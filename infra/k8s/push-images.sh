#!/usr/bin/env bash
# Білдить і пушить образи fetcher/history в ECR-репозиторії, створені в ecr.tf.
# Запускати руками після terraform apply (ECR-репо мають вже існувати).
set -euo pipefail

cd "$(dirname "$0")"

REGION=eu-central-1

FETCHER_REPO=$(terraform output -raw fetcher_repository_url)
HISTORY_REPO=$(terraform output -raw history_repository_url)
REGISTRY="${FETCHER_REPO%%/*}"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

docker build -t "$FETCHER_REPO:latest" ../../osm-app/overpass-api-fetcher/osm-fetcher
docker push "$FETCHER_REPO:latest"

docker build -t "$HISTORY_REPO:latest" ../../osm-app/history/osm-history
docker push "$HISTORY_REPO:latest"

echo "Pushed:"
echo "  $FETCHER_REPO:latest"
echo "  $HISTORY_REPO:latest"
echo "(:latest + MUTABLE tag - після повторного push треба kubectl rollout restart)"
