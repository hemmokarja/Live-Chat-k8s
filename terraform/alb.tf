
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"] # NOTE HERE THE NAME!!!!
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
