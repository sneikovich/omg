// бакет для статики
resource "aws_s3_bucket" "site" {
  bucket = var.domain_name
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.module}/site/index.html"
  etag         = filemd5("${path.module}/site/index.html")
  content_type = "text/html"
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.site.id
  key          = "error.html"
  source       = "${path.module}/site/error.html"
  etag         = filemd5("${path.module}/site/error.html")
  content_type = "text/html"
}

# website endpoint S3 не підтримує IAM/OAC, тож для роздачі статики потрібен public-read
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "kubectl_manifest" "site_backend" {
  yaml_body = templatefile("${path.module}/manifests/s3-site/backend.yml", {
    bucket_website_hostname = "${aws_s3_bucket.site.id}.s3-website.eu-central-1.amazonaws.com"
  })

  depends_on = [helm_release.envoy_gw, aws_s3_bucket_website_configuration.site]
}

resource "kubectl_manifest" "site_route" {
  yaml_body = templatefile("${path.module}/manifests/s3-site/http-route.yml", {
    domain_name             = var.domain_name
    bucket_website_hostname = "${aws_s3_bucket.site.id}.s3-website.eu-central-1.amazonaws.com"
  })

  depends_on = [kubectl_manifest.site_backend, kubectl_manifest.gateway]
}
