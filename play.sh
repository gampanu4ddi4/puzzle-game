#!/usr/bin/env bash
# Runs the game (starts at puzzle 1-1).
exec "$(dirname "${BASH_SOURCE[0]}")/tools/godot.sh" "$@"
