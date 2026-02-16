#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="$ROOT_DIR/Docs/Architecture/Public_API_Baseline.txt"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

{
  echo "# CartKit Public API Baseline"
  echo "# Source root: ."
  echo
  echo "# Signature lines are extracted from public declarations in Sources/*.swift"
  echo "# Regenerate with: ./scripts/generate_public_api_baseline.sh"
  echo
  rg --glob '*.swift' --no-heading --line-number "^\\s*public\\s+(actor|class|struct|enum|protocol|typealias|init|func|var|let|subscript)\\b" "$ROOT_DIR/Sources" \
    | sed "s|$ROOT_DIR/||" \
    | sed -E 's/[[:space:]]+/ /g'
} > "$TMP_FILE"

mv "$TMP_FILE" "$OUT_FILE"
echo "Wrote $OUT_FILE"
