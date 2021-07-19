variable "access_key" {}

variable "secret_key" {}

variable "region" {}

variable "domain" {}

variable "api_subdomain" {}

variable "target_alb_arn" {
  type = string
}

variable "target_listener_arn" {
  type = string
}


# Configure the AWS Provider
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

data "aws_route53_zone" "api_zone" {
  name = var.domain
}

data "aws_lb" "target_alb" {
  arn  = var.target_alb_arn
}

resource "aws_route53_record" "root_record" {
  zone_id = data.aws_route53_zone.api_zone.zone_id
  name    = "*"
  type    = "A"
  
  alias {
    name                   = data.aws_lb.target_alb.dns_name
    zone_id                = data.aws_lb.target_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "api_cert" {
  domain_name       = "${var.api_subdomain}.${var.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "api_cert" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.api_zone.zone_id
}

resource "aws_acm_certificate_validation" "api_cert" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.api_cert : record.fqdn]
}