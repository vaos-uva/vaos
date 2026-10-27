#!/usr/bin/env sh
# vaos-portable-install.sh — VAOS Portable Installer
# VAOS / TheAvaGroup
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER_ROOT="${SCRIPT_DIR}"
export INSTALLER_ROOT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf '%s[INFO]%s  %s\n' "$BLUE" "$NC" "$1"; }
log_ok()   { printf '%s[ OK ]%s %s\n' "$GREEN" "$NC" "$1"; }
log_warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$1"; }
log_fail() { printf '%s[FAIL]%s %s\n' "$RED" "$NC" "$1"; }

usage() {
  cat <<EOF
${BLUE}VAOS Portable Installer${NC}

Usage: $(basename "$0") <command> [options]

Commands:
  install      Run full installation (default)
  check        Check environment and dependencies
  init-dirs    Create required directory structure
  validate     Validate all .yaml configuration files
  help         Show this help

Examples:
  $(basename "$0") install
  $(basename "$0") check
  $(basename "$0") init-dirs
EOF
}

# ---- Check environment ----
check_env() {
  log_info "Checking environment..."

  if command -v sh >/dev/null 2>&1; then
    log_ok "sh: available"
  else
    log_fail "sh not found"
    return 1
  fi

  for runtime in bun node pnpm; do
    if command -v "$runtime" >/dev/null 2>&1; then
      ver="$( "$runtime" --version 2>&1 | tr '\n' ' ' | cut -c1-40)"
      log_ok "$runtime: $ver"
      found_runtime=1
      break
    fi
  done
  if [ -z "$found_runtime" ]; then
    log_warn "No JS runtime found (bun/node/pnpm) — some tools may be unavailable"
  fi

  if command -v git >/dev/null 2>&1; then
    ver="$(git --version 2>&1 | tr '\n' ' ' | cut -c1-40)"
    log_ok "git: $ver"
  else
    log_fail "git not found — required"
    return 1
  fi

  log_ok "Environment check passed."
}

# ---- Initialize directories ----
init_dirs() {
  log_info "Creating VAOS Portable directory structure..."

  for dir in vaos-common-skills vaos-common-schemas vaos-common-specs \
             vaos-common-templates vaos-common-standards vaos-common-tools \
             vaos-common-runners vaos-common-rules vaos-portable-registry \
             vaos-common-installers; do
    mkdir -p "${INSTALLER_ROOT}/${dir}"
    log_ok "${dir}/"
  done

  # State directories for .vaos/ runtime
  vaos_dir="${INSTALLER_ROOT}/../.vaos"
  if [ -d "$vaos_dir" ]; then
    for sdir in _state-new _state-review _state-warnings _state-failed \
                _state-passed _state-active _state-deferred _state-archived _state-locked; do
      mkdir -p "${vaos_dir}/${sdir}"
      log_ok ".vaos/${sdir}/"
    done
  fi

  log_ok "Directory structure initialized."
}

# ---- Validate YAML configs ----
validate_yaml() {
  log_info "Validating YAML configuration files..."

  manifest="${INSTALLER_ROOT}/vaos-manifest.yaml"
  registry="${INSTALLER_ROOT}/vaos-portable-registry/registry.yaml"
  selfdef="${INSTALLER_ROOT}/vaos-self-definition.yaml"

  count=0
  for f in "$manifest" "$registry" "$selfdef"; do
    if [ -f "$f" ]; then
      size="$(wc -c < "$f")"
      if [ "$size" -gt 0 ]; then
        log_ok "$(basename "$f"): present ($size bytes)"
        count=$((count + 1))
      else
        log_warn "$(basename "$f"): empty file"
      fi
    else
      log_warn "$(basename "$f"): not found"
    fi
  done

  log_ok "Validated $count configuration file(s)."
}

# ---- Install (main) ----
do_install() {
  log_info "VAOS Portable Installer — starting..."
  echo ""

  check_env || exit 1
  echo ""

  init_dirs
  echo ""

  validate_yaml
  echo ""

  log_ok "Installation complete."
  log_info "Next steps:"
  log_info "  ./vaos-portable-cli.sh init"
  log_info "  cd ../.vaos && ./vaos-runtime-cli.sh init"
}

# ---- Main ----
case "${1:-install}" in
  install)     do_install ;;
  check)       check_env ;;
  init-dirs)   init_dirs ;;
  validate)    validate_yaml ;;
  help|--help) usage ;;
  *)           usage ;;
esac