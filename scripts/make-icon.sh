#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

swift build
BIN_DIR="$(swift build --show-bin-path)"
"$BIN_DIR/Kello" --render-icon "$WORKDIR"

iconutil -c icns "$WORKDIR/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"

echo "Wrote $ROOT/Resources/AppIcon.icns"
