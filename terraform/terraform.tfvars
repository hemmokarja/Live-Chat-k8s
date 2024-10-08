project             = "LiveChatApp"
cluster_name        = "LiveChatAppEKSCluster"
username            = "Hemmo"
region              = "eu-north-1"
backend_module_port = 5000
ui_module_port      = 8000
redis_port          = 6379
eks_instance_type   = "t3.medium"
eks_desired_nodes   = 2
eks_min_nodes       = 1
eks_max_nodes       = 3
allowed_cidr        = "85.76.75.15/32"
# allowed_cidr        = "0.0.0.0/0"