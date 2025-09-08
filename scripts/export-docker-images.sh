#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist
docker save terramino-backend:local | gzip -c > dist/terramino-backend_local.tar.gz
docker save terramino-frontend:local | gzip -c > dist/terramino-frontend_local.tar.gz
sha256sum dist/* > dist/checksums.sha256
echo "Exported images to dist/, checksums in dist/checksums.sha256"
