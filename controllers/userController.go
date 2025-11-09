package controller

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jeffthorne/tasky/auth"
	"github.com/jeffthorne/tasky/database"
	"github.com/jeffthorne/tasky/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"golang.org/x/crypto/bcrypt"
)

var SECRET_KEY string = os.Getenv("SECRET_KEY")

// this can still end up nil if database.Client wasn't initialized
var userCollection *mongo.Collection = database.OpenCollection(database.Client, "user")

// ---------------------- SIGNUP ----------------------
func SignUp(c *gin.Context) {
	// make sure we actually have a collection
	if userCollection == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database not initialized"})
		return
	}

	var user models.User

	// bind JSON (what you're sending from curl)
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json: " + err.Error()})
		return
	}

	// password is a pointer in your model, so guard it
	if user.Password == nil || *user.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "password is required"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Second)
	defer cancel()

	// check for existing email
	emailCount, err := userCollection.CountDocuments(ctx, bson.M{"email": user.Email})
	if err != nil {
		log.Println("email count error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error occurred while checking for the email"})
		return
	}

	// hash password
	hashed := HashPassword(*user.Password)
	user.Password = &hashed

	if emailCount > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User with this email already exists!"})
		return
	}

	user.ID = primitive.NewObjectID()
	resultInsertionNumber, insertErr := userCollection.InsertOne(ctx, user)
	if insertErr != nil {
		msg := fmt.Sprintf("user item was not created")
		c.JSON(http.StatusInternalServerError, gin.H{"error": msg})
		return
	}

	userId := user.ID.Hex()
	username := ""
	if user.Name != nil {
		username = *user.Name
	}

	// generate token
	token, err, expirationTime := auth.GenerateJWT(userId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error occurred while generating token"})
		return
	}

	// set cookies
	http.SetCookie(c.Writer, &http.Cookie{
		Name:    "token",
		Value:   token,
		Expires: expirationTime,
	})
	http.SetCookie(c.Writer, &http.Cookie{
		Name:    "userID",
		Value:   userId,
		Expires: expirationTime,
	})
	http.SetCookie(c.Writer, &http.Cookie{
		Name:    "username",
		Value:   username,
		Expires: expirationTime,
	})

	// return the Mongo insert result like before
	c.JSON(http.StatusOK, resultInsertionNumber)
}

// ---------------------- LOGIN ----------------------
func Login(c *gin.Context) {
	if userCollection == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database not initialized"})
		return
	}

	var user models.User
	var foundUser models.User

	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json: " + err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Second)
	defer cancel()

	err := userCollection.FindOne(ctx, bson.M{"email": user.Email}).Decode(&foundUser)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "email or password is incorrect"})
		return
	}

	// again, your model uses *string
	if user.Password == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "password is required"})
		return
	}

	passwordIsValid, msg := VerifyPassword(*user.Password, *foundUser.Password)
	if passwordIsValid != true {
		c.JSON(http.StatusInternalServerError, gin.H{"error": msg})
		return
	}

	if foundUser.Email == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "User not found!"})
		return
	}

	userId := foundUser.ID.Hex()
	username := ""
	if foundUser.Name != nil {
		username = *foundUser.Name
	}

	shouldRefresh, err, expirationTime := auth.RefreshToken(c)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "refresh token error"})
		return
	}

	if shouldRefresh {
		token, err, expirationTime := auth.GenerateJWT(userId)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "error occurred while generating token"})
			return
		}

		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "token",
			Value:   token,
			Expires: expirationTime,
		})
		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "userID",
			Value:   userId,
			Expires: expirationTime,
		})
		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "username",
			Value:   username,
			Expires: expirationTime,
		})
	} else {
		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "userID",
			Value:   userId,
			Expires: expirationTime,
		})
		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "username",
			Value:   username,
			Expires: expirationTime,
		})
	}

	c.JSON(http.StatusOK, gin.H{"msg": "login successful"})
}

// ---------------------- TODO PAGE ----------------------
func Todo(c *gin.Context) {
	session := auth.ValidateSession(c)
	if session {
		c.HTML(http.StatusOK, "todo.html", nil)
	}
}

// ---------------------- HELPERS ----------------------
func HashPassword(password string) string {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	if err != nil {
		log.Panic(err)
	}
	return string(bytes)
}

func VerifyPassword(userPassword string, providedPassword string) (bool, string) {
	err := bcrypt.CompareHashAndPassword([]byte(providedPassword), []byte(userPassword))
	check := true
	msg := ""

	if err != nil {
		msg = fmt.Sprintf("email or password is incorrect")
		check = false
	}

	return check, msg
}

