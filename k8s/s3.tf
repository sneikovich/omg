// бакет для статики. поки без вмісту - ресурс зі статикою додамо пізніше
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
  yaml_body = yamlencode({
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "Backend"
    metadata = {
      name      = "static-site"
      namespace = kubernetes_namespace_v1.envoy_gw.metadata[0].name
    }
    spec = {
      endpoints = [{
        fqdn = {
          hostname = "${aws_s3_bucket.site.id}.s3-website.eu-central-1.amazonaws.com"
          port     = 80
        }
      }]
    }
  })

  depends_on = [helm_release.envoy_gw, aws_s3_bucket_website_configuration.site]
}

resource "kubectl_manifest" "site_route" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "static-site"
      namespace = kubernetes_namespace_v1.envoy_gw.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name = "main-gateway"
      }]
      hostnames = [var.domain_name]
      rules = [{
        filters = [{
          type = "URLRewrite"
          urlRewrite = {
            hostname = "${aws_s3_bucket.site.id}.s3-website.eu-central-1.amazonaws.com"
          }
        }]
        backendRefs = [{
          group = "gateway.envoyproxy.io"
          kind  = "Backend"
          name  = "static-site"
          port  = 80
        }]
      }]
    }
  })

  depends_on = [kubectl_manifest.site_backend, kubectl_manifest.gateway]
}
