#!/usr/bin/env bash
# =============================================================================
# System HUD & Actions Helper for Hyprland Keybindings
# Handles system state toggles and sends clean Dunst notifications.
# =============================================================================

action="$1"
param="$2"

case "$action" in
    volume)
        if [ "$param" = "toggle" ]; then
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        else
            wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "$param"
        fi
        
        # Get status
        vol_info=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
        if echo "$vol_info" | grep -q "MUTED"; then
            dunstify -u normal -h string:x-dunst-stack-tag:volume -i audio-volume-muted "Volume" "Muted"
        else
            vol_val=$(echo "$vol_info" | awk '{print int($2 * 100)}')
            dunstify -u normal -h string:x-dunst-stack-tag:volume -h int:value:"$vol_val" -i audio-volume-high "Volume" "Volume: ${vol_val}%"
        fi
        ;;

    brightness)
        brightnessctl -e4 -n2 set "$param"
        bright_val=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
        dunstify -u normal -h string:x-dunst-stack-tag:brightness -h int:value:"$bright_val" -i display-brightness "Brightness" "Brightness: ${bright_val}%"
        ;;

    wifi)
        if [ "$(nmcli radio wifi)" = "enabled" ]; then
            nmcli radio wifi off
            dunstify -u normal -h string:x-dunst-stack-tag:wifi -i network-wireless-offline "WiFi" "WiFi Disabled"
        else
            nmcli radio wifi on
            dunstify -u normal -h string:x-dunst-stack-tag:wifi -i network-wireless-hotspot "WiFi" "WiFi Enabled"
        fi
        ;;

    bluetooth)
        if bluetoothctl show | grep -q "Powered: yes"; then
            bluetoothctl power off
            dunstify -u normal -h string:x-dunst-stack-tag:bluetooth -i bluetooth-disabled "Bluetooth" "Bluetooth Disabled"
        else
            bluetoothctl power on
            dunstify -u normal -h string:x-dunst-stack-tag:bluetooth -i bluetooth-active "Bluetooth" "Bluetooth Enabled"
        fi
        ;;

    mic)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q "MUTED"; then
            dunstify -u normal -h string:x-dunst-stack-tag:mic -i microphone-disabled "Microphone" "Muted"
        else
            dunstify -u normal -h string:x-dunst-stack-tag:mic -i microphone-sensitivity-high "Microphone" "Active"
        fi
        ;;

    monique)
        dunstify -u normal -h string:x-dunst-stack-tag:monique -i system-run "Monique" "Launching Monique..."
        monique >/dev/null 2>&1 & disown
        ;;

    control_center)
        dunstify -u normal -h string:x-dunst-stack-tag:control -i preferences-system "Control Center" "Opening Control Center..."
        ~/.config/rofi/control_center/control_center.sh >/dev/null 2>&1 & disown
        ;;

    power_profile)
        current=$(powerprofilesctl get 2>/dev/null)
        case "$current" in
            performance)
                powerprofilesctl set balanced
                dunstify -u normal -h string:x-dunst-stack-tag:power -i power-profile-balanced "Power Profile" "Balanced (Turbo OFF)"
                ;;
            balanced)
                powerprofilesctl set power-saver
                dunstify -u normal -h string:x-dunst-stack-tag:power -i power-profile-power-saver "Power Profile" "Power Saver (Turbo OFF)"
                ;;
            power-saver|*)
                powerprofilesctl set performance
                dunstify -u normal -h string:x-dunst-stack-tag:power -i power-profile-performance "Power Profile" "Performance (Turbo ON)"
                ;;
        esac
        ;;
esac

