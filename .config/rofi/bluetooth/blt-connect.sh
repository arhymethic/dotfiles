#!/usr/bin/env bash
#             __ _       _     _            _              _   _
#  _ __ ___  / _(_)     | |__ | |_   _  ___| |_ ___   ___ | |_| |__
# | '__/ _ \| |_| |_____| '_ \| | | | |/ _ \ __/ _ \ / _ \| __| '_ \
# | | | (_) |  _| |_____| |_) | | |_| |  __/ || (_) | (_) | |_| | | |
# |_|  \___/|_| |_|     |_.__/|_|\__,_|\___|\__\___/ \___/ \__|_| |_|
#
# Author: Nick Clyde (clydedroid)
#
# A script that generates a rofi menu that uses bluetoothctl to
# connect to bluetooth devices and display status info.

# Constants
divider="---------"
goback="Back"
dir="$HOME/.config/rofi"
theme='style-1'

# Checks if bluetooth controller is powered on
power_on() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        return 0
    else
        return 1
    fi
}

# Toggles power state
toggle_power() {
    if power_on; then
        bluetoothctl power off
        show_menu
    else
        rfkill unblock bluetooth 2>/dev/null
        sleep 0.5
        bluetoothctl power on
        show_menu
    fi
}

# Checks if controller is scanning for new devices
scan_on() {
    if bluetoothctl show | grep -q "Discovering: yes"; then
        echo "Scan: on"
        return 0
    else
        echo "Scan: off"
        return 1
    fi
}

# Helper functions for scan control
stop_scan() {
    pkill -f "sleep 3600" 2>/dev/null
    pkill -f "bluetoothctl.*scan on" 2>/dev/null
    bluetoothctl scan off >/dev/null 2>&1
}

start_scan() {
    stop_scan
    (echo "scan on"; sleep 3600) | bluetoothctl >/dev/null 2>&1 &
    sleep 0.5
}

# Toggles scanning state
toggle_scan() {
    if scan_on >/dev/null 2>&1; then
        stop_scan
        show_menu
    else
        start_scan
        show_menu
    fi
}

# Checks if controller is able to pair to devices
pairable_on() {
    if bluetoothctl show | grep -q "Pairable: yes"; then
        echo "Pairable: on"
        return 0
    else
        echo "Pairable: off"
        return 1
    fi
}

# Toggles pairable state
toggle_pairable() {
    if pairable_on; then
        bluetoothctl pairable off
        show_menu
    else
        bluetoothctl pairable on
        show_menu
    fi
}

# Checks if controller is discoverable by other devices
discoverable_on() {
    if bluetoothctl show | grep -q "Discoverable: yes"; then
        echo "Discoverable: on"
        return 0
    else
        echo "Discoverable: off"
        return 1
    fi
}

# Toggles discoverable state
toggle_discoverable() {
    if discoverable_on; then
        bluetoothctl discoverable off
        show_menu
    else
        bluetoothctl discoverable on
        show_menu
    fi
}

# Checks if a device is connected
device_connected() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Connected: yes"; then
        return 0
    else
        return 1
    fi
}

# Toggles device connection
toggle_connection() {
    if device_connected "$1"; then
        bluetoothctl disconnect "$1"
        device_menu "$device"
    else
        stop_scan
        bluetoothctl connect "$1"
        device_menu "$device"
    fi
}

# Checks if a device is paired
device_paired() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Paired: yes"; then
        echo "Paired: yes"
        return 0
    else
        echo "Paired: no"
        return 1
    fi
}

# Toggles device paired state
toggle_paired() {
    if device_paired "$1"; then
        bluetoothctl remove "$1"
        device_menu "$device"
    else
        bluetoothctl pair "$1"
        device_menu "$device"
    fi
}

# Removes / forgets a paired device
remove_device() {
    bluetoothctl remove "$1"
    show_menu
}

