#!/usr/bin/env bash

# Current Theme (adjust to your powermenu directory and style)
dir="$HOME/.config/rofi"
theme='style-1'

# Options with icons
shutdown='  Shutdown'
reboot='  Reboot'
lock='󰌾  Lock'
suspend='󰒲  Suspend'
logout='󰍃  Logout'

# Build menu options
menu_options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

# Rofi CMD
chosen=$(echo -e "$menu_options" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Power" -lines 5)

[ -z "$chosen" ] && exit 0

# Actions based on choice
case ${chosen} in
    "$shutdown")
        systemctl poweroff
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$lock")
        hyprlock
        ;;
    "$suspend")
        systemctl suspend
        ;;
    "$logout")
        if [[ "$XDG_CURRENT_DESKTOP" == 'Hyprland' ]] || [[ "$DESKTOP_SESSION" == 'hyprland' ]]; then
            hyprctl dispatch exit
        elif [[ "$DESKTOP_SESSION" == 'i3' ]]; then
            i3-msg exit
        elif [[ "$DESKTOP_SESSION" == 'bspwm' ]]; then
            bspc quit
        else
            loginctl terminate-session self
        fi
        ;;
esac