#!/usr/bin/env bash
# scout-scanner-analyzer-cli.sh - Scout Scanner Analyzer Installer
# VAOS / TheAvaGroup
# Implements: check, install, execute, run, runtime-check, runtime-install, self-check
set -euo pipefail

VAOS_ROOT="${VAOS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VAOS_ROOT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
require() { command -v "$1" >/dev/null 2>&1 || error "Required: $1"; }

usage() {
  cat <<EOF
${GREEN}Scout Scanner Analyzer CLI Installer${NC}
VAOS / TheAvaGroup

Usage: $(basename "$0") <command> [--help]

Entity Scope: installer | Category: analysis | Runtime: uv (OPTIONAL)

Commands:
  check           Check Scout installation
  install         Install Scout scanner
  execute <cmd>   Execute Scout command (scan|analyze|report)
  run <script>    Run script with uv/python3 runtime
  runtime-check   Check runtime dependencies (uv, python3)
  runtime-install Install runtime dependencies
  self-check      Run self-diagnostic check
  self-status     Show component status
  self-version    Show component version

Options:
  --help, -h      Show this help
  --version, -v   Show Python version

Examples:
  $(basename "$0") check
  $(basename "$0") install
  $(basename "$0") execute scan
  $(basename "$0") run script.py
  $(basename "$0") runtime-install
EOF
}

cmd_check() {
  info "Checking Scout installation..."
  local status=0
  
  if command -v python3 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} python3: $(python3 --version)"
  else
    echo -e "${RED}✗${NC} python3: not found"
    status=1
  fi
  
  if command -v uv >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} uv: $(uv --version)"
  else
    warn "uv: not found (optional)"
  fi
  
  return $status
}

cmd_install() {
  info "Installing Scout scanner..."
  require python3
  
  if command -v uv >/dev/null 2>&1; then
    uv pip install scout
  else
    pip3 install scout
  fi
  
  info "Scout installation complete"
}

cmd_execute() {
  shift
  local cmd="${1:-scan}"
  info "Executing Scout: $cmd"
  
  case "$cmd" in
    scan)
      info "Hint: scout scan <target-directory>"
      ;;
    analyze)
      info "Hint: scout analyze <results>"
      ;;
    report)
      info "Hint: scout report <results>"
      ;;
    *)
      error "Unknown Scout command: $cmd"
      ;;
  esac
}

cmd_runtime_check() {
  info "Checking runtime dependencies (OPTIONAL: uv, python3)..."
  local status=0
  
  if command -v python3 >/dev/null 2>&1; then
    local py_ver=$(python3 --version | awk '{print $2}')
    echo -e "${GREEN}✓${NC} python3: $py_ver"
    local major=$(echo "$py_ver" | cut -d. -f1)
    local minor=$(echo "$py_ver" | cut -d. -f2)
    if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 8 ]); then
      warn "Python 3.8+ recommended"
    fi
  else
    echo -e "${RED}✗${NC} python3: not found"
    status=1
  fi
  
  if command -v uv >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} uv: $(uv --version)"
  else
    warn "uv: not found (optional)"
  fi
  
  return $status
}

cmd_runtime_install() {
  info "Installing runtime dependencies..."
  
  if ! command -v python3 >/dev/null 2>&1; then
    error "Python 3 required but not found"
  fi
  
  if ! command -v uv >/dev/null 2>&1; then
    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  
  info "Runtime installation complete"
}

cmd_run() {
  shift
  local script="$1"
  shift
  local args="$@"
  
  if [ -z "$script" ]; then
    error "Usage: $(basename "$0") run <script> [args...]"
  fi
  
  if ! command -v uv >/dev/null 2>&1; then
    if ! command -v python3 >/dev/null 2>&1; then
      error "Python runtime not found. Run '$(basename "$0") runtime-install' first"
    fi
    warn "uv not found, using python3 directly"
    python3 "$script" $args
  else
    info "Running $script with uv..."
    uv run python3 "$script" $args
  fi
}

cmd_self_check() {
  info "Running self-diagnostic..."
  local errors=0
  
  local self_path="${BASH_SOURCE[0]}"
  if [ -f "$self_path" ] && [ -x "$self_path" ]; then
    echo -e "${GREEN}✓${NC} Self: executable"
  else
    echo -e "${RED}✗${NC} Self: not found or not executable"
    ((errors++))
  fi
  
  if [ -n "$VAOS_ROOT" ] && [ -d "$VAOS_ROOT" ]; then
    echo -e "${GREEN}✓${NC} VAOS_ROOT: $VAOS_ROOT"
  else
    echo -e "${YELLOW}!${NC} VAOS_ROOT: not set or invalid"
  fi
  
  if command -v python3 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} python3: $(python3 --version)"
  else
    echo -e "${RED}✗${NC} python3: not found"
    ((errors++))
  fi
  
  if command -v uv >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} uv: $(uv --version)"
  else
    echo -e "${YELLOW}!${NC} uv: not found (optional)"
  fi
  
  [ $errors -eq 0 ] && info "Self-check: PASSED" || warn "Self-check: $errors issue(s) found"
  return $errors
}

cmd_self_status() {
  echo "Scout Scanner Installer Status"
  echo "  Path: ${BASH_SOURCE[0]}"
  echo "  VAOS_ROOT: ${VAOS_ROOT:-not set}"
  echo "  python3: $(command -v python3 2>/dev/null || echo 'not found')"
  echo "  uv: $(command -v uv 2>/dev/null || echo 'not found')"
}

cmd_self_version() {
  echo "Scout Scanner Analyzer CLI Installer v1.1.0"
  echo "Entity: installer | Category: analysis | Runtime: uv (OPTIONAL)"
  echo "VAOS / TheAvaGroup"
}

case "${1:-help}" in
  check)           cmd_check ;;
  install)         cmd_install ;;
  execute)         cmd_execute "$@" ;;
  run)             cmd_run "$@" ;;
  runtime-check)   cmd_runtime_check ;;
  runtime-install) cmd_runtime_install ;;
  self-check)      cmd_self_check ;;
  self-status)     cmd_self_status ;;
  self-version)    cmd_self_version ;;
  --version|-v)    python3 --version ;;
  help|--help|-h)  usage ;;
  *) echo -e "${RED}Unknown command:${NC} $1"; usage; exit 1 ;;
esac