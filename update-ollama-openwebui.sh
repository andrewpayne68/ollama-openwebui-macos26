#!/usr/bin/env bash
# =============================================================================
# update-ollama-openwebui.sh
# Updates Ollama and Open WebUI on macOS (bare metal / pipx install)
# Tested on: macOS 26 Tahoe, pipx + Python 3.12 venv managed by pipx
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

# Retry a curl health-check up to N times with a delay between attempts.
# Usage: wait_for_url <url> <max_attempts> <delay_seconds>
wait_for_url() {
  local url="$1" attempts="$2" delay="$3"
  local i=1
  while (( i <= attempts )); do
    if curl -s --max-time 5 "$url" &>/dev/null; then
      return 0
    fi
    info "Waiting for service… (${i}/${attempts})"
    sleep "$delay"
    (( i++ ))
  done
  return 1
}

# ── Detect Ollama install method ──────────────────────────────────────────────
detect_ollama_install() {
  if [[ -d "/Applications/Ollama.app" ]]; then
    echo "app"
  elif command_exists brew && brew list --formula ollama &>/dev/null; then
    echo "brew-formula"
  elif command_exists brew && brew list --cask ollama &>/dev/null; then
    echo "brew-cask"
  elif command_exists ollama; then
    echo "binary"   # manually installed binary
  else
    echo "none"
  fi
}

# ── Parse Ollama version string ───────────────────────────────────────────────
# `ollama --version` prints: "ollama version is X.Y.Z"
ollama_version() {
  ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown"
}

# ── Stop / start Ollama service (handles both .app and brew service) ──────────
ollama_stop() {
  info "Stopping Ollama service…"
  if pgrep -x "ollama" &>/dev/null; then
    pkill -x "ollama" 2>/dev/null || true
    sleep 2
  fi
  if pgrep -x "Ollama" &>/dev/null; then
    pkill -x "Ollama" 2>/dev/null || true
    sleep 2
  fi
  # Stop Homebrew service only if it is actually running (non-zero exit = not running → guard with || true)
  if command_exists brew && brew services list 2>/dev/null | grep -q "^ollama.*started"; then
    brew services stop ollama 2>/dev/null || true
  fi
  success "Ollama stopped."
}

ollama_start() {
  local method="$1"
  info "Restarting Ollama…"
  case "$method" in
    app)
      open -a Ollama
      ;;
    brew-formula)
      brew services start ollama
      ;;
    brew-cask)
      open -a Ollama
      ;;
    binary)
      nohup ollama serve &>/tmp/ollama.log &
      ;;
  esac
  # Retry up to 6 times, 3 s apart (18 s total) to accommodate slow .app startup
  if wait_for_url "http://localhost:11434/api/version" 6 3; then
    success "Ollama is running."
  else
    warn "Ollama may still be starting. Check manually: curl http://localhost:11434/api/version"
  fi
}

# =============================================================================
# 1. UPDATE OLLAMA
# =============================================================================
update_ollama() {
  header "━━━  Updating Ollama  ━━━"

  local method
  method=$(detect_ollama_install)

  if [[ "$method" == "none" ]]; then
    warn "Ollama not found. Skipping Ollama update."
    return
  fi

  # Record current version
  local before_version="unknown"
  if command_exists ollama; then
    before_version=$(ollama_version)
    info "Current Ollama version: ${before_version}"
  fi

  case "$method" in
    # ── .app bundle (downloaded from ollama.com) ────────────────────────────
    app)
      info "Install method: .app bundle"
      info "Downloading latest Ollama.app from ollama.com…"
      local tmpdir
      tmpdir=$(mktemp -d)
      # Ensure tmpdir is always removed, even on error
      trap 'rm -rf "${tmpdir}"' RETURN
      local zip_path="${tmpdir}/Ollama.zip"

      curl -fL "https://ollama.com/download/Ollama-darwin.zip" -o "$zip_path"

      # Basic sanity check: ZIP must be at least 1 MB
      local zip_size
      zip_size=$(stat -f%z "$zip_path" 2>/dev/null || echo 0)
      if (( zip_size < 1048576 )); then
        error "Downloaded ZIP looks too small (${zip_size} bytes). Aborting to protect existing install."
        return 1
      fi

      info "Download complete (${zip_size} bytes). Installing…"
      ollama_stop

      # Backup old app
      if [[ -d "/Applications/Ollama.app" ]]; then
        rm -rf "/Applications/Ollama.app.bak"
        cp -R "/Applications/Ollama.app" "/Applications/Ollama.app.bak"
      fi

      unzip -q -o "$zip_path" -d "/Applications/"

      # Clear macOS quarantine flag set on freshly extracted bundles
      if command_exists xattr; then
        xattr -dr com.apple.quarantine "/Applications/Ollama.app" 2>/dev/null || true
      fi

      success "Ollama.app updated."
      ollama_start "app"
      ;;

    # ── Homebrew formula ─────────────────────────────────────────────────────
    brew-formula)
      info "Install method: Homebrew formula"
      ollama_stop
      brew update
      brew upgrade ollama
      ollama_start "brew-formula"
      ;;

    # ── Homebrew cask ─────────────────────────────────────────────────────────
    brew-cask)
      info "Install method: Homebrew cask"
      ollama_stop
      brew update
      brew upgrade --cask ollama
      ollama_start "brew-cask"
      ;;

    # ── Standalone binary ─────────────────────────────────────────────────────
    binary)
      info "Install method: standalone binary"
      warn "Updating via the official install script (re-runs installer)…"
      ollama_stop
      curl -fsSL https://ollama.com/install.sh | sh
      ollama_start "binary"
      ;;
  esac

  # Print new version
  if command_exists ollama; then
    local after_version
    after_version=$(ollama_version)
    if [[ "$before_version" != "$after_version" ]]; then
      success "Ollama updated: ${before_version} → ${after_version}"
    else
      success "Ollama is already up to date (${after_version})."
    fi
  fi
}

