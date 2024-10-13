output "vpc_id" {
  value = module.vpc.vpc_id
}

output "aws_lb_controller_role_arn" {
  value = aws_iam_role.aws_lb_controller_role.arn
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.self_signed_cert.arn
}
