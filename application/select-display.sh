set -euo pipefail

SCALING_PREF=$(cat /var/lib/gui-localization/screen-scaling 2>/dev/null || echo "default")
readonly SCALING_PREF
echo "Using scaling preference '$SCALING_PREF'"

CONNECTED_OUTPUTS=$(xrandr | grep ' connected' | awk '{ print $1 }')
readonly CONNECTED_OUTPUTS
echo -e "Connected outputs:\n$CONNECTED_OUTPUTS\n"

if [ -z "$CONNECTED_OUTPUTS" ]; then

  echo "No connected outputs found. Apply xrandr globally."
  xrandr --auto

else

  case "$SCALING_PREF" in
    "default" | "full-hd")
      for output in $CONNECTED_OUTPUTS; do
        echo "Applying full-hd to output '$output'"
        xrandr --auto --output "$output" --mode 1920x1080
      done
      ;;
    "native")
      echo "Native scaling preference. Applying auto."
      xrandr --auto
      ;;
    *)
      echo "Unknown scaling preference '$SCALING_PREF'. Applying auto."
      xrandr --auto
      ;;
  esac

fi
