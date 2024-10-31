set -euo pipefail

SCALING_PREF=$(cat /var/lib/gui-localization/screen-scaling 2>/dev/null || echo "default")
readonly SCALING_PREF

CONNECTED_OUTPUTS=$(xrandr | grep ' connected' | awk '{ print $1 }')
readonly CONNECTED_OUTPUTS

echo -e "Connected outputs:\n$CONNECTED_OUTPUTS\n"

scaling_pref_params=""

echo "Using scaling preference '$SCALING_PREF'"

case "$SCALING_PREF" in
    "default" | "full-hd")
        scaling_pref_params=(--mode 1920x1080)
        ;;
    "native")
        scaling_pref_params=(--auto)
        ;;
    *)
        scaling_pref_params=(--auto)
        ;;
esac

if [ -z "$CONNECTED_OUTPUTS" ]; then

    echo "No connected outputs found. Attempting to apply xrandr globally."
    xrandr "${scaling_pref_params[@]}"

else

    first_output=""
    for output in $CONNECTED_OUTPUTS; do
        if [ -z "$first_output" ]; then
            first_output=$output
            xrandr --output "$output" \
                --primary \
                "${scaling_pref_params[@]}"
        else
            xrandr --output "$output" \
                --same-as "$first_output" \
                "${scaling_pref_params[@]}"
        fi
    done

fi
