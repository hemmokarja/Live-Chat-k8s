# elastic block store container store interface driver
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${var.project}EBSCSIDriverRole"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role_policy.json
}


data "aws_iam_policy_document" "ebs_csi_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-serviceaccount"]
    }
  }
}


resource "aws_iam_role_policy_attachment" "ebs_csi_driver_attachment" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
