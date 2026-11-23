# Look up the existing hosted zone (created when domain was registered)
data "aws_route53_zone" "app" {
  name         = var.domain_name
  private_zone = false
}

# Apex A record → CloudFront
resource "aws_route53_record" "apex_a" {
  zone_id = data.aws_route53_zone.app.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}

# Apex AAAA record → CloudFront (IPv6)
resource "aws_route53_record" "apex_aaaa" {
  zone_id = data.aws_route53_zone.app.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}

# www CNAME → CloudFront
resource "aws_route53_record" "www_a" {
  zone_id = data.aws_route53_zone.app.zone_id
  name    = var.www_subdomain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_aaaa" {
  zone_id = data.aws_route53_zone.app.zone_id
  name    = var.www_subdomain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}
