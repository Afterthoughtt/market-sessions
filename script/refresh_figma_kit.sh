#!/bin/zsh
# Re-pull Apple's macOS 26 UI kit JSON into .build/reference (gitignored, ~25 MB).
# The Figma seat is capped (REST Tier 1 ≈ 20 calls/month): run this only when the kit changes.
# FIGMA_TOKEN (scope file_content:read) lives in ~/.zshrc; never print, copy, or commit it.
set -euo pipefail
source ~/.zshrc
mkdir -p .build/reference
curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" \
  https://api.figma.com/v1/files/Y5S76dMwnwkVKikaIg8Nxj \
  -o .build/reference/figma-macos26.json
echo "pulled $(date +%F): $(du -h .build/reference/figma-macos26.json | cut -f1)"
