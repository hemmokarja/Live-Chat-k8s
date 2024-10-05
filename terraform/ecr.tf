locals {
  backend_module_repository_name = "${lower(var.project)}/backend_module"
  ui_module_repository_name      = "${lower(var.project)}/ui_module"
  backend_path                   = "${path.module}/../src/backend"
  ui_path                        = "${path.module}/../src/ui"
  push_image_path                = "${path.module}/scripts/push_image.sh"
}


# ECR
resource "aws_ecr_repository" "backend_module" {
  name                 = local.backend_module_repository_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = true

  tags = {
    Name = "${var.project}BackendModuleECRRepository"
    User = var.username
  }
}


resource "aws_ecr_repository" "ui_module" {
  name                 = local.ui_module_repository_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = true

  tags = {
    Name = "${var.project}UIModuleECRRepository"
    User = var.username
  }
}


# push images
resource "null_resource" "push_backend_image" {
  depends_on = [aws_ecr_repository.backend_module]

  triggers = {
    script_checksum = filemd5(local.push_image_path)
  }

  provisioner "local-exec" {
    command = local.push_image_path
    environment = {
      IMAGE_TAG       = "backend_module"
      REGION          = var.region
      REPOSITORY_NAME = local.backend_module_repository_name
      DOCKERFILE_PATH = "${local.backend_path}/Dockerfile"
      CONTEXT_DIR     = local.backend_path
    }
  }
}


resource "null_resource" "push_ui_image" {
  depends_on = [aws_ecr_repository.ui_module]

  triggers = {
    script_checksum = filemd5(local.push_image_path)
  }

  provisioner "local-exec" {
    command = local.push_image_path
    environment = {
      IMAGE_TAG       = "ui_module"
      REGION          = var.region
      REPOSITORY_NAME = local.ui_module_repository_name
      DOCKERFILE_PATH = "${local.ui_path}/Dockerfile"
      CONTEXT_DIR     = local.ui_path
    }
  }
}