# Checks if a device is trusted
device_trusted() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Trusted: yes"; then
        echo "Trusted: yes"
        return 0
    else
        echo "Trusted: no"
        return 1
    fi
}

# Toggles device trust state
toggle_trust() {
    if device_trusted "$1"; then
        bluetoothctl untrust "$1"
        device_menu "$device"
    else
        bluetoothctl trust "$1"
        device_menu "$device"
    fi
}

# Fetches sorted list of devices (Connected/Most Recent at the top)
get_sorted_devices() {
    local connected_devs=""
    local other_devs=""

    while read -r line; do
        [ -z "$line" ] && continue
        mac=$(echo "$line" | cut -d ' ' -f 2)
        name=$(echo "$line" | cut -d ' ' -f 3-)

        if device_connected "$mac"; then
            connected_devs+="$name\n"
        else
            other_devs+="$name\n"
        fi
    done < <(bluetoothctl devices | grep Device)

    printf "%b%b" "$connected_devs" "$other_devs" | sed '/^$/d'
}

# Prints status string for status bars
print_status() {
    if power_on; then
        printf ''

        paired_devices_cmd="devices Paired"
        bt_ver=$(bluetoothctl version 2>/dev/null | cut -d ' ' -f 2)
        if command -v bc >/dev/null 2>&1 && [ -n "$bt_ver" ]; then
            if (( $(echo "$bt_ver < 5.65" | bc -l 2>/dev/null) )); then
                paired_devices_cmd="paired-devices"
            fi
        fi

        mapfile -t paired_devices < <(bluetoothctl $paired_devices_cmd | grep Device | cut -d ' ' -f 2)
        counter=0

        for device in "${paired_devices[@]}"; do
            if device_connected "$device"; then
                device_alias=$(bluetoothctl info "$device" | grep "Alias" | cut -d ' ' -f 2-)

                if [ $counter -gt 0 ]; then
                    printf ", %s" "$device_alias"
                else
                    printf " %s" "$device_alias"
                fi

                ((counter++))
            fi
        done
        printf "\n"
    else
        echo ""
    fi
}

# Helper functions for audio profiles (A2DP / HSP-HFP)
get_audio_profile() {
    local mac=$1
    local card_name="bluez_card.$(echo "$mac" | tr ':' '_')"
    local active
    active=$(pactl list cards 2>/dev/null | awk -v card="$card_name" '
        $0 ~ "Name: " card { in_card=1; next }
        in_card && /^Card/ { in_card=0 }
        in_card && /Active Profile:/ { print $3; exit }
    ')
    if [ -n "$active" ]; then
        if [[ "$active" == a2dp* ]]; then
            echo "Profile: A2DP (High Quality)"
        elif [[ "$active" == headset* || "$active" == hsp* || "$active" == hfp* ]]; then
            echo "Profile: HSP/HFP (Call Mode)"
        else
            echo "Profile: $active"
        fi
    fi
}

set_audio_profile() {
    local mac=$1
    local profile=$2
    local card_name="bluez_card.$(echo "$mac" | tr ':' '_')"
    pactl set-card-profile "$card_name" "$profile" 2>/dev/null
}

toggle_audio_profile() {
    local mac=$1
    local current
    current=$(get_audio_profile "$mac")

    local target_profile
    if [[ "$current" == *"A2DP"* ]]; then
        target_profile="headset-head-unit"
    else
        target_profile="a2dp-sink"
    fi

    set_audio_profile "$mac" "$target_profile"

    for i in {1..8}; do
        local check
        check=$(get_audio_profile "$mac")
        if [[ "$target_profile" == "headset-head-unit" && "$check" == *"HSP/HFP"* ]] || \
           [[ "$target_profile" == "a2dp-sink" && "$check" == *"A2DP"* ]]; then
            break
        fi
        sleep 0.05
    done
}

# Submenu for a specific device
device_menu() {
    device=$1

    device_name=$(echo "$device" | cut -d ' ' -f 3-)
    mac=$(echo "$device" | cut -d ' ' -f 2)

    profile_opt=""

    if device_connected "$mac"; then
        connected="Connected: yes"
        audio_prof=$(get_audio_profile "$mac")
        if [ -n "$audio_prof" ]; then
            profile_opt="$audio_prof"
        fi
    else
        connected="Connected: no"
    fi

    paired=$(device_paired "$mac")
    trusted=$(device_trusted "$mac")
    remove_opt="Remove / Unpair Device"

    options="$connected"
    if [ -n "$profile_opt" ]; then
        options+="\n$profile_opt"
    fi
    options+="\n$paired\n$trusted\n$remove_opt\n$divider\n$goback\nExit"

    chosen="$(echo -e "$options" | $rofi_command "$device_name")"

    case "$chosen" in
        "" | "$divider")
            echo "No option chosen."
            ;;
        "$connected")
            toggle_connection "$mac"
            ;;
        "Profile:"*)
            toggle_audio_profile "$mac"
            device_menu "$device"
            ;;
        "$paired")
            toggle_paired "$mac"
            ;;
        "$trusted")
            toggle_trust "$mac"
            ;;
        "$remove_opt")
            remove_device "$mac"
            ;;
        "$goback")
            show_menu
            ;;
    esac
}

