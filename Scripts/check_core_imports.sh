#!/usr/bin/env bash
set -euo pipefail

CORE_DIR="MusicWall/Core"
FORBIDDEN='^import (MusicKit|SwiftUI|UIKit)'

if [[ ! -d "$CORE_DIR" ]]; then
  echo "error: $CORE_DIR not found" >&2
  exit 2
fi

if matches=$(rg -n "$FORBIDDEN" "$CORE_DIR" 2>/dev/null); then
  echo "error: MusicWall/Core must not import MusicKit, SwiftUI, or UIKit:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "ok: $CORE_DIR has no MusicKit/SwiftUI/UIKit imports"
