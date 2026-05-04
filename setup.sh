#!/usr/bin/env bash
# setup.sh — Bootstrap farty-bobo config on a new machine.
# Run from anywhere: bash /path/to/farty-bobo/setup.sh
#
# Flags:
#   --links-only   Skip .env bootstrap and node/nvm install; just refresh symlinks.
#                  Safe to run on every Claude Code session start as a self-heal.
#   --quiet        Suppress success lines (warnings/errors still print).

set -euo pipefail

LINKS_ONLY=false
QUIET=false
for arg in "$@"; do
  case "$arg" in
    --links-only) LINKS_ONLY=true ;;
    --quiet)      QUIET=true ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_DESKTOP_DIR="$HOME/Library/Application Support/Claude"
LOCAL_BIN="$HOME/.local/bin"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

if $QUIET; then
  ok() { :; }
else
  ok() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
fi
warn() { printf "${YELLOW}!${RESET} %s\n" "$1"; }
err()  { printf "${RED}✗${RESET} %s\n" "$1"; }

# ── ~/.claude dir ────────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR"
ok "~/.claude exists"

# ── Symlinks: files ──────────────────────────────────────────────
symlink_file() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || { err "Source not found: $src"; exit 1; }
  ln -sf "$src" "$dst" || { err "Failed to create symlink: $dst"; exit 1; }
  ok "$(basename "$dst") → $src"
}

# Symlinks: directories
symlink_dir() {
  local src="$1" dst="$2"
  [[ -d "$src" ]] || { err "Source not found: $src"; exit 1; }
  ln -sfn "$src" "$dst" || { err "Failed to create symlink: $dst"; exit 1; }
  ok "$(basename "$dst")/ → $src"
}

symlink_file "$REPO_DIR/settings.json"  "$CLAUDE_DIR/settings.json"
symlink_file "$REPO_DIR/CLAUDE.md"      "$CLAUDE_DIR/CLAUDE.md"
symlink_dir  "$REPO_DIR/commands"       "$CLAUDE_DIR/commands"
symlink_dir  "$REPO_DIR/hooks"          "$CLAUDE_DIR/hooks"
symlink_dir  "$REPO_DIR/skills"         "$CLAUDE_DIR/skills"

symlink_file "$REPO_DIR/claude-desktop/mcp-versions.env" "$CLAUDE_DIR/mcp-versions.env"
chmod 600 "$REPO_DIR/claude-desktop/mcp-versions.env"
symlink_file "$REPO_DIR/.mcp.json"      "$CLAUDE_DIR/.mcp.json"
symlink_dir  "$REPO_DIR/claude-desktop/scripts" "$CLAUDE_DIR/scripts"

# Make wrapper scripts executable (skip gracefully if none exist yet)
if compgen -G "$CLAUDE_DIR/scripts/*.sh" > /dev/null 2>&1; then
  chmod +x "$CLAUDE_DIR/scripts/"*.sh
  ok "scripts/*.sh marked executable"
fi

# ── codex shim ───────────────────────────────────────────────────
# Runs in both full and --links-only mode so the shim is always wired up.
mkdir -p "$LOCAL_BIN"
CODEX_SHIM="$REPO_DIR/claude-desktop/scripts/codex-shim.sh"
if [[ -f "$CODEX_SHIM" ]]; then
  ln -sf "$CODEX_SHIM" "$LOCAL_BIN/codex"
  ok "codex shim symlinked to ~/.local/bin/codex"
else
  warn "codex-shim.sh not found — skipping codex symlink"
fi

# ── Codex skill symlinks ─────────────────────────────────────────
# Codex loads skills from ~/.codex/skills/<name>/SKILL.md (uppercase).
# Claude Code uses skill.md (lowercase). Create SKILL.md symlinks so both
# tools share the same source files — no duplication, no drift.
CODEX_SKILLS_DIR="$HOME/.codex/skills"
if [[ -d "$CODEX_SKILLS_DIR" ]]; then
  skill_count=0
  for skill_dir in "$REPO_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "${skill_dir%/}")"
    src="$REPO_DIR/skills/$skill_name/skill.md"
    dst_dir="$CODEX_SKILLS_DIR/$skill_name"
    mkdir -p "$dst_dir"
    ln -sf "$src" "$dst_dir/SKILL.md"
    skill_count=$((skill_count + 1))
  done
  ok "$skill_count skills symlinked to ~/.codex/skills/"
else
  warn "~/.codex/skills not found — skipping Codex skill symlinks (install Codex first)"
fi

# ── Codex MCP servers ────────────────────────────────────────────
# Register the MCP servers from claude_desktop_config.json into Codex.
# Codex stores servers in ~/.codex/config.toml; command/args format is
# identical to Claude Desktop's mcpServers — same wrapper scripts work.
# Idempotent: skips servers that are already registered.
DESKTOP_CONFIG="$REPO_DIR/claude-desktop/claude_desktop_config.json"
CODEX_BIN="$LOCAL_BIN/codex"
if [[ -x "$CODEX_BIN" ]] && [[ -f "$DESKTOP_CONFIG" ]]; then
  python3 - "$DESKTOP_CONFIG" "$CODEX_BIN" <<'PYEOF'
