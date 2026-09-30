#!/bin/zsh
# Re-pull Apple's macOS 27 UI kit JSON (owner's copy of the Community file) into .build/reference (gitignored).
# The Figma seat is capped (REST Tier 1 ≈ 20 calls/month): run this only when the kit changes.
# FIGMA_TOKEN (scope file_content:read) lives in ~/.zshrc; never print, copy, or commit it.
set -euo pipefail
source ~/.zshrc
mkdir -p .build/reference
curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" \
  https://api.figma.com/v1/files/ZXma61UBRxW4c4oz4PfZ66 \
  -o .build/reference/figma-macos27.json
echo "pulled $(date +%F): $(du -h .build/reference/figma-macos27.json | cut -f1)"
