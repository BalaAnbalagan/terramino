#!/usr/bin/env bash
# Packages Vagrant machines into .box files (requires VirtualBox for vm-native).
set -euo pipefail
mkdir -p dist
# Ensure machines exist
vagrant status vm-native || true
# Package vm-native (VirtualBox)
vagrant package vm-native --output dist/terramino-vm-native.box
# Package docker-native (Docker provider) - results in a metadata-only box that assumes Docker on host
vagrant package docker-native --output dist/terramino-docker-native.box || echo "docker-native package may be provider-specific; ensure consumers have Docker installed."
sha256sum dist/*.box > dist/boxes.sha256
echo "Boxes in dist/, checksums in dist/boxes.sha256"
