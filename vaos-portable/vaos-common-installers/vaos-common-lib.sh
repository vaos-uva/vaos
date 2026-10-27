#!/usr/bin/env bash
# vaos-common-lib.sh - VAOS Common Library
# VAOS / TheAvaGroup
# Shared functions for all VAOS CLI tools
# Version: 1.1.0

# Color codes
export VAOS_RED='\033[0;31m'
export VAOS_GREEN='\033[0;32m'
export VAOS_YELLOW='\033[1;33m'
export VAOS_BLUE='\033[0;34m'
export VAOS_NC='\033[0m'

# Error handler
vaos_error() { 
    echo -e "${VAOS_RED}[ERROR]${VAOS_NC} $1" >&2; 
    exit 1
}

# Warning handler  
vaos_warn() { 
    echo -e "${VAOS_YELLOW}[WARN]${VAOS_NC} $1"
}

# Info handler
vaos_info() { 
    echo -e "${VAOS_BLUE}[INFO]${VAOS_NC} $1"
}

# Success handler
vaos_ok() {
    echo -e "${VAOS_GREEN}[OK]${VAOS_NC} $1"
}

# Require command
vaos_require() { 
    command -v "$1" >/dev/null 2>&1 || vaos_error "Required: $1"
}

# Check if command exists
vaos_has() {
    command -v "$1" >/dev/null 2>&1
}

# Get VAOS_ROOT
vaos_get_root() {
    local script_path="${BASH_SOURCE[0]}"
    # Navigate from installers/<name>/ or runtimes/ to vaos-portable root
    echo "$(cd "$(dirname "$script_path")/.." && pwd)"
}

# Self check common
vaos_self_check() {
    local self_path="${BASH_SOURCE[0]}"
    local errors=0
    
    vaos_info "Running self-diagnostic..."
    
    if [ -f "$self_path" ] && [ -x "$self_path" ]; then
        echo -e "${VAOS_GREEN}✓${VAOS_NC} Self: executable"
    else
        echo -e "${VAOS_RED}✗${VAOS_NC} Self: not found or not executable"
        ((errors++))
    fi
    
    if [ -n "$VAOS_ROOT" ] && [ -d "$VAOS_ROOT" ]; then
        echo -e "${VAOS_GREEN}✓${VAOS_NC} VAOS_ROOT: $VAOS_ROOT"
    else
        echo -e "${VAOS_YELLOW}!${VAOS_NC} VAOS_ROOT: not set or invalid"
    fi
    
    return $errors
}

# Print usage header
vaos_usage_header() {
    local name="$1"
    local entity="${2:-installer}"
    local category="$3"
    local runtime="$4"
    
    cat <<EOF
${VAOS_GREEN}${name}${VAOS_NC}
VAOS / TheAvaGroup

Usage: $(basename "$0") <command> [--help]

Entity Scope: ${entity} | Category: ${category} | Runtime: ${runtime}

Commands:
EOF
}

# Print usage footer with examples
vaos_usage_footer() {
    local name="$(basename "$0")"
    cat <<EOF

Options:
  --help, -h      Show this help
  --version, -v   Show version

Examples:
  $name check
  $name self-check
  $name self-status
EOF
}

# Default self-check if not overridden
vaos_cmd_self_check_default() {
    vaos_self_check
    
    local errors=$?
    local extra_checks="${1:-}"
    
    if [ -n "$extra_checks" ]; then
        eval "$extra_checks"
    fi
    
    if [ $errors -eq 0 ]; then
        vaos_info "Self-check: PASSED"
    else
        vaos_warn "Self-check: $errors issue(s) found"
    fi
    return $errors
}

# Default self-status if not overridden  
vaos_cmd_self_status_default() {
    echo "$(basename "$0") Status"
    echo "  Path: ${BASH_SOURCE[0]}"
    echo "  VAOS_ROOT: ${VAOS_ROOT:-not set}"
}

# Default self-version
vaos_cmd_self_version_default() {
    echo "$(basename "$0") v1.1.0"
    echo "VAOS / TheAvaGroup"
}