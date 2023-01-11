# Variables
variable "profile" {}
variable "access_key" {}
variable "secret_key" {}
variable "bucket_name" {
  default = "answerking-bucket-react"
}

# Configure the AWS provider
provider "aws" {
  region     = "eu-west-2"
  profile    = var.profile
  access_key = var.access_key
  secret_key = var.secret_key
}

# S3 Bucket
data "aws_iam_policy_document" "read_react_app_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.react.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.react.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.react.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.react.iam_arn]
    }
  }
}

resource "aws_s3_bucket" "react" {
  bucket = var.bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_policy" "read_react_app" {
  bucket = aws_s3_bucket.react.id
  policy = data.aws_iam_policy_document.read_react_app_bucket.json
}

resource "aws_s3_bucket_public_access_block" "react" {
  bucket = aws_s3_bucket.react.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

locals {
  s3_origin_id    = "S3-origin-react-app"
  certificate_arn = "arn:aws:acm:us-east-1:409973623162:certificate/3672e181-0091-4469-a7ca-3676705ff426"
}

# Upload the React app to the S3 bucket
resource "aws_s3_bucket_object" "index_html" {
  bucket       = aws_s3_bucket.react.id
  key          = "index.html"
  source       = "dist/index.html"
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "css_files" {
  bucket       = aws_s3_bucket.react.id
  key          = "/assets/index-650b95c4.css"
  source       = "dist/assets/index-650b95c4.css"
  content_type = "text/css"
}

resource "aws_s3_bucket_object" "js_files" {
  bucket       = aws_s3_bucket.react.id
  key          = "/assets/index-2c7a1f24.js"
  source       = "dist/assets/index-2c7a1f24.js"
  content_type = "application/javascript"
}

resource "aws_s3_bucket_object" "image_files" {
  count  = length(var.image_filenames)
  bucket = aws_s3_bucket.react.id
  key    = "/assets/${var.image_filenames[count.index]}"
  source = "dist/assets/${var.image_filenames[count.index]}"
}

variable "image_filenames" {
  type = list(string)
  default = [
    "burger_transparent-e8cf04d5.png",
    "burgerhome-3f16d8ea.png",
    "logo-204f0d5a.png"
  ]
}

# Cloudfront Distribution
resource "aws_cloudfront_origin_access_identity" "react" {
  comment = "react"
}

resource "aws_cloudfront_distribution" "website_cdn" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["answerking.co.uk"]

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.react.bucket
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    min_ttl     = 0
    default_ttl = 5 * 60
    max_ttl     = 60 * 60

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.react.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.react.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.react.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = local.certificate_arn
    ssl_support_method  = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }
}

# Route53
data "aws_route53_zone" "route53_zone" {
  name         = "answerking.co.uk"
  private_zone = false
}

resource "aws_route53_record" "cf_dns" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "answerking.co.uk"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.website_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# Output
output "website_cdn_id" {
  value = aws_cloudfront_distribution.website_cdn.id
}

output "website_endpoint" {
  value = aws_cloudfront_distribution.website_cdn.domain_name
}

