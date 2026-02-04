# Note: shebang header, shellopts and PATH is configured by nixpkgs' writeShellApplication

DEFAULT_LOG_FORMAT="short-iso"
DEFAULT_SINCE="2 weeks ago"
DEFAULT_CMD_TIMEOUT="5m"

declare -a DIAGNOSTIC_TYPES=(
    "HARDWARE"
    "LOGS"
    "NETWORK"
    "STATS"
    "SYSINFO"
)

readonly DEFAULT_LOG_FORMAT DEFAULT_SINCE DEFAULT_CMD_TIMEOUT DIAGNOSTIC_TYPES


usage() {
  cat <<EOF
Usage: $0 [--minimal] [--since SINCE] [--output FILE]

Run various diagnostic commands and collect the data into a gzip-compressed tar
archive.

The diagnostic commands are grouped by TYPE and output into separate folders.

In case any of the diagnostic commands fail with exit code N>0, the script will
exit with code 100+N. Exit codes <100 are bugs and/or unexpected errors in the
collection script.

The tool will save the commands used to collect the data, their stderr outputs
and their exit error codes into collection.log, which serves as an audit log.

The resulting archive will have the following structure:

    playos-diagnostics-<MACHINE_ID>-<DATE>/
    - collection.log  # date, params and logs of diagnostic tool invocations and
                      # error exit codes
    - data/
        - TYPE1/
            - cmd1.txt
            - cmd2.txt
            ...
        - TYPE2/
            - cmd1.txt
            - cmd2.txt
            ...

General params:

    -o, --output            Destination file, defaults to stdout

    --log-format FORMAT     Sets journalctl --output=FORMAT. Defaults to '${DEFAULT_LOG_FORMAT}'

Limits:

    --cmd-timeout SECONDS   Set a time limit for individual diagnostic commands. Defaults
                            to "${DEFAULT_CMD_TIMEOUT}". Can use s, m, h, d
                            suffixes for seconds, minutes, hours, days.

Filters:
    -m, --minimal           Produce a small archive. Alias for --exclude=LOGS

    -S, --since SINCE       How much historical data (e.g. logs) to collect.
                            Defaults to "${DEFAULT_SINCE}".
                            Can take an absolute value (e.g. --since=2025-01-01)
                            and a relative one (e.g. --since="12 days ago").

    -e, --exclude TYPE      Exclude a diagnostic type. Can be used multiple times.

Misc:
    --list-types            Prints a list of all diagnostic types and exits.

    -h, --help              Prints this help page.


Examples:
  $0 --output debug-info.tar.gz --minimal

  $0 --since "1 week ago" --exclude network
EOF
  exit 1
}

log() {
    echo "$1" >&2
}

# Globals set during arg parsing
OUTPUT="-"
LOG_FORMAT=$DEFAULT_LOG_FORMAT
SINCE=$DEFAULT_SINCE
CMD_TIMEOUT=$DEFAULT_CMD_TIMEOUT
declare -a EXCLUDES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -o|--output) OUTPUT="$2"; shift 2 ;;
        --log-format) LOG_FORMAT="$2"; shift 2 ;;
        -m|--minimal) EXCLUDES+=("LOGS"); shift ;;
        -S|--since) SINCE="$2"; shift 2 ;;
        --cmd-timeout) CMD_TIMEOUT="$2"; shift 2 ;;
        -e|--exclude) EXCLUDES+=("$2"); shift 2 ;;
        --list-types) printf '%s\n' "${DIAGNOSTIC_TYPES[@]}"; exit 0 ;;
        *) log "Unknown option: $1"; usage ;;
    esac
done

readonly OUTPUT LOG_FORMAT SINCE CMD_TIMEOUT EXCLUDES

# Globals modified during collection
LAST_COLLECTION_ERROR=0

is_excluded() {
    [[ " ${EXCLUDES[*]^^} " == *" ${1^^} "* ]]
}

