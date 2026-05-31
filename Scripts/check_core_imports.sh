#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_DIR="$ROOT/MusicWall/Core"
FORBIDDEN='^import (MusicKit|SwiftUI|UIKit)'

if [[ ! -d "$CORE_DIR" ]]; then
  echo "error: $CORE_DIR not found" >&2
  exit 2
fi

if command -v rg >/dev/null 2>&1; then
  if matches=$(rg -n "$FORBIDDEN" "$CORE_DIR" 2>/dev/null); then
    echo "error: MusicWall/Core must not import MusicKit, SwiftUI, or UIKit:" >&2
    echo "$matches" >&2
    exit 1
  fi
elif matches=$(grep -REn "$FORBIDDEN" "$CORE_DIR" 2>/dev/null || true); then
  if [[ -n "$matches" ]]; then
    echo "error: MusicWall/Core must not import MusicKit, SwiftUI, or UIKit:" >&2
    echo "$matches" >&2
    exit 1
  fi
fi

echo "ok: $CORE_DIR has no MusicKit/SwiftUI/UIKit imports"
