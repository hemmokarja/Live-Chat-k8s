data "aws_caller_identity" "current" {}


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  authentication_mode = "API_AND_CONFIG_MAP"
  access_entries = {
    # can be circumvented by `enable_cluster_creator_admin_permissions = true`
    admin_user = {
      principal_arn     = data.aws_caller_identity.current.arn
      kubernetes_groups = []
      policy_associations = {
        admin_user = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "cluster"
            namespaces = []
          }
        }
      }
    }
  }

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = [var.allowed_cidr]
  cluster_security_group_id            = aws_security_group.cluster_sg.id

  eks_managed_node_groups = {
    workers = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size       = var.eks_min_capacity
      max_size       = var.eks_max_capacity
      desired_size   = var.eks_desired_capacity
      # subnet_ids             = module.vpc.private_subnets
      vpc_security_group_ids = [aws_security_group.worker_sg.id]

      iam_role_name = "${var.project}EKSWorkerRole"
      iam_role_additional_policies = {
        "EKSWorkerNodePolicy"          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        "EC2ContainerRegistryReadOnly" = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        "EKSCNIPolicy"                 = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }
    }
  }

  create_iam_role = true
  iam_role_name   = "${var.project}EKSClusterRole"
  iam_role_additional_policies = {
    "EKSClusterPolicy" = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    "EKSServicePolicy" = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  }

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name = var.cluster_name
    User = var.username
  }
}
