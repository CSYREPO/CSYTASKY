# IAM role that EC2 will assume
resource "aws_iam_role" "mongo_backup_role" {
  name = "tasky-wiz-mongo-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy that allows writing to the backup bucket
resource "aws_iam_policy" "mongo_backup_policy" {
  name        = "tasky-wiz-mongo-backup-policy"
  description = "Allow EC2 to put backups in Mongo backup bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mongo_backups.arn,
          "${aws_s3_bucket.mongo_backups.arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "mongo_backup_attach" {
  role       = aws_iam_role.mongo_backup_role.name
  policy_arn = aws_iam_policy.mongo_backup_policy.arn
}

# Instance profile so EC2 can actually use the role
resource "aws_iam_instance_profile" "mongo_backup_profile" {
  name = "tasky-wiz-mongo-backup-profile"
  role = aws_iam_role.mongo_backup_role.name
}
