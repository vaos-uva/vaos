#!/usr/bin/env bash
# playwright-cli.sh - Playwright Installer
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
${GREEN}Playwright CLI Installer${NC}
VAOS / TheAvaGroup

Usage: $(basename "$0") <command> [--help]

Entity Scope: installer | Category: testing | Runtime: bun

Commands:
  check           Check Playwright installation
  install         Install Playwright and browsers
  execute         Execute Playwright command
  run <script>    Run script with bun runtime
  runtime-check   Check runtime dependencies (bun, pnpm)
  runtime-install Install runtime dependencies
  self-check      Run self-diagnostic check
  self-status     Show component status
  self-version    Show component version

Options:
  --help, -h      Show this help
  --version, -v   Show version

Examples:
  $(basename "$0") check
  $(basename "$0") install
  $(basename "$0") run script.js
  $(basename "$0") runtime-check
EOF
}

cmd_check() {
  info "Checking Playwright..."
  if command -v npx >/dev/null 2>&1; then
    local version=$(npx playwright --version 2>/dev/null || echo "not-installed")
    echo -e "${GREEN}✓${NC} Playwright: $version"
    return 0
  else
    echo -e "${RED}✗${NC} Playwright: not installed"
    return 1
  fi
}

cmd_install() {
  info "Installing Playwright and browsers..."
  require npx
  npx playwright install --with-deps
  info "Installation complete"
}

cmd_execute() {
  shift
  info "Executing Playwright: $@"
  require npx
  npx playwright "$@"
}

cmd_runtime_check() {
  info "Checking runtime dependencies (BASE: bun, pnpm)..."
  local status=0
  
  if command -v bun >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} bun: $(bun --version)"
  else
    echo -e "${RED}✗${NC} bun: not found"
    status=1
  fi
  
  if command -v pnpm >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} pnpm: $(pnpm --version)"
  else
    echo -e "${RED}✗${NC} pnpm: not found"
    status=1
  fi
  
  return $status
}

cmd_runtime_install() {
  info "Installing runtime dependencies..."
  
  if ! command -v bun >/dev/null 2>&1; then
    info "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
  fi
  
  if ! command -v pnpm >/dev/null 2>&1; then
    info "Installing pnpm..."
    npm install -g pnpm
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
  
  if ! command -v bun >/dev/null 2>&1; then
    error "bun runtime not found. Run '$(basename "$0") runtime-install' first"
  fi
  
  info "Running $script with bun..."
  bun "$script" $args
}

cmd_self_version() {
  echo "Playwright CLI Installer v1.1.0"
  echo "Entity: installer | Category: testing | Runtime: bun"
  echo "VAOS / TheAvaGroup"
}

cmd_self_check() {
  info "Running self-diagnostic..."
  local errors=0
  
  # Check self existence
  local self_path="${BASH_SOURCE[0]}"
  if [ -f "$self_path" ] && [ -x "$self_path" ]; then
    echo -e "${GREEN}✓${NC} Self: executable"
  else
    echo -e "${RED}✗${NC} Self: not found or not executable"
    ((errors++))
  fi
  
  # Check VAOS_ROOT
  if [ -n "$VAOS_ROOT" ] && [ -d "$VAOS_ROOT" ]; then
    echo -e "${GREEN}✓${NC} VAOS_ROOT: $VAOS_ROOT"
  else
    echo -e "${YELLOW}!${NC} VAOS_ROOT: not set or invalid"
  fi
  
  # Check runtimes
  if command -v bun >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} bun: $(bun --version)"
  else
    echo -e "${RED}✗${NC} bun: not found"
    ((errors++))
  fi
  
  if command -v pnpm >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} pnpm: $(pnpm --version)"
  else
    echo -e "${YELLOW}!${NC} pnpm: not found"
  fi
  
  # Check npx
  if command -v npx >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} npx: available"
  else
    echo -e "${RED}✗${NC} npx: not found"
    ((errors++))
  fi
  
  if [ $errors -eq 0 ]; then
    info "Self-check: PASSED"
    return 0
  else
    warn "Self-check: $errors issue(s) found"
    return 1
  fi
}

cmd_self_status() {
  echo "Playwright Installer Status"
  echo "  Path: ${BASH_SOURCE[0]}"
  echo "  VAOS_ROOT: ${VAOS_ROOT:-not set}"
  echo "  bun: $(command -v bun 2>/dev/null || echo 'not found')"
  echo "  pnpm: $(command -v pnpm 2>/dev/null || echo 'not found')"
  echo "  npx: $(command -v npx 2>/dev/null || echo 'not found')"
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
  --version|-v)    npx playwright --version ;;
  help|--help|-h)  usage ;;
  *) echo -e "${RED}Unknown command:${NC} $1"; usage; exit 1 ;;
esac