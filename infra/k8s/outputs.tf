output "fetcher_repository_url" {
  value = aws_ecr_repository.fetcher.repository_url
}

output "history_repository_url" {
  value = aws_ecr_repository.history.repository_url
}
