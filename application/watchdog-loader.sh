set -euo pipefail

# Loads the watchdog driver for known-good vendor models.

# List of PCI Subsystem IDs (lowercase hex) with known support for a
# useful watchdog:
#
# - Supported by it87_wdt driver
# - Triggers system reset irrespective of BIOS settings
#
# Subsystem IDs are the criterion also used by Shuttle's proprietary
# drivers to determine whether a board is compatible.
SUPPORTED_BOARD_IDS=(
    "4078" # DH310S
)


# Get the Subsystem ID from the Host Bridge (00:00.0)
# 46 decimal is the PCI Subsystem ID offset
BOARD_ID=$(hexdump -s 46 -n 2 -e '"%04x\n"' /proc/bus/pci/00/00.0)

if [ -z "$BOARD_ID" ]; then
    echo "Failed to read PCI ID. Aborting."
    exit 1
fi
echo "Detected Board Subsystem ID: $BOARD_ID"

MATCH=0
for ID in "${SUPPORTED_BOARD_IDS[@]}"; do
    if [ "$BOARD_ID" == "$ID" ]; then
        MATCH=1
        break
    fi
done


if [ $MATCH -eq 1 ]; then
    echo "PCI ID $BOARD_ID is in it87_wdt whitelist, loading it87_wdt..."
    modprobe it87_wdt
else
    echo "PCI ID $BOARD_ID is not in it87_wdt whitelist. Module skipped."
fi
