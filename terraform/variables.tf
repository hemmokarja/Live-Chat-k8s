variable "project" {
  description = "Name of the project"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
}

variable "username" {
  description = "Username for tagging resources"
}

variable "region" {
  description = "The AWS region to deploy resources"
}

# ports
variable "backend_service_port" {
  description = "EC2 instance type for the actual dev instance"
}

variable "ui_service_port" {
  description = "EC2 instance type for the actual dev instance"
}

variable "redis_port" {
  description = "EC2 instance type for the actual dev instance"
}

# EKS
variable "eks_instance_type" {
  description = "EC2 instance type for the actual dev instance"
}

variable "eks_desired_capacity" {
  description = "Desired number of EC2 instances in the EKS cluster"
}

variable "eks_min_capacity" {
  description = "Minimum number of EC2 instances in the EKS cluster"
}

variable "eks_max_capacity" {
  description = "Maximum number of EC2 instances in the EKS cluster"
}

# access
variable "allowed_cidr" {
  description = "CIDR block defining IPs that can connect to the service"
}


# variable "key_pair_name" {
#   description = "Name of the SSH key pair"
# }

# variable "public_key_path" {
#   description = "Path to the public key"
# }

# variable "local_public_ip" {
#   description = "Your local machine's public IP address to allow SSH access"
# }

# variable "dev_instance_private_ip" {
#   description = "Your remote dev machine's private IP address"
# }