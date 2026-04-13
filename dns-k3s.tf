data "aws_route53_zone" "main" {
  name = "tommykeyapp.com"
}

resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "argocd.tommykeyapp.com"
  type    = "A"
  ttl     = 300
  records = [aws_eip.k3s.public_ip]
}
