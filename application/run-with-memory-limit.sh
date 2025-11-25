set -euo pipefail

usage() {
    echo "Usage: $0 --memory-pct <NUM> prog arg1 arg2 ... "
    echo ""
    echo "Starts program in a cgroup (using a systemd transient scope) and sets MemoryHigh"
    echo "to the specified <NUM>% of total system memory."
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

memory_high_pct=

while true; do
    case "$1" in
        --memory-pct)
            memory_high_pct=${2}
            shift 2
        ;;
        (-h|--help)
            usage
            exit 0
        ;;
        *)
            if [[ -z $memory_high_pct ]]; then
                usage
                exit 1
            else
                break
            fi
        ;;
    esac
done

if [[ -z "$memory_high_pct" ]] || [[ -z "$*" ]]; then
    usage
    exit 1
fi


system_memory_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"

if ! [[ $system_memory_kb -gt 0 ]]; then
    echo "Failed to read system memory, got: $system_memory_kb kB"
    exit 1
fi

memory_high_mb=$(( memory_high_pct * system_memory_kb / 1024 / 100))

if ! [[ $memory_high_mb -gt 0 ]]; then
    echo "Computed MemoryHigh is 0 or invalid: $memory_high_mb M"
    exit 1
fi

printf "%s: MemoryHigh will be set to %d MB\n" "$0" "$memory_high_mb" >&2

scope_name="run-$(uuidgen)"

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
