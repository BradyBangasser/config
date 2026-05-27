#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# install.sh  —  one-line installer for dotfile-sync
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/BradyBangasser/config/main/install.sh)
# ──────────────────────────────────────────────────────────────

set -euo pipefail

REPO="git@github.com:BradyBangasser/config.git"
DOTFILES_DIR="$HOME/.dotfiles"
BIN_DIR="$HOME/.local/bin"
RAW_BASE="https://raw.githubusercontent.com/BradyBangasser/config/main"

# ── helpers ───────────────────────────────────────────────────
log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
ok()   { printf '\e[1;32m  ✔\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m  ✘\e[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }
need() { command -v "$1" &>/dev/null || die "'$1' is required but not installed."; }

# ── detect OS ─────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Linux)  PLATFORM="linux"  ;;
  Darwin) PLATFORM="macos"  ;;
  *)      die "Unsupported OS: $OS" ;;
esac
log "Detected platform: $PLATFORM"

# ── preflight ─────────────────────────────────────────────────
log "Checking dependencies ..."
need git
need curl
ok "All dependencies present"

# ── directories ───────────────────────────────────────────────
log "Creating directories ..."
mkdir -p "$BIN_DIR"
ok "$BIN_DIR"

# ── install dotfile.sh ────────────────────────────────────────
log "Installing dotfile.sh ..."
curl -fsSL "$RAW_BASE/dotfile.sh" -o "$BIN_DIR/dotfile.sh"
chmod +x "$BIN_DIR/dotfile.sh"
ok "$BIN_DIR/dotfile.sh"

# ── ensure BIN_DIR is on PATH ─────────────────────────────────
if ! [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
  export PATH="$BIN_DIR:$PATH"
  ok "PATH updated for this session"
fi

# ── install auto-sync scheduler ───────────────────────────────
install_linux() {
  local SYSTEMD_DIR="$HOME/.config/systemd/user"
  mkdir -p "$SYSTEMD_DIR"

  log "Installing systemd units ..."
  curl -fsSL "$RAW_BASE/dotfile.service" -o "$SYSTEMD_DIR/dotfile.service"
  curl -fsSL "$RAW_BASE/dotfile.timer"   -o "$SYSTEMD_DIR/dotfile.timer"
  ok "dotfile.service"
  ok "dotfile.timer"

  log "Enabling systemd timer ..."
  systemctl --user daemon-reload
  systemctl --user enable --now dotfile.timer
  ok "dotfile.timer enabled and started"
}

install_macos() {
  local PLIST_DIR="$HOME/Library/LaunchAgents"
  local PLIST_NAME="com.bradybangasser.dotfile-sync.plist"
  local PLIST_PATH="$PLIST_DIR/$PLIST_NAME"

  mkdir -p "$PLIST_DIR"

  log "Installing launchd plist ..."
  curl -fsSL "$RAW_BASE/dotfile.plist" -o "$PLIST_PATH"

  # Inject the real path to dotfile.sh
  sed -i '' "s|DOTFILE_SH_PATH|$BIN_DIR/dotfile.sh|g" "$PLIST_PATH"
  ok "$PLIST_PATH"

  log "Loading launchd agent ..."
  # Unload first in case it's already loaded
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH"
  ok "launchd agent loaded (runs every hour)"
}

case "$PLATFORM" in
  linux) install_linux ;;
  macos) install_macos ;;
esac

# ── clone / update dotfiles repo ──────────────────────────────
if [ -d "$DOTFILES_DIR/.git" ]; then
  log "Dotfiles repo already cloned — pulling latest ..."
  git -C "$DOTFILES_DIR" pull --ff-only
else
  log "Cloning dotfiles repo ..."
  git clone "$REPO" "$DOTFILES_DIR"
fi
ok "Repo ready at $DOTFILES_DIR"

# ── restore configs ───────────────────────────────────────────
log "Restoring configs from repo ..."
"$BIN_DIR/dotfile.sh" pull

# ── done ──────────────────────────────────────────────────────
echo ""
echo -e "\e[1;32m✔ dotfile-sync installed successfully on $PLATFORM!\e[0m"
echo ""
echo "  Manual commands:"
echo "    dotfile.sh push    # commit & push configs"
echo "    dotfile.sh pull    # restore configs from GitHub"
echo "    dotfile.sh status  # check sync status"
echo ""
if [ "$PLATFORM" = "linux" ]; then
  echo "  Auto-sync: runs every hour via systemd"
  echo "    systemctl --user status dotfile.timer"
else
  echo "  Auto-sync: runs every hour via launchd"
  echo "    launchctl list | grep dotfile"
fi
echo ""
