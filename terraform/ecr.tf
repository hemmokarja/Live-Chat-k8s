# ECR
resource "aws_ecr_repository" "backend_module" {
  name                 = "${lower(var.project)}/backend_module"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = true

  tags = {
    Name    = "${var.project}BackendModuleECRRepository"
    User    = var.username
    Project = var.project
  }
}


resource "aws_ecr_repository" "ui_module" {
  name                 = "${lower(var.project)}/ui_module"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = true

  tags = {
    Name    = "${var.project}UIModuleECRRepository"
    User    = var.username
    Project = var.project
  }
}