# Helper function that:
# 1. Wraps the command in `timeout` with $CMD_TIMEOUT
# 2. Auto-generates an output filename from the cmd name if not specified
# 3. Redirects stdout to the output file
# 4. Saves the error exit code to LAST_COLLECTION_ERROR
#
# The executed command will be run with the output folder as the current working
# directory, so can use relative paths like ./foo to output
run_cmd() {
    local outfile
    if [[ "$1" == "-o" ]]; then
        outfile="$2"
        shift 2
    else
        local cmd; cmd="$*"
        outfile="${cmd// /_}.txt"
    fi

    log "Running: $* > $outfile ..."

    local exit_code; exit_code=0
    # Note: using `bash -c` to
    timeout -v --kill-after 10 "$CMD_TIMEOUT" bash -c "$*" > "$outfile" || exit_code=$?


    if [[ $exit_code -ne 0 ]]; then
        log ""
        log "... ERR command failed with exit code: ${exit_code}"
        LAST_COLLECTION_ERROR=$exit_code
    fi
}

copy_file() {
    run_cmd -o /dev/null "cp \"$1\" \"$2\""
}

collect_LOGS() {
    local since_args; since_args=""
    if [[ -n "$SINCE" ]]; then
        since_args="--since=\"$SINCE\""
    fi

    # Note: logs get compressed in-flight to reduce the amount of data stored in /tmp
    run_cmd -o journald.log.gz "journalctl --output=\"$LOG_FORMAT\" $since_args | gzip -c"
}

collect_NETWORK() {
    run_cmd ip addr show
    run_cmd ip link show
    run_cmd ip route show
    run_cmd -o ip_link_stats ip -s link show
    run_cmd connmanctl services
    run_cmd rfkill list
    run_cmd iw dev
    # redirectering stderr to stdout here, because these tools dump non-wireless
    # interfaces to stderr without an easy way to filter them
    run_cmd -o iwconfig.txt "iwconfig 2>&1"
    run_cmd -o iwlist_scanning.txt "iwlist scanning 2>&1"
}

collect_SYSINFO() {
    run_cmd date
    run_cmd -o uname.txt uname -a
    copy_file /etc/os-release .

    # excluding autosuspend_delay_ms since it seems to always produce I/O error
    run_cmd -o sys_class_dmi_id.txt grep -r . /sys/class/dmi/id/ --exclude="autosuspend_delay_ms"
}

collect_HARDWARE() {
    run_cmd -o "udevadm_net_devices.txt" "udevadm info /sys/class/net/*/device/"
    run_cmd lsmod
    run_cmd lscpu
}

collect_STATS() {
    run_cmd -o free.txt free -h
    run_cmd -o df.txt df -h
    run_cmd uptime
}

workdir=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$workdir'" EXIT
readonly workdir

machine_id="$(cat /etc/machine-id || echo "NO_MACHINE_ID")"
archive_name="playos-diagnostics-${machine_id}-$(date +%Y%m%d-%H%M%S)"
basedir="$workdir/$archive_name"
datadir="$basedir/data"
logfile="$basedir/collection.log"

readonly machine_id archive_name basedir datadir logfile

mkdir -p "$datadir"
touch "$logfile"

# Redirect stderr to both terminal and logfile to collect
# the output of self and run_cmd's
exec 3>&2
exec 2> >(tee -a "$logfile" >&3)

log "Starting PlayOS diagnostic data collection."
log ""
log "Collection date: $(date --rfc-3339=seconds)"
log "Machine id: ${machine_id}"
log ""
log "Parameters:"
log "  SINCE: ${SINCE:-<not set>}"
log "  LOG_FORMAT: $LOG_FORMAT"
log "  EXCLUDES: ${EXCLUDES[*]:-<none>}"
log ""

# Collect each type
for type in "${DIAGNOSTIC_TYPES[@]}"; do
    if ! is_excluded "$type"; then
        log "Collecting $type diagnostics..."
        mkdir -p "$datadir/${type,,}"
        pushd "$datadir/${type,,}" > /dev/null
            "collect_$type"
        popd > /dev/null
        log ""
    fi
done

log "Diagnostic collection completed."

if [[ $LAST_COLLECTION_ERROR -ne 0 ]]; then
    log "Warning: some diagnostic commands failed!"
fi

# Create archive
tar -czf "$OUTPUT" -C "$workdir" "$archive_name"

if [[ $LAST_COLLECTION_ERROR -ne 0 ]]; then
    exit $((100 + LAST_COLLECTION_ERROR))
fi
