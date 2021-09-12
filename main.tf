provider "aws" {
  region = var.aws_region
}

# S3 Bucket with Website settings
resource "aws_s3_bucket" "website" {
  bucket = var.website_domain
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

//  cors_rule {
//    allowed_headers = ["*"]
//    allowed_methods = ["PUT", "POST"]
//    allowed_origins = ["https://${var.website_domain}"]
//    expose_headers  = ["ETag"]
//    max_age_seconds = 3000
//  }

  tags = {
    Name = "Static Corporate Website"
  }
}

# Request SSL Certificate
resource "aws_acm_certificate" "website" {
  domain_name       = var.website_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Static Corporate Website"
  }
}

# Route53 Domain Name & Resource Records
resource "aws_route53_zone" "website_zone" {
  name         = var.website_domain
  private_zone = false
}

resource "aws_route53_record" "website_cname" {
  zone_id = aws_route53_zone.website_zone.zone_id
  name = var.website_domain
  type = "NS"
  ttl = "30"
  records = [
    aws_route53_zone.website_zone.name_servers,
    aws_route53_zone.website_zone.name_servers,
    aws_route53_zone.website_zone.name_servers,
    aws_route53_zone.website_zone.name_servers
  ]
}

# Validate ACM issued SSL certificate via DNS
resource "aws_route53_record" "website_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.website_zone.zone_id
}

resource "aws_acm_certificate_validation" "website" {
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for record in aws_route53_record.website_certificate_validation : record.fqdn]
}
