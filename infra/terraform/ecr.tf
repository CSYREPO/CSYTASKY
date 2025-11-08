resource "aws_ecr_repository" "tasky" {
  name = "tasky"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "tasky-ecr"
  }
}
