#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# dotfiles-sync.sh  —  push / pull configs to/from GitHub
# Repo: git@github.com:BradyBangasser/config.git
# ──────────────────────────────────────────────────────────────

set -euo pipefail

DOTFILES_REPO="git@github.com:BradyBangasser/config.git"
DOTFILES_DIR="$HOME/.dotfiles"

# Files/dirs to track  (source path → path inside repo)
declare -A TARGETS=(
  ["$HOME/.bashrc"]="bashrc"
  ["$HOME/.config/starship.toml"]="starship.toml"
  ["$HOME/.config/nvim"]="nvim"
)

# ── helpers ────────────────────────────────────────────────────
log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
ok()   { printf '\e[1;32m  ✔\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m  ✘\e[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# ── ensure repo is cloned ──────────────────────────────────────
ensure_repo() {
  if [ ! -d "$DOTFILES_DIR/.git" ]; then
    log "Cloning dotfiles repo to $DOTFILES_DIR …"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
}

# ── copy live configs → repo ───────────────────────────────────
copy_to_repo() {
  log "Copying configs into repo …"
  for src in "${!TARGETS[@]}"; do
    dest="$DOTFILES_DIR/${TARGETS[$src]}"
    if [ -e "$src" ]; then
      if [ -d "$src" ]; then
        rsync -a --delete "$src/" "$dest/"
      else
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
      fi
      ok "$src"
    else
      err "$src not found, skipping"
    fi
  done
}

# ── copy repo → live configs ───────────────────────────────────
copy_from_repo() {
  log "Restoring configs from repo …"
  for src in "${!TARGETS[@]}"; do
    repo_path="$DOTFILES_DIR/${TARGETS[$src]}"
    if [ -e "$repo_path" ]; then
      if [ -d "$repo_path" ]; then
        mkdir -p "$src"
        rsync -a --delete "$repo_path/" "$src/"
      else
        mkdir -p "$(dirname "$src")"
        cp "$repo_path" "$src"
      fi
      ok "$src"
    else
      err "$repo_path not in repo, skipping"
    fi
  done
}

# ── push ──────────────────────────────────────────────────────
cmd_push() {
  ensure_repo
  copy_to_repo

  cd "$DOTFILES_DIR"
  git add -A

  if git diff --cached --quiet; then
    ok "Nothing changed — repo already up to date."
    return
  fi

  MSG="sync: $(date '+%Y-%m-%d %H:%M') on $(hostname)"
  git commit -m "$MSG"
  git push
  ok "Pushed → $DOTFILES_REPO"
}

# ── pull ──────────────────────────────────────────────────────
cmd_pull() {
  ensure_repo
  cd "$DOTFILES_DIR"

  log "Pulling latest from remote …"
  git pull --ff-only
  copy_from_repo
  ok "Configs restored from repo."
}

# ── status ────────────────────────────────────────────────────
cmd_status() {
  ensure_repo
  cd "$DOTFILES_DIR"
  log "Local diff (repo vs remote):"
  git fetch --quiet
  git status
  git log --oneline origin/HEAD..HEAD 2>/dev/null && true
}

# ── usage ─────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  push    Copy live configs into repo and push to GitHub
  pull    Pull from GitHub and restore configs
  status  Show repo status vs remote
EOF
}

# ── main ──────────────────────────────────────────────────────
case "${1:-}" in
  push)   cmd_push   ;;
  pull)   cmd_pull   ;;
  status) cmd_status ;;
  *)      usage; exit 1 ;;
esac
