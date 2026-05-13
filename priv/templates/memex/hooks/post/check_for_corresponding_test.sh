#!/usr/bin/env bash
#
# Post-write test-presence check — delegates to `memex hook-advice`.
# Patterns live in docs/phoenix-liveview/hooks.toml.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[[ -n "$FILE_PATH" && -n "$CWD" ]] || exit 0

cd "$CWD" || exit 0
memex hook-advice "$FILE_PATH" --event post-write --claude-hook 2>/dev/null || true

exit 0
