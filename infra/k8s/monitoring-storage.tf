# S3-сховище для Loki (чанки) та Mimir (блоки): в кластері немає aws-ebs-csi-driver, тож PVC лишились би Pending.
# Доступ - через EKS Pod Identity (аддон eks-pod-identity-agent вже є в eks/), без статичних ключів.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  monitoring_components = toset(["loki", "mimir"])

  # імена бакетів глобально унікальні, тож додаємо id акаунта
  monitoring_buckets = {
    for c in local.monitoring_components : c => "osm-${c}-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket" "monitoring" {
  for_each = local.monitoring_components

  bucket = local.monitoring_buckets[each.key]

  # без цього terraform destroy падає на непорожньому бакеті; а за shard rule k8s-шар
  # знищується регулярно. Дані моніторингу відтворювані (ретенція 7d), тож це прийнятно
  force_destroy = true
}

# на відміну від frontend-бакета, дані моніторингу публічними не бувають
resource "aws_s3_bucket_public_access_block" "monitoring" {
  for_each = local.monitoring_components

  bucket = aws_s3_bucket.monitoring[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "monitoring" {
  for_each = local.monitoring_components

  bucket = aws_s3_bucket.monitoring[each.key].id

  rule {
    id     = "expire-old-data"
    status = "Enabled"

    filter {}

    expiration {
      days = var.monitoring_s3_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# окрема роль на компонент: Loki не бачить бакет Mimir і навпаки
resource "aws_iam_role" "monitoring" {
  for_each = local.monitoring_components

  name               = "osm-${each.key}-s3"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

data "aws_iam_policy_document" "monitoring_s3" {
  for_each = local.monitoring_components

  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.monitoring[each.key].arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.monitoring[each.key].arn}/*"]
  }
}

resource "aws_iam_role_policy" "monitoring_s3" {
  for_each = local.monitoring_components

  name   = "s3-access"
  role   = aws_iam_role.monitoring[each.key].id
  policy = data.aws_iam_policy_document.monitoring_s3[each.key].json
}

# service account з таким ім'ям створює чарт Loki (serviceAccount.name) та mimir.tf
resource "aws_eks_pod_identity_association" "monitoring" {
  for_each = local.monitoring_components

  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = kubernetes_namespace_v1.monitoring.metadata[0].name
  service_account = each.key
  role_arn        = aws_iam_role.monitoring[each.key].arn
}
