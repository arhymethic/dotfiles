#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Wallpapers"
CACHE_DIR="$HOME/.cache/hyprpaper_cycle"
mkdir -p "$CACHE_DIR"
LIST_FILE="$CACHE_DIR/list.txt"
INDEX_FILE="$CACHE_DIR/index.txt"

# 1. Generate the list of images
find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | sort > "$LIST_FILE"

TOTAL_WALLPAPERS=$(wc -l < "$LIST_FILE")
if [ "$TOTAL_WALLPAPERS" -eq 0 ]; then
    notify-send "Hyprpaper" "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# 2. Initialize or read index
if [ ! -f "$INDEX_FILE" ]; then
    currentIndex=0
else
    currentIndex=$(cat "$INDEX_FILE")
fi

# 3. Handle direction argument (next, prev, or current)
DIRECTION="${1:-current}"
if [ "$DIRECTION" == "next" ]; then
    currentIndex=$(( (currentIndex + 1) % TOTAL_WALLPAPERS ))
elif [ "$DIRECTION" == "prev" ]; then
    currentIndex=$(( (currentIndex - 1 + TOTAL_WALLPAPERS) % TOTAL_WALLPAPERS ))
fi
# Note: If DIRECTION is "current", currentIndex remains unchanged!

# Save the index
echo "$currentIndex" > "$INDEX_FILE"

# 4. Get target wallpaper path
WALLPAPER=$(sed -n "$((currentIndex + 1))p" "$LIST_FILE")

# 5. Apply via hyprpaper IPC
# Grab all connected monitors dynamically
MONITORS=$(hyprctl monitors -j | jq -r '.[].name')

hyprpaper_command() {
    hyprctl hyprpaper unload unused
    hyprctl hyprpaper preload "$WALLPAPER"
    for mon in $MONITORS; do
        hyprctl hyprpaper wallpaper "$mon,$WALLPAPER"
    done
}

hyprpaper_command