#!/usr/bin/env bash
# Shared launcher used by play.sh and edit.sh (Linux, e.g. Ubuntu).
# 1. Makes sure Godot 4.7.2 is in .tools/godot (downloads it from the official GitHub release if missing).
# 2. On the first run after cloning, imports the assets (creates the .godot folder).
# 3. Starts Godot on this project with the arguments given.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GDIR="$ROOT/.tools/godot"

case "$(uname -m)" in
  x86_64|amd64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac

GODOT="$GDIR/Godot_v4.7.2-stable_linux.$ARCH"
URL="https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.$ARCH.zip"

if [ ! -x "$GODOT" ]; then
  echo "Godot 4.7.2 not found in .tools/godot. Downloading from the official release (about 78 MB)..."
  mkdir -p "$GDIR"
  if command -v curl >/dev/null 2>&1; then
    curl -fL "$URL" -o "$GDIR/godot.zip"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$GDIR/godot.zip" "$URL"
  else
    echo "Need curl or wget to download Godot. Install one with: sudo apt install curl"
    exit 1
  fi
  if command -v unzip >/dev/null 2>&1; then
    unzip -o -q "$GDIR/godot.zip" -d "$GDIR"
  else
    python3 -m zipfile -e "$GDIR/godot.zip" "$GDIR"
  fi
  rm -f "$GDIR/godot.zip"
  chmod +x "$GODOT"
fi

if [ ! -d "$ROOT/.godot/imported" ]; then
  echo "First run: importing assets. This takes about a minute..."
  "$GODOT" --headless --path "$ROOT" --import || true
fi

exec "$GODOT" --path "$ROOT" "$@"