# Main menu
show_menu() {
    if power_on; then
        power="Power: on"

        devices=$(get_sorted_devices)

        scan=$(scan_on)
        pairable=$(pairable_on)
        discoverable=$(discoverable_on)

        options="$devices\n$divider\n$power\n$scan\n$pairable\n$discoverable\nExit"
    else
        power="Power: off"
        options="$power\nExit"
    fi

    rofi_out=$(mktemp)
    refresh_flag=$(mktemp)
    rm -f "$refresh_flag" 2>/dev/null

    echo -e "$options" | $rofi_command "Bluetooth" > "$rofi_out" &
    rofi_pid=$!

    last_devices=$(bluetoothctl devices | sort)
    watcher_pid=""

    if power_on >/dev/null 2>&1 && bluetoothctl show | grep -q "Discovering: yes"; then
        (
            while power_on >/dev/null 2>&1 && bluetoothctl show | grep -q "Discovering: yes"; do
                sleep 1.5
                current_devices=$(bluetoothctl devices | sort)
                if [ "$current_devices" != "$last_devices" ]; then
                    touch "$refresh_flag"
                    kill $rofi_pid 2>/dev/null
                    break
                fi
            done
        ) &
        watcher_pid=$!
    fi

    wait $rofi_pid 2>/dev/null
    [ -n "$watcher_pid" ] && kill $watcher_pid 2>/dev/null && wait $watcher_pid 2>/dev/null

    chosen=$(cat "$rofi_out" 2>/dev/null)
    is_refresh=0
    if [ -f "$refresh_flag" ]; then
        is_refresh=1
    fi
    rm -f "$rofi_out" "$refresh_flag" 2>/dev/null

    if [ $is_refresh -eq 1 ]; then
        show_menu
        return
    fi

    case "$chosen" in
        "" | "$divider")
            echo "No option chosen."
            ;;
        "$power")
            toggle_power
            ;;
        "$scan")
            toggle_scan
            ;;
        "$discoverable")
            toggle_discoverable
            ;;
        "$pairable")
            toggle_pairable
            ;;
        "Exit")
            ;;
        *)
            device=$(bluetoothctl devices | grep "$chosen")
            if [[ $device ]]; then device_menu "$device"; fi
            ;;
    esac
}

# Rofi command base
rofi_command="rofi -dmenu $* -theme ${dir}/${theme}.rasi -p 󰂯 "

case "$1" in
    --status)
        print_status
        ;;
    *)
        trap 'stop_scan' EXIT INT TERM
        show_menu
        ;;
esac