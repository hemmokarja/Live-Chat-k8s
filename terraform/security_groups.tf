resource "aws_security_group" "lb_sg" {
  name        = "${var.project}LoadBalancerSG"
  description = "Security group for EKS load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow HTTP traffic from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Allow outbound traffic to worker nodes"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_sg.id]
  }

  tags = {
    Name = "${var.project}LoadBalancerSG"
    User = var.username
  }
}


resource "aws_security_group" "worker_sg" {
  name        = "${var.project}WorkerSG"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow traffic from control plane"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster_sg.id]
  }

  ingress {
    description = "Allow node-to-node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}WorkerSG"
    User = var.username
  }
}


resource "aws_security_group" "cluster_sg" {
  name        = "${var.project}ClusterSG"
  description = "Security group for EKS cluster control plane (not within the VPC)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow inbound traffic from your IP"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}ClusterSG"
    User = var.username
  }
}
