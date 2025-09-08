#!/usr/bin/env bash
set -euo pipefail
docker build -t terramino-backend:local ./app/backend || true
docker build -t terramino-frontend:local ./app/frontend || true
