# Building the binary of the App
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky

# Runtime image
FROM alpine:3.17.0 AS release

WORKDIR /app

# copy app + assets
COPY --from=build /go/src/tasky/tasky .
COPY --from=build /go/src/tasky/assets ./assets

# Wiz exercise marker
RUN echo "Casey Walker" > /app/wizexercise.txt

EXPOSE 8080
ENTRYPOINT ["/app/tasky"]

