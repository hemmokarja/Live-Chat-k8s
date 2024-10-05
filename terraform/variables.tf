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
variable "backend_module_port" {
  description = "Exposed internal port of the backend application"
}

variable "ui_module_port" {
  description = "Exposed internal port of the UI application"
}

variable "redis_port" {
  description = "Exposed port of the Redis Cache"
}

# EKS
variable "eks_instance_type" {
  description = "Instance type of the EKS cluster worker nodes"
}

variable "eks_desired_nodes" {
  description = "Desired number of EC2 instances in the EKS cluster"
}

variable "eks_min_nodes" {
  description = "Minimum number of EC2 instances in the EKS cluster"
}

variable "eks_max_nodes" {
  description = "Maximum number of EC2 instances in the EKS cluster"
}

# access
variable "allowed_cidr" {
  description = "CIDR block defining IPs that can connect to the EKS control plane"
}
