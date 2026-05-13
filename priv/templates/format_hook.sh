#!/usr/bin/env bash

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Only format Elixir files
if [[ "$FILE_PATH" =~ \.(ex|exs)$ ]] && [[ -n "$CWD" ]]; then
  cd "$CWD"
  nix develop --command mix format "$FILE_PATH" 2>/dev/null || true
fi

exit 0
