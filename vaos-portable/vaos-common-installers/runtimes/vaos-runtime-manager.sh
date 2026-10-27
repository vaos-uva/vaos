#!/usr/bin/env bash
# vaos-runtime-manager.sh - VAOS Runtime Manager
# VAOS / TheAvaGroup
# Manages BASE runtimes: bun, sh, pnpm, uv
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

usage() {
  cat <<EOF
${GREEN}VAOS Runtime Manager${NC}
VAOS / TheAvaGroup

Usage: $(basename "$0") <command> [runtime] [script] [--help]

Entity Scope: tool | Category: runtime-manager

Commands:
  check [runtime]            Check runtime availability
  install <runtime>          Install runtime
  list                       List all runtimes with status
  run <runtime> <script>    Execute script by runtime
  self-check                 Run self-diagnostic check
  self-status                Show component status
  self-version               Show component version
  version                    Show version

Runtimes:
  bun   (BASE) - JavaScript runtime
  sh    (BASE) - Shell interpreter
  pnpm  (BASE) - Package manager
  uv    (OPT)  - Python package manager

Options:
  --help, -h                 Show this help

Examples:
  $(basename "$0") list
  $(basename "$0") check bun
  $(basename "$0") install pnpm
  $(basename "$0") run bun script.js
  $(basename "$0") run sh script.sh
EOF
}

# Runtime definitions
declare -A RUNTIME_CMDS=(
  [bun]="bun --version"
  [sh]="sh --version 2>&1 || echo 'sh-available'"
  [pnpm]="pnpm --version"
  [uv]="uv --version"
)

declare -A RUNTIME_INSTALL=(
  [bun]="curl -fsSL https://bun.sh/install | bash"
  [sh]="echo 'System shell required'"
  [pnpm]="npm install -g pnpm"
  [uv]="curl -LsSf https://astral.sh/uv/install.sh | sh"
)

declare -A RUNTIME_EXEC=(
  [bun]="bun"
  [sh]="sh"
  [pnpm]="pnpm exec"
  [uv]="uv run"
)

declare -A RUNTIME_TYPE=(
  [bun]="BASE"
  [sh]="BASE"
  [pnpm]="BASE"
  [uv]="OPTIONAL"
)

cmd_check() {
  local runtime="${1:-}"
  
  if [ -n "$runtime" ]; then
    check_runtime "$runtime"
  else
    for r in bun sh pnpm uv; do
      check_runtime "$r"
    done
  fi
}

check_runtime() {
  local runtime="$1"
  local cmd="${RUNTIME_CMDS[$runtime]}"
  local rtype="${RUNTIME_TYPE[$runtime]}"
  
  if eval "$cmd" >/dev/null 2>&1; then
    local version=$(eval "$cmd" 2>/dev/null | head -1)
    echo -e "${GREEN}✓${NC} $runtime ($rtype): $version"
    return 0
  else
    echo -e "${RED}✗${NC} $runtime ($rtype): not found"
    return 1
  fi
}

cmd_install() {
  local runtime="${1:-}"
  
  if [ -z "$runtime" ]; then
    error "Runtime not specified. Usage: $(basename "$0") install <runtime>"
  fi
  
  if [ -z "${RUNTIME_INSTALL[$runtime]:-}" ]; then
    error "Unknown runtime: $runtime"
  fi
  
  info "Installing $runtime..."
  local install_cmd="${RUNTIME_INSTALL[$runtime]}"
  
  if [ "$install_cmd" = "echo 'System shell required'" ]; then
    warn "sh is a system runtime - use system package manager"
    return 1
  fi
  
  eval "$install_cmd"
  info "$runtime installation complete"
}

cmd_list() {
  info "VAOS Runtimes:"
  echo ""
  for runtime in bun sh pnpm uv; do
    check_runtime "$runtime"
  done
  echo ""
  echo "BASE runtimes: bun, sh, pnpm"
  echo "OPTIONAL runtimes: uv"
}

cmd_run() {
  local runtime="$1"
  shift
  local script="$1"
  shift
  local args="$@"
  
  if [ -z "$runtime" ] || [ -z "$script" ]; then
    error "Usage: $(basename "$0") run <runtime> <script> [args...]"
  fi
  
  local exec_cmd="${RUNTIME_EXEC[$runtime]}"
  
  if ! command -v "$runtime" >/dev/null 2>&1; then
    error "$runtime not found. Run '$(basename "$0") install $runtime' first"
  fi
  
  info "Executing: $runtime $script $args"
  $exec_cmd "$script" $args
}

cmd_version() {
  echo "VAOS Runtime Manager v1.1.0"
  echo "VAOS / TheAvaGroup"
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
  
  for r in bun sh pnpm uv; do
    if command -v $r >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC} $r: available"
    else
      echo -e "${YELLOW}!${NC} $r: not found"
    fi
  done
  
  [ $errors -eq 0 ] && info "Self-check: PASSED" || warn "Self-check: $errors issue(s) found"
  return $errors
}

cmd_self_status() {
  echo "VAOS Runtime Manager Status"
  echo "  Path: ${BASH_SOURCE[0]}"
  echo "  VAOS_ROOT: ${VAOS_ROOT:-not set}"
  for r in bun sh pnpm uv; do
    echo "  $r: $(command -v $r 2>/dev/null || echo 'not found')"
  done
}

cmd_self_version() {
  echo "VAOS Runtime Manager v1.1.0"
  echo "Entity: tool | Category: runtime-manager"
  echo "VAOS / TheAvaGroup"
}

case "${1:-help}" in
  check)    shift; cmd_check "$@" ;;
  install)  shift; cmd_install "$@" ;;
  list)     cmd_list ;;
  run)      shift; cmd_run "$@" ;;
  self-check)    cmd_self_check ;;
  self-status)   cmd_self_status ;;
  self-version)  cmd_self_version ;;
  version)  cmd_version ;;
  help|--help|-h) usage ;;
  *) usage ;;
esac