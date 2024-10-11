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

# EKS
variable "eks_module_version" {
  description = "Version of the EKS module"
}

variable "eks_kubernetes_version" {
  description = "Version of Kubernetes running in the EKS module"
}

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
