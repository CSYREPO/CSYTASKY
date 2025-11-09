pipeline {
    agent any

    environment {
        AWS_REGION    = "us-east-1"
        CLUSTER_NAME  = "tasky-wiz-eks"
        K8S_DIR       = "k8s"
        AWS_ACCOUNTID = "122610499688"
        ECR_REPO      = "tasky"
        IMAGE_TAG     = "latest"
        ECR_URL       = "${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // optional but good for your small Jenkins EC2
        stage('Docker Cleanup') {
            steps {
                sh """
                  docker system prune -af || true
                  docker image prune -af || true
                """
            }
        }

        stage('Build & Push Image') {
            steps {
                sh """
                  echo "🔐 Logging into ECR..."
                  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}

                  echo "🐳 Building image..."
                  docker build -t ${ECR_REPO}:${IMAGE_TAG} .

                  echo "🏷️ Tagging image..."
                  docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}

                  echo "🚀 Pushing image to ECR..."
                  docker push ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}
                """
            }
        }

        stage('Scan Image (Trivy)') {
            steps {
                sh """
                  echo "🔎 Scanning image with Trivy..."

                  # install Trivy into the current workspace if it's not already there
                  if ! [ -x "./trivy" ]; then
                    echo "Downloading Trivy locally..."
                    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ./
                  fi

                  # run a non-blocking scan so the pipeline can continue
                  ./trivy image --severity HIGH,CRITICAL --exit-code 0 ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}

                  echo "✅ Trivy scan completed (non-blocking)."
                """
            }
        }

        stage('Configure AWS & EKS') {
            steps {
                sh """
                  aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                  kubectl get nodes
                """
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh """
                  kubectl apply -f ${K8S_DIR}/
                  kubectl -n tasky get pods
                  kubectl -n tasky get svc
                """
            }
        }
    }
}