import json, re, subprocess, sys

config_path, codex_bin = sys.argv[1], sys.argv[2]
with open(config_path) as f:
    servers = json.load(f).get("mcpServers", {})

for name, cfg in servers.items():
    # Codex only allows letters, numbers, '-', '_' in server names.
    codex_name = re.sub(r"[^a-zA-Z0-9_-]", "-", name)
    already = subprocess.run(
        [codex_bin, "mcp", "get", codex_name], capture_output=True
    ).returncode == 0
    if already:
        print(f"  (codex MCP) {codex_name}: already registered")
        continue
    cmd = [codex_bin, "mcp", "add", codex_name, "--"] + [cfg["command"]] + cfg.get("args", [])
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode == 0:
        print(f"  (codex MCP) {codex_name}: registered")
    else:
        print(f"  ! (codex MCP) {codex_name}: failed — {r.stderr.strip()}", file=sys.stderr)
PYEOF
elif [[ ! -x "$CODEX_BIN" ]]; then
  warn "codex not found at $CODEX_BIN — skipping MCP registration (run setup.sh again after installing Codex)"
fi

# ── Claude Desktop config (macOS only) ──────────────────────────
if [[ "$OSTYPE" == darwin* ]]; then
  mkdir -p "$CLAUDE_DESKTOP_DIR"
  symlink_file "$REPO_DIR/claude-desktop/claude_desktop_config.json" \
    "$CLAUDE_DESKTOP_DIR/claude_desktop_config.json"
fi

# ── .env setup ──────────────────────────────────────────────────
ENV_SRC="$REPO_DIR/.env"
ENV_DST="$CLAUDE_DIR/mcp.env"

if $LINKS_ONLY; then
  # Re-link only if .env already exists; never bootstrap silently on session start.
  if [[ -f "$ENV_SRC" ]]; then
    ln -sf "$ENV_SRC" "$ENV_DST"
  fi
else
  ENV_IS_NEW=false
  if [[ ! -f "$ENV_SRC" ]]; then
    ENV_IS_NEW=true
    if [[ -f "$REPO_DIR/.env.sample" ]]; then
      cp "$REPO_DIR/.env.sample" "$ENV_SRC"
    else
      touch "$ENV_SRC"
    fi
  fi

  ln -sf "$ENV_SRC" "$ENV_DST"
  chmod 600 "$ENV_SRC"
  ok "mcp.env → $ENV_SRC (permissions: 600)"

  if [[ "$ENV_IS_NEW" == true ]]; then
    warn "EDIT YOUR FUCKING .env FILE: $ENV_SRC"
  else
    warn ".env already exists — if new env vars were added to .env.sample, add them manually to: $ENV_SRC"
  fi
fi

if ! $LINKS_ONLY; then
  # ── node: install pinned version via nvm, expose to /bin/sh ─────
  # Claude Code hooks run under /bin/sh which doesn't load nvm.
  # We install the pinned version from .nvmrc and create shims in
  # ~/.local/bin (no sudo required) so /bin/sh can find node/npm/npx.

  NODE_VERSION_FILE="$REPO_DIR/.nvmrc"
  NODE_VERSION=$(cat "$NODE_VERSION_FILE" | tr -d '[:space:]')
  NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  # Load nvm if available and install the pinned version
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh" --no-use
    if ! nvm ls "$NODE_VERSION" &>/dev/null; then
      printf "  Installing node %s via nvm...\n" "$NODE_VERSION"
      nvm install "$NODE_VERSION"
    fi
    # Resolve binary path: try nvm which first, fall back to glob
    NVM_NODE_PATH="$(nvm which "$NODE_VERSION" 2>/dev/null)" \
      || NVM_NODE_PATH="$(ls "$NVM_DIR/versions/node/"v"$NODE_VERSION"*/bin/node 2>/dev/null | sort -V | tail -1)"
    NVM_NODE_BIN="$(dirname "$NVM_NODE_PATH")"
    if [[ -x "$NVM_NODE_BIN/node" ]]; then
      ln -sf "$NVM_NODE_BIN/node" "$LOCAL_BIN/node"
      ln -sf "$NVM_NODE_BIN/npm"  "$LOCAL_BIN/npm"
      ln -sf "$NVM_NODE_BIN/npx"  "$LOCAL_BIN/npx"
      ok "node $("$NVM_NODE_BIN/node" --version) symlinked to ~/.local/bin (from nvm)"
    else
      err "nvm install succeeded but binary not found at $NVM_NODE_BIN"
      exit 1
    fi
  else
    err "nvm not found — install nvm first, then rerun setup.sh"
    err "See: https://github.com/nvm-sh/nvm"
    exit 1
  fi

  # Remind if ~/.local/bin isn't on PATH
  if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    warn "Add ~/.local/bin to your PATH so shells can find node:"
    warn "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
  fi
fi

# ── Done ─────────────────────────────────────────────────────────
if ! $QUIET; then
  printf "\n${GREEN}Setup complete.${RESET} Restart Claude Desktop for changes to take effect.\n"
fi
