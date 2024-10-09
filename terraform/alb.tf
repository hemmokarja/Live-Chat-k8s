# iam role
data "aws_iam_policy_document" "aws_lb_controller_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}


resource "aws_iam_role" "aws_lb_controller_role" {
  name               = "${var.project}EKSAWSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.aws_lb_controller_assume_role_policy.json
}


resource "aws_iam_policy" "aws_lb_controller_policy" {
  name = "${var.project}EKSAWSLoadBalancerControllerIAMPolicy"

  # https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
  policy = file("${path.module}/policies/alb.json")
}


resource "aws_iam_role_policy_attachment" "aws_lb_controller_policy_attachment" {
  role       = aws_iam_role.aws_lb_controller_role.name
  policy_arn = aws_iam_policy.aws_lb_controller_policy.arn
}


# cert
locals {
  cert_dir = "../.cert"
}


resource "aws_acm_certificate" "self_signed_cert" {
  private_key       = file("${local.cert_dir}/private.key")
  certificate_body  = file("${local.cert_dir}/certificate.crt")
  certificate_chain = null

  tags = {
    Name    = "${var.project}SelfSignedCert"
    User    = var.username
    Project = var.project
  }
}


# service account
resource "kubernetes_service_account" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_controller_role.arn
    }
  }
}


# alb controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.${var.region}.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "enableCertManager"
    value = "false"
  }

  depends_on = [
    module.eks,
    module.vpc,
    kubernetes_service_account.aws_lb_controller,
  ]
}


# alb
resource "kubernetes_ingress_v1" "live_chat_app_ingress" {
  metadata {
    name      = "live-chat-app-ingress"
    namespace = "default"

    annotations = {
      "kubernetes.io/ingress.class"                       = "alb"
      "alb.ingress.kubernetes.io/scheme"                  = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports"            = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn"         = aws_acm_certificate.self_signed_cert.arn
      "alb.ingress.kubernetes.io/ssl-policy"              = "ELBSecurityPolicy-2016-08"
      "alb.ingress.kubernetes.io/ssl-redirect"            = "443"
      "alb.ingress.kubernetes.io/target-type"             = "ip"
      "alb.ingress.kubernetes.io/target-group-attributes" = "stickiness.enabled=true,stickiness.type=lb_cookie,stickiness.lb_cookie.duration_seconds=86400"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "ui-service"
              port {
                number = 8000
              }
            }
          }
        }

        path {
          path      = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = "backend-service"
              port {
                number = 5000
              }
            }
          }
        }

        path {
          path      = "/socket.io"
          path_type = "Prefix"

          backend {
            service {
              name = "backend-service"
              port {
                number = 5000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate.self_signed_cert
  ]
}
