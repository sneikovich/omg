#!/usr/bin/env bash
# Білдить і пушить образи fetcher/history в ECR-репозиторії, створені в ecr.tf.
# Запускати руками після terraform apply (ECR-репо мають вже існувати).
set -euo pipefail

cd "$(dirname "$0")"

REGION=eu-central-1

if command -v podman >/dev/null 2>&1; then
  ENGINE=podman
elif command -v docker >/dev/null 2>&1; then
  ENGINE=docker
else
  echo "Потрібен podman або docker у PATH" >&2
  exit 1
fi

FETCHER_REPO=$(terraform output -raw fetcher_repository_url)
HISTORY_REPO=$(terraform output -raw history_repository_url)
REGISTRY="${FETCHER_REPO%%/*}"

aws ecr get-login-password --region "$REGION" | "$ENGINE" login --username AWS --password-stdin "$REGISTRY"

"$ENGINE" build -t "$FETCHER_REPO:latest" ../../osm-app/overpass-api-fetcher/osm-fetcher
"$ENGINE" push "$FETCHER_REPO:latest"

"$ENGINE" build -t "$HISTORY_REPO:latest" ../../osm-app/history/osm-history
"$ENGINE" push "$HISTORY_REPO:latest"

echo "Pushed ($ENGINE):"
echo "  $FETCHER_REPO:latest"
echo "  $HISTORY_REPO:latest"
echo "(:latest + MUTABLE tag - після повторного push треба kubectl rollout restart)"
