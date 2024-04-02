#! /usr/bin/env bash

# Discover connected displays
scaling_pref=$(cat /var/lib/gui-localization/screen-scaling 2>/dev/null || echo "default")
echo "Using scaling preference '$scaling_pref'"
connected_outputs=$(xrandr | grep ' connected' | awk '{ print $1 }')
echo "Connected outputs: $connected_outputs"
if [ -z "$connected_outputs" ]; then
echo "No connected outputs found. Trying to apply xrandr globally."
case "$scaling_pref" in
  "default" | "full-hd")
    xrandr --size 1920x1080;;
  "native")
    xrandr --auto;;
  *)
    echo "Unknown scaling preference '$scaling_pref'. Applying auto.";
    xrandr --auto;;
esac
else
for output in $connected_outputs; do
  echo "Enabling connected output $output"
  case "$scaling_pref" in
    "default" | "full-hd")
      xrandr --output $output --mode 1920x1080;;
    "native")
      xrandr --output $output --auto;;
    *)
      echo "Unknown scaling preference '$scaling_pref'. Applying auto.";
      xrandr --output $output --auto;;
  esac
done
fi
