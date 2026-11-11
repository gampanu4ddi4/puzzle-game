#!/usr/bin/env bash
# Opens the project in the Godot editor.
exec "$(dirname "${BASH_SOURCE[0]}")/tools/godot.sh" -e "$@"
