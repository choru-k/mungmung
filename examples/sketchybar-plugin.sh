#!/bin/bash
# MungMung Alerts Plugin for Sketchybar
# Reference implementation — copy to your dotfiles and customize.
#
# This plugin:
# 1. Subscribes to the `mung_alert_change` custom event
# 2. Reads alert state files from $MUNG_DIR/alerts/
# 3. Updates a sketchybar label showing alert count and icons
#
# Setup in your sketchybarrc:
# ─────────────────────────────────────────────────────────
#   # Register the custom event
#   sketchybar --add event mung_alert_change
#
#   # Add the mungmung alerts item
#   sketchybar --add item mung_alerts right \
#     --set mung_alerts \
#     icon="🔔" \
#     icon.padding_left=8 \
#     icon.padding_right=4 \
#     label="0" \
#     label.padding_right=8 \
#     background.drawing=on \
#     click_script="mung list" \
#     script="$PLUGIN_DIR/mung_alerts.sh" \
#     --subscribe mung_alerts mung_alert_change
# ─────────────────────────────────────────────────────────
#
# Clicking the item opens a terminal with `mung list`.
# You can change click_script to whatever suits your workflow.

# Colors (Catppuccin Macchiato — match your sketchybarrc)
TEXT_COLOR=0xffcdd6f4    # Text (active)
SUBTEXT_COLOR=0xff6c7086 # Subtext (inactive/zero)
ACCENT_COLOR=0xff89b4fa  # Blue (alerts present)

# State directory
MUNG_DIR="${MUNG_DIR:-$HOME/.local/share/mung}"
ALERTS_DIR="$MUNG_DIR/alerts"

# Count alert files
count=0
if [[ -d "$ALERTS_DIR" ]]; then
    for file in "$ALERTS_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        ((count++))
    done
fi

# Build label
if (( count == 0 )); then
    LABEL="0"
    LABEL_COLOR=$SUBTEXT_COLOR
    ICON_COLOR=$SUBTEXT_COLOR
else
    LABEL="$count"
    LABEL_COLOR=$TEXT_COLOR
    ICON_COLOR=$ACCENT_COLOR
fi

# Update sketchybar item
sketchybar --set "$NAME" \
    label="$LABEL" \
    label.color=$LABEL_COLOR \
    icon.color=$ICON_COLOR
