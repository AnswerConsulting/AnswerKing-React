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
  profile    = var.profile
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_s3_bucket" "react_bucket" {
  bucket = var.bucket_name
  acl    = "private"

  tags = {
    Name = "my-react-bucket"
  }

  logging {
    target_bucket = var.bucket_name
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "react-config" {
  bucket = aws_s3_bucket.react_bucket.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }
}

# Retrieve users as a resource
data "aws_iam_user" "user" {
  user_name = "Harry_Stead"
}

# Create the policy to access the S3 bucket
resource "aws_iam_policy" "s3_policy" {
  name        = "s3-policy"
  path        = "/"
  description = "S3 policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.react_bucket.arn}/*"
        ]
      },
    ]
  })
}

# Attach the policy to our user
resource "aws_iam_policy_attachment" "user_policy_attachment" {
  name       = "user-policy-attachment"
  users      = [data.aws_iam_user.user.user_name]
  policy_arn = aws_iam_policy.s3_policy.arn
}

# Upload the React app to the S3 bucket
resource "aws_s3_bucket_object" "index_html" {
  bucket       = aws_s3_bucket.react_bucket.id
  key          = "index.html"
  source       = "dist/index.html"
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "css_files" {
  bucket       = aws_s3_bucket.react_bucket.id
  key          = "/assets/index-650b95c4.css"
  source       = "dist/assets/index-650b95c4.css"
  content_type = "text/css"
}

resource "aws_s3_bucket_object" "js_files" {
  bucket       = aws_s3_bucket.react_bucket.id
  key          = "/assets/index-2c7a1f24.js"
  source       = "dist/assets/index-2c7a1f24.js"
  content_type = "application/javascript"
}

resource "aws_s3_bucket_object" "image_files" {
  count  = length(var.image_filenames)
  bucket = aws_s3_bucket.react_bucket.id
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

# Cloudfront Web Distribution
locals {
  s3_origin_id = "S3-origin-react-app"
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "react-app OAI"
}

resource "aws_cloudfront_distribution" "cf_distribution" {
  origin {
    domain_name = aws_s3_bucket.react_bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/index.html"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  retain_on_delete = true

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

data "aws_iam_policy_document" "react_app_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.react_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "react_app_bucket_policy" {
  bucket = aws_s3_bucket.react_bucket.id
  policy = data.aws_iam_policy_document.react_app_s3_policy.json
}
