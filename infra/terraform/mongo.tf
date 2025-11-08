# --- MongoDB Security Group ---
resource "aws_security_group" "mongo_sg" {
  name        = "tasky-wiz-mongo-sg"
  description = "Allow SSH and Mongo"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tasky-wiz-mongo-sg"
  }
}

# --- MongoDB EC2 Instance ---
resource "aws_instance" "mongo" {
  ami                         = "ami-0fc5d935ebf8bc3bc" # Ubuntu 22.04 us-east-1
  instance_type               = "t3.micro"
  key_name                    = "ubuntu22"
  subnet_id                   = aws_subnet.public_b.id
  vpc_security_group_ids      = [aws_security_group.mongo_sg.id]
  associate_public_ip_address = true

  # <-- this is the new part
  iam_instance_profile = aws_iam_instance_profile.mongo_backup_profile.name

  tags = {
    Name = "tasky-wiz-mongo"
  }

  user_data = <<-EOT
    #!/bin/bash
    set -e

    apt-get update -y
    apt-get install -y gnupg curl awscli

    # install MongoDB 6.0
    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" \
      | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    apt-get update -y
    apt-get install -y mongodb-org
    systemctl enable mongod
    systemctl start mongod

    BUCKET_NAME="${aws_s3_bucket.mongo_backups.bucket}"

    cat >/usr/local/bin/mongo-to-s3.sh <<'SCRIPT'
    #!/bin/bash
    set -e
    TS=$(date +%Y%m%d-%H%M%S)
    FILE="/tmp/mongo-backup-$TS.gz"
    mongodump --archive="$FILE" --gzip
    aws s3 cp "$FILE" s3://BUCKET_PLACEHOLDER/
    rm -f "$FILE"
    SCRIPT

    sed -i "s|BUCKET_PLACEHOLDER|$BUCKET_NAME|g" /usr/local/bin/mongo-to-s3.sh
    chmod +x /usr/local/bin/mongo-to-s3.sh

    cat >/etc/cron.d/mongo-backup <<'CRON'
    0 * * * * root /usr/local/bin/mongo-to-s3.sh
    CRON

    chmod 0644 /etc/cron.d/mongo-backup
    systemctl restart cron || systemctl restart crond
  EOT
}
