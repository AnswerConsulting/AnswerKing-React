# Variables
variable "profile" {}
variable "access_key" {}
variable "secret_key" {}
variable "bucket_name" {
  default = "react-answerking-bucket"
}

# Configure the AWS provider
provider "aws" {
  region     = "eu-west-2"
  profile =  "${var.profile}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.react_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.react_bucket.arn}/*"
      },
    ]
  })
}

resource "aws_s3_bucket" "react_bucket" {
  bucket = var.bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

# Upload the React app to the S3 bucket
resource "aws_s3_bucket_object" "index_html" {
  bucket = aws_s3_bucket.react_bucket.id
  key    = "index.html"
  source = "dist/index.html"
  content_type = "text/html"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "css_files" {
  bucket = aws_s3_bucket.react_bucket.id
  key    = "/assets/index.0af4e829.css"
  source = "dist/assets/index.0af4e829.css"
  content_type = "text/css"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "js_files" {
  bucket = aws_s3_bucket.react_bucket.id
  key    = "/assets/index.b7557a3a.js"
  source = "dist/assets/index.b7557a3a.js"
  content_type = "application/javascript"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "image_files" {
  count       = "${length(var.image_filenames)}"
  bucket      = "${aws_s3_bucket.react_bucket.id}"
  key         = "/assets/${var.image_filenames[count.index]}"
  source      = "dist/assets/${var.image_filenames[count.index]}"
}

variable "image_filenames" {
  type = list(string)
  default = [
    "burger_transparent.e8cf04d5.png",
    "burgerhome.3f16d8ea.png",
    "logo.204f0d5a.png"
  ]
}

# Cloudfront Web Distribution
resource "aws_cloudfront_origin_access_identity" "cloudfront_oia" {
  comment = "answerking-oia"
}

resource "aws_cloudfront_distribution" "website_cdn" {
  enabled = true

  origin {
    origin_id   = "origin-bucket-${aws_s3_bucket.react_bucket.id}"
    domain_name = aws_s3_bucket.react_bucket.website_endpoint

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    min_ttl                = "0"
    default_ttl            = "300"
    max_ttl                = "1200"
    target_origin_id       = "origin-bucket-${aws_s3_bucket.react_bucket.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Output
output "website_cdn_id" {
  value = aws_cloudfront_distribution.website_cdn.id
}

output "website_endpoint" {
  value = aws_cloudfront_distribution.website_cdn.domain_name
}
