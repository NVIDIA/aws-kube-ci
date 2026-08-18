#!/usr/bin/env bash
# Regression test for unset CONFIG_DIR in docker/crio install scripts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

run_prefix() {
    local script="$1"
    # Execute only up to (and including) the source of common.sh, then verify
    # common.sh was sourced by checking ARCH and OS are populated.  This avoids
    # running the apt/systemd commands that require root.
    local tmp
    tmp=$(mktemp -p config/ "test-config-dir.XXXXXX")
    awk '/source \$\{CONFIG_DIR\}\/common\.sh/{print; exit} {print}' "$script" > "$tmp"
    printf 'echo "OK: CONFIG_DIR=\\"%s\\" ARCH=%s OS=%s"\n' '$CONFIG_DIR' '$ARCH' '$OS' >> "$tmp"
    bash "$tmp"
    rm -f "$tmp"
}

echo "==> config/install_docker.sh"
run_prefix config/install_docker.sh

echo "==> config/install_crio.sh"
run_prefix config/install_crio.sh

echo "All CONFIG_DIR regression checks passed."
