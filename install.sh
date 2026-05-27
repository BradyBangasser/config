#!/usr/bin/env bash
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/BradyBangasser/config/main/install.sh)

set -euo pipefail

REPO="git@github.com:BradyBangasser/config.git"
DOTFILES_DIR="$HOME/.dotfiles"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"

RAW_BASE="https://raw.githubusercontent.com/BradyBangasser/config/main"

# ── helpers ───────────────────────────────────────────────────
log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
ok()   { printf '\e[1;32m  ✔\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m  ✘\e[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

need() {
  command -v "$1" &>/dev/null || die "'$1' is required but not installed."
}

# ── preflight ─────────────────────────────────────────────────
log "Checking dependencies …"
need git
need systemctl
ok "All dependencies present"

# ── directories ───────────────────────────────────────────────
log "Creating directories …"
mkdir -p "$BIN_DIR" "$SYSTEMD_DIR"
ok "$BIN_DIR"
ok "$SYSTEMD_DIR"

# ── install sync script ───────────────────────────────────────
log "Installing dotfile.sh …"
curl -fsSL "$RAW_BASE/dotfile.sh" -o "$BIN_DIR/dotfile.sh"
chmod +x "$BIN_DIR/dotfile.sh"
ok "$BIN_DIR/dotfile.sh"

# ── install systemd units ─────────────────────────────────────
log "Installing systemd units …"
curl -fsSL "$RAW_BASE/dotfiles-sync.service" -o "$SYSTEMD_DIR/dotfiles-sync.service"
curl -fsSL "$RAW_BASE/dotfiles-sync.timer"   -o "$SYSTEMD_DIR/dotfiles-sync.timer"
ok "dotfiles-sync.service"
ok "dotfiles-sync.timer"

# ── ensure $BIN_DIR is on PATH (for this session + future) ────
if ! [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
  log "Adding $BIN_DIR to PATH for this session …"
  export PATH="$BIN_DIR:$PATH"
  ok "PATH updated (already permanent via your .bashrc)"
fi

# ── clone / update dotfiles repo ──────────────────────────────
if [ -d "$DOTFILES_DIR/.git" ]; then
  log "Dotfiles repo already cloned — pulling latest …"
  git -C "$DOTFILES_DIR" pull --ff-only
else
  log "Cloning dotfiles repo …"
  git clone "$REPO" "$DOTFILES_DIR"
fi
ok "Repo ready at $DOTFILES_DIR"

# ── restore configs from repo ─────────────────────────────────
log "Restoring configs from repo …"
dotfile.sh pull

# ── enable systemd timer ──────────────────────────────────────
log "Enabling auto-sync timer …"
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-sync.timer
ok "dotfiles-sync.timer enabled and started"

# ── done ──────────────────────────────────────────────────────
echo ""
echo -e "\e[1;32m✔ dotfiles-sync installed successfully!\e[0m"
echo ""
echo "  Manual commands:"
echo "    dotfile.sh push    # commit & push configs"
echo "    dotfile.sh pull    # restore configs from GitHub"
echo "    dotfile.sh status  # check sync status"
echo ""
echo "  Auto-sync: runs every hour via systemd timer"
echo "    systemctl --user status dotfiles-sync.timer"
echo ""
