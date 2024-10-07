locals {
  backend_module_repository_name = "${lower(var.project)}/backend_module"
  ui_module_repository_name      = "${lower(var.project)}/ui_module"
  backend_dir                    = "${path.module}/../src/backend"
  ui_dir                         = "${path.module}/../src/ui"
  backend_files                  = fileset(local.backend_dir, "**")
  ui_files                       = fileset(local.ui_dir, "**")
  push_image_path                = "${path.module}/../scripts/push_image.sh"
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
    Name    = "${var.project}BackendModuleECRRepository"
    User    = var.username
    Project = var.project
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
    Name    = "${var.project}UIModuleECRRepository"
    User    = var.username
    Project = var.project
  }
}


resource "null_resource" "push_backend_image" {
  depends_on = [aws_ecr_repository.backend_module]

  triggers = {
    push_checksum = filemd5(local.push_image_path)
    app_checksum  = md5(join("", [for f in local.backend_files : filemd5("${local.backend_dir}/${f}")]))
  }

  provisioner "local-exec" {
    command = local.push_image_path
    environment = {
      IMAGE_TAG       = "backend_module"
      REGION          = var.region
      REPOSITORY_NAME = local.backend_module_repository_name
      DOCKERFILE_PATH = "${local.backend_dir}/Dockerfile"
      CONTEXT_DIR     = local.backend_dir
    }
  }
}


resource "null_resource" "push_ui_image" {
  depends_on = [aws_ecr_repository.ui_module]

  triggers = {
    push_checksum = filemd5(local.push_image_path)
    app_checksum  = md5(join("", [for f in local.ui_files : filemd5("${local.ui_dir}/${f}")]))
  }

  provisioner "local-exec" {
    command = local.push_image_path
    environment = {
      IMAGE_TAG       = "ui_module"
      REGION          = var.region
      REPOSITORY_NAME = local.ui_module_repository_name
      DOCKERFILE_PATH = "${local.ui_dir}/Dockerfile"
      CONTEXT_DIR     = local.ui_dir
    }
  }
}
