output "ecr_api_url" {
    value = aws_ecr_repository.api_repo.repository_url
}

output "ecr_db_url" {
    value = aws_ecr_repository.db_repo.repository_url
}