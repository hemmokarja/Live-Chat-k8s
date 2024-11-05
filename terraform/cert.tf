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
