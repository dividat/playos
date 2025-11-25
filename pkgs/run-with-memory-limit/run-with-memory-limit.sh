#!/usr/bin/env bash
set -euo pipefail

# default optional param values

scope_prefix="run"

usage() {
    cat <<EOF
Usage: $0 --scope-prefix [STR] --memory-pct <NUM> prog arg1 arg2 ...

Starts program in a cgroup (using a systemd transient scope) and sets MemoryHigh
to the specified <NUM>% of total system memory.

A unique scope name is generated as {scope-prefix}-{uuid}.
scope-prefix defaults to "${scope_prefix}".
EOF
}

while true; do
    case "${1:-}" in
        --memory-pct)
            memory_high_pct=${2}
            readonly memory_high_pct
            shift 2
        ;;
        --scope-prefix)
            scope_prefix=$2
            shift 2
        ;;
        (-h|--help)
            usage
            exit 0
        ;;
        *)
            break
        ;;
    esac
done

readonly scope_prefix

if [[ -z "${memory_high_pct:-}" ]] || [[ -z "$*" ]]; then
    usage
    exit 1
fi

system_memory_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
readonly system_memory_kb

if ! [[ $system_memory_kb -gt 0 ]]; then
    echo "Failed to read system memory, got: $system_memory_kb kB"
    exit 1
fi

memory_high_mb=$(( memory_high_pct * system_memory_kb / 1024 / 100))
readonly memory_high_mb

if ! [[ $memory_high_mb -gt 0 ]]; then
    echo "Computed MemoryHigh is 0 or invalid: $memory_high_mb M"
    exit 1
fi

printf "%s: MemoryHigh will be set to %d MB\n" "$0" "$memory_high_mb" >&2

scope_name="${scope_prefix}-$(uuidgen)"
readonly scope_name

# `systemd-run --scope` only waits for the main PID to exit before returning.
# This means subprocesses can linger for longer. To avoid leaving any orphans
# behind and to return only when the scope is fully destroyed, we brutally kill
# anything that the main PID failed to stop.
cleanup() {
    systemctl --user kill --kill-whom=all "${scope_name}.scope" > /dev/null 2>&1 || true
    sleep 0.2
    systemctl --user kill --signal=SIGKILL --kill-whom=all "${scope_name}.scope" > /dev/null 2>&1 || true
}

trap cleanup EXIT
systemd-run --user \
    --scope \
    --unit="${scope_name}" \
    --property="MemoryHigh=${memory_high_mb}M" \
    "$@"
