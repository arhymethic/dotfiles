#!/usr/bin/env bash

# Reload Waybar
killall waybar 2>/dev/null
nohup waybar >/dev/null 2>&1 &

# Reload Hyprland config
hyprctl reload

# Ensure hyprpaper is running (without killing it if it's already active)
if ! pgrep -x "hyprpaper" > /dev/null; then
    nohup hyprpaper >/dev/null 2>&1 &
    sleep 0.5
fi

# Re-apply current wallpaper from cycle index
~/.config/hypr/scripts/cycle_hyprpaper.sh current

# Ensure hypridle is running
if ! pgrep -x "hypridle" > /dev/null; then
    nohup hypridle >/dev/null 2>&1 & disown
fi

# Start battery monitor (kill existing instance first)
pkill -f "battery_monitor.sh" 2>/dev/null
nohup ~/.config/hypr/scripts/battery_monitor.sh >/dev/null 2>&1 & disown

# Start clipboard history daemons
pkill -x wl-paste 2>/dev/null
nohup wl-paste --type text --watch cliphist store >/dev/null 2>&1 & disown
nohup wl-paste --type image --watch cliphist store >/dev/null 2>&1 & disown