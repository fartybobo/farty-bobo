#!/usr/bin/env bash
# Portable codex shim. Finds the @openai/codex binary under any nvm-managed
# node version and execs it. Symlinked to ~/.local/bin/codex by setup.sh so
# Claude Code's shell can find it regardless of which node version is active.
set -euo pipefail

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ ! -d "$NVM_DIR/versions/node" ]]; then
  echo "ERROR: nvm node versions not found at $NVM_DIR/versions/node." >&2
  echo "Install nvm and at least one node version first." >&2
  exit 1
fi

# Pick the newest codex bin across all installed node versions.
# Portable sort: extract major.minor.patch from path, sort numerically.
# Avoids sort -V which is GNU coreutils only (not available on macOS BSD sort).
# maxdepth 3: $NVM_DIR/versions/node/<version>/bin/codex is exactly 3 levels deep.
CODEX_BIN=$(
  find "$NVM_DIR/versions/node" -maxdepth 3 -name "codex" -path "*/bin/codex" 2>/dev/null \
    | sed 's|.*/node/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/bin/codex$|\1 \2 \3 &|' \
    | grep -E '^[0-9]' \
    | sort -k1,1n -k2,2n -k3,3n \
    | awk '{print $4}' \
    | tail -1
)

if [[ -z "$CODEX_BIN" ]]; then
  echo "ERROR: codex not found under any nvm node version." >&2
  echo "Install it with: npm install -g @openai/codex" >&2
  exit 1
fi

exec "$CODEX_BIN" "$@"
