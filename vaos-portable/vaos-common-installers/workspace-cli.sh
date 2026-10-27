#!/usr/bin/env bash
# workspace-cli.sh - Workspace Manager Installer
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
${GREEN}Workspace Manager CLI Installer${NC}
VAOS / TheAvaGroup

Usage: $(basename "$0") <command> [--help]

Entity Scope: installer | Category: workspace | Runtime: sh

Commands:
  check           Check workspace tools
  install         Install workspace structure
  execute <cmd>   Execute workspace command (list|status|current)
  run <script>    Run script with sh runtime
  runtime-check   Check runtime dependencies (sh, rsync, git)
  runtime-install Install runtime dependencies
  self-check      Run self-diagnostic check
  self-status     Show component status
  self-version    Show component version

Options:
  --help, -h      Show this help

Examples:
  $(basename "$0") check
  $(basename "$0") install
  $(basename "$0") execute list
  $(basename "$0") run script.sh
EOF
}

cmd_check() {
  info "Checking workspace tools..."
  local status=0
  
  if command -v rsync >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} rsync: $(rsync --version 2>&1 | head -1)"
  else
    echo -e "${RED}✗${NC} rsync: not found"
    status=1
  fi
  
  if command -v git >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} git: $(git --version)"
  else
    echo -e "${RED}✗${NC} git: not found"
    status=1
  fi
  
  return $status
}

cmd_install() {
  info "Installing workspace structure..."
  mkdir -p "$VAOS_ROOT/workspaces"
  mkdir -p "$VAOS_ROOT/config"
  mkdir -p "$VAOS_ROOT/logs"
  info "Workspace structure created at: $VAOS_ROOT"
}

cmd_execute() {
  shift
  local cmd="${1:-list}"
  info "Executing workspace: $cmd"
  
  case "$cmd" in
    list)
      find "$VAOS_ROOT/workspaces" -maxdepth 3 -type d 2>/dev/null | sed "s|$VAOS_ROOT/workspaces/||" | grep -v "^$" | sort || echo "No workspaces"
      ;;
    current)
      echo "Current workspace: ${WORKSPACE_ROOT:-not set}"
      ;;
    status)
      echo "Workspace root: $VAOS_ROOT"
      echo "Workspaces: $(find "$VAOS_ROOT/workspaces" -maxdepth 1 -type d 2>/dev/null | wc -l)"
      ;;
    *)
      error "Unknown workspace command: $cmd"
      ;;
  esac
}

cmd_runtime_check() {
  info "Checking runtime dependencies (BASE: sh)..."
  
  if command -v sh >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} sh: available"
  else
    echo -e "${RED}✗${NC} sh: not found"
    return 1
  fi
  
  if command -v rsync >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} rsync: $(rsync --version 2>&1 | head -1)"
  else
    echo -e "${RED}✗${NC} rsync: not found"
  fi
  
  if command -v git >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} git: $(git --version)"
  else
    echo -e "${RED}✗${NC} git: not found"
  fi
}

cmd_runtime_install() {
  info "Installing runtime dependencies..."
  
  if ! command -v rsync >/dev/null 2>&1; then
    warn "rsync not found - install via system package manager"
    echo "  Debian/Ubuntu: apt-get install rsync"
    echo "  macOS: brew install rsync"
  fi
  
  if ! command -v git >/dev/null 2>&1; then
    warn "git not found - install via system package manager"
    echo "  Debian/Ubuntu: apt-get install git"
    echo "  macOS: brew install git"
  fi
  
  info "Runtime dependencies check complete"
}

cmd_run() {
  shift
  local script="$1"
  shift
  local args="$@"
  
  if [ -z "$script" ]; then
    error "Usage: $(basename "$0") run <script> [args...]"
  fi
  
  if ! command -v sh >/dev/null 2>&1; then
    error "sh runtime not found"
  fi
  
  info "Running $script with sh..."
  sh "$script" $args
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
  
  if command -v sh >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} sh: available"
  else
    echo -e "${RED}✗${NC} sh: not found"
    ((errors++))
  fi
  
  if command -v rsync >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} rsync: available"
  else
    echo -e "${YELLOW}!${NC} rsync: not found"
  fi
  
  if command -v git >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} git: available"
  else
    echo -e "${YELLOW}!${NC} git: not found"
  fi
  
  [ $errors -eq 0 ] && info "Self-check: PASSED" || warn "Self-check: $errors issue(s) found"
  return $errors
}

cmd_self_status() {
  echo "Workspace Installer Status"
  echo "  Path: ${BASH_SOURCE[0]}"
  echo "  VAOS_ROOT: ${VAOS_ROOT:-not set}"
  echo "  sh: $(command -v sh 2>/dev/null || echo 'not found')"
  echo "  rsync: $(command -v rsync 2>/dev/null || echo 'not found')"
  echo "  git: $(command -v git 2>/dev/null || echo 'not found')"
}

cmd_self_version() {
  echo "Workspace CLI Installer v1.1.0"
  echo "Entity: installer | Category: workspace | Runtime: sh"
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
  help|--help|-h)  usage ;;
  *) usage ;;
esac