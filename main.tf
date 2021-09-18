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

# Setup Cloudfront
resource "aws_cloudfront_origin_access_identity" "s3_bucket_website" {
  comment = "Static Corporate Website"
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.id
    origin_id   = "${var.website_domain}-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_bucket_website.cloudfront_access_identity_path
    }
  }

  enabled             = true
  aliases             = [var.website_domain]
  price_class         = "PriceClass_100" # Cheapest price class with fewest edge locations
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.website_domain}-origin"
    compress         = true

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 43200 # 12 hours
    default_ttl            = 43200 # 12 hours
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.website.arn
    ssl_support_method  = "sni-only" # No dedicated IP, cheaper

    # Balance between security and compatibility
    # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html
    minimum_protocol_version = "TLSv1.2_2018"
  }
}

# Update S3 bucket policy and restrict access with Cloudfront Origin Access Identity
data "aws_iam_policy_document" "cloudfront_origin_access_identity" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.s3_bucket_website.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.cloudfront_origin_access_identity.json
}

# Sync repository website files with S3
resource "null_resource" "sync_with_s3" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/website s3://${aws_s3_bucket.website.id}"
  }
}
