# статика фронтенду osm-app: заливаємо реальні файли замість старого плейсхолдера,
# nginx з k8s-шляху прибрано повністю - S3 website + Envoy Backend роблять ту саму роботу
locals {
  frontend_dir = "${path.module}/../../osm-app/frontend"

  # виключаємо все, що потрібне лише для локального docker compose
  frontend_exclude_files    = ["Dockerfile", "nginx.conf.template", "15-resolver.envsh", "package.json", "README.md"]
  frontend_exclude_prefixes = ["test/"]

  frontend_files = [
    for f in fileset(local.frontend_dir, "**") : f
    if !contains(local.frontend_exclude_files, f) &&
    !anytrue([for p in local.frontend_exclude_prefixes : startswith(f, p)])
  ]

  frontend_content_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    png  = "image/png"
  }
}

resource "aws_s3_bucket" "frontend" {
  bucket = var.domain_name
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  # SPA без серверного роутингу: на будь-яку "помилку" повертаємо index.html,
  # а клієнтський JS сам розбирається з шляхом
  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# website endpoint S3 не підтримує IAM/OAC, тож для роздачі статики потрібен public-read
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

resource "aws_s3_object" "frontend" {
  for_each = toset(local.frontend_files)

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${local.frontend_dir}/${each.value}"
  etag         = filemd5("${local.frontend_dir}/${each.value}")
  content_type = lookup(local.frontend_content_types, lower(reverse(split(".", each.value))[0]), "application/octet-stream")
}

resource "kubectl_manifest" "frontend_backend" {
  yaml_body = templatefile("${path.module}/manifests/frontend/backend.yml", {
    bucket_website_hostname = "${aws_s3_bucket.frontend.id}.s3-website.eu-central-1.amazonaws.com"
  })

  depends_on = [helm_release.envoy_gw, kubernetes_namespace_v1.osm_app, aws_s3_bucket_website_configuration.frontend]
}