# =============================================================================
# 2. UPDATE OPEN WEBUI
# =============================================================================
update_openwebui() {
  header "━━━  Updating Open WebUI  ━━━"

  # ── Verify pipx is available ──────────────────────────────────────────────
  if ! command_exists pipx; then
    error "pipx not found. Install it first: brew install pipx && pipx ensurepath"
    return 1
  fi

  info "Using: $(which pipx)  ($(pipx --version))"

  # Check open-webui is actually installed via pipx
  if ! pipx list 2>/dev/null | grep -q "open-webui"; then
    warn "open-webui is not installed via pipx. Skipping."
    info "To install: pipx install open-webui"
    return
  fi

  # Record current version — pipx list line format: "   package open-webui X.Y.Z, ..."
  # Use $3 (the version field) and strip any trailing comma.
  local before_version
  before_version=$(pipx list 2>/dev/null \
    | awk '/package open-webui/{print $3}' \
    | tr -d ',' \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    || echo "unknown")
  info "Current Open WebUI version: ${before_version}"

  # ── Check if Open WebUI is running and stop it ────────────────────────────
  local webui_was_running=false
  if pgrep -f "open-webui" &>/dev/null || pgrep -f "openwebui" &>/dev/null; then
    webui_was_running=true
    info "Stopping Open WebUI…"
    pkill -f "open-webui" 2>/dev/null || true
    pkill -f "openwebui" 2>/dev/null || true
    sleep 2
    success "Open WebUI stopped."
  fi

  # ── Upgrade open-webui via pipx ───────────────────────────────────────────
  info "Upgrading open-webui via pipx…"
  pipx upgrade open-webui

  local after_version
  after_version=$(pipx list 2>/dev/null \
    | awk '/package open-webui/{print $3}' \
    | tr -d ',' \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    || echo "unknown")

  if [[ "$before_version" != "$after_version" ]]; then
    success "Open WebUI updated: ${before_version} → ${after_version}"
  else
    success "Open WebUI is already up to date (${after_version})."
  fi

  # ── Restart if it was running ─────────────────────────────────────────────
  if [[ "$webui_was_running" == true ]]; then
    info "Restarting Open WebUI…"
    nohup open-webui serve &>/tmp/open-webui.log &
    # Retry up to 15 times, 5 s apart (75 s total) — Open WebUI runs DB migrations on first start
    if wait_for_url "http://localhost:8080" 15 5; then
      success "Open WebUI is back online at http://localhost:8080"
    else
      warn "Open WebUI may still be starting up. Tail logs: tail -f /tmp/open-webui.log"
    fi
  else
    info "Open WebUI was not running — not auto-starting."
    info "To start manually: open-webui serve"
  fi

  # Remind about browser cache
  warn "Tip: clear your browser cache after a major Open WebUI update."
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  # ── Handle help flag before printing the banner ───────────────────────────
  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        echo "Usage: $0 [--ollama-only] [--webui-only]"
        echo ""
        echo "  --ollama-only   Update Ollama only, skip Open WebUI"
        echo "  --webui-only    Update Open WebUI only, skip Ollama"
        echo "  --help, -h      Show this help message"
        exit 0
        ;;
    esac
  done

  echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║   Ollama + Open WebUI — macOS Updater        ║${RESET}"
  echo -e "${BOLD}║   macOS 26 Tahoe · pipx · Bare Metal         ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
  echo ""

  # Optional flags: --ollama-only  --webui-only
  local do_ollama=true
  local do_webui=true

  for arg in "$@"; do
    case "$arg" in
      --ollama-only) do_webui=false ;;
      --webui-only)  do_ollama=false ;;
    esac
  done

  [[ "$do_ollama" == true ]] && update_ollama
  [[ "$do_webui"  == true ]] && update_openwebui

  header "━━━  Done  ━━━"
  echo ""
  [[ "$do_ollama" == true ]] && echo -e "  Ollama API  →  ${CYAN}http://localhost:11434${RESET}"
  [[ "$do_webui"  == true ]] && echo -e "  Open WebUI  →  ${CYAN}http://localhost:8080${RESET}"
  echo ""
}

main "$@"