#!/bin/sh
# @ patterns:
#   @ : pAT, META
#   !  :   instructs
#   $   vars
# ident: m2m-dev-root-cli
# category: tool
# purpose: development-cli-help
# role: standalone-shell-scaffold
# semantic: cli-scaffold
# universe: vaos
# vaos-id: VAOS.M2M.DevRoot.001
# brand: OZCO
# layer: TASK
# base-axis: Execution
# time-axis: RunTime
# purpose-axis: Knowlege
# generated-from: m2m-dev-root-cli-v1
CLI_TITLE='M2M-DEV-ROOT Development CLI'
set -eu
CYAN=
GREEN=
NC=
if [ -t 1 ] && [ "${NO_COLOR+x}" != x ]; then
    CYAN=$(printf '\033[36m')
    GREEN=$(printf '\033[32m')
    NC=$(printf '\033[0m')
fi

show_help() {
    printf '\n%s%s%s\n\n' "$CYAN" "$CLI_TITLE" "$NC"
    printf '%sCommands:%s\n' "$GREEN" "$NC"
    printf '\n  %sProject Operations (research02)%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    sync                 Sync projects: prj-artifact → STATE-PRJ/ds-projects
    build [project]      Build all DS projects (or just [project])
    projects             List all DS Engine projects

EOF_HELP
    printf '  %sTerra App (terra-trunk-one)%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    terra dev            Start Terra dev servers (Vite + NestJS concurrently)
    terra build          Build Terra (web + nest)
    terra test           Run Terra Jest tests
    terra playwright     Run Playwright E2E pipeline (full)
    terra playwright --skip-servers   Skip server start/stop
    terra playwright --lms-only       LMStudio review only
    terra health         Health check: web (5173) + API (3000)

EOF_HELP
    printf '  %sDS CLI (research01 cli.sh)%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    ds info              Show project info (via ds-cli)
    ds project list      List projects
    ds schema <cmd>      Schema operations (validate, generate, inspect)
    ds artifact <cmd>    Artifact operations (list, download, upload)

EOF_HELP
    printf '  %sRemote Operations%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    deploy <src> [dst]   SCP to remote /home/administrator/projects
                         Env: REMOTE_HOST, REMOTE_USER, SSH_KEY

EOF_HELP
    printf '  %sWorkspace%s\n' "$GREEN" "$NC"
    cat <<'EOF_HELP'
    status               Show status of all services and projects
    activity             Mark agent activity (suppress self-monitor)
    config               Show current project-config.yaml summary
    self-monitor         Run self-monitor health checks
    help                 Show this help
EOF_HELP
}

case ${1:-help} in
    help|-h|--help) show_help ;;
    *)
        printf '%s: this scaffold documents command groups; wire project-specific handlers before use: %s\n' "$CLI_TITLE" "$*" >&2
        exit 2
        ;;
esac
