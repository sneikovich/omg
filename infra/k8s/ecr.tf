# репозиторії для образів osm-app (fetcher, history); frontend більше не має власного
# образу - його статика йде напряму в S3 (див. frontend.tf)
resource "aws_ecr_repository" "fetcher" {
  name                 = "fetcher"
  image_tag_mutability = "MUTABLE"

  # дозволяє terraform destroy цього модуля навіть якщо в репозиторії лишились образи
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "history" {
  name                 = "history"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
