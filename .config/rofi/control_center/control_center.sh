#!/usr/bin/env bash
# =============================================================================
# ANDROID-STYLE QUICK SETTINGS CONTROL CENTER (Rofi + Hyprland)
# =============================================================================
# This script provides a central, interactive Rofi control panel for your system.
# It queries system states (Wi-Fi, Bluetooth, Power Profiles, Brightness,
# Night Light via hyprsunset, Volume, Idle Guard, DND, Wallpaper, Power Menu)
# and displays them in a clean, perfectly aligned Rofi menu.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. PROCESS TOGGLE CHECK
# -----------------------------------------------------------------------------
# If Rofi is already running when the user triggers the shortcut key (e.g. Super+A),
# pkill closes Rofi immediately so the key acts as a true open/close toggle.
if pgrep -x rofi >/dev/null; then
    pkill -x rofi
    exit 0
fi

# -----------------------------------------------------------------------------
# 2. THEME AND PATH DEFINITIONS
# -----------------------------------------------------------------------------
dir="$HOME/.config/rofi"
theme="style-1"

# Tracks which row was previously selected so the cursor stays on the same
# setting after performing an action inside the loop.
SELECTED_ROW=0

# =============================================================================
# 3. SYSTEM STATE GETTER FUNCTIONS (Fast, Non-Blocking Queries)
# =============================================================================

# Queries active Wi-Fi connection via NetworkManager CLI (fast connection lookup)
get_wifi() {
    local wifi_name
    wifi_name=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep 802-11-wireless | head -n1 | cut -d: -f2)
    if [ -n "$wifi_name" ]; then
        echo "[ON] $wifi_name"
    else
        echo "[OFF] Disconnected"
    fi
}

# Checks Bluetooth power and connected device name via bluetoothctl
get_bt() {
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        local bt_dev
        bt_dev=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)
        if [ -n "$bt_dev" ]; then
            echo "[ON] $bt_dev"
        else
            echo "[ON] Enabled"
        fi
    else
        echo "[OFF] Disabled"
    fi
}

# Queries power-profiles-daemon for current CPU power profile
get_power_profile() {
    local prof
    prof=$(powerprofilesctl get 2>/dev/null)
    case "$prof" in
        performance) echo "[PERFORMANCE] Turbo ON" ;;
        balanced)    echo "[BALANCED] Turbo OFF" ;;
        power-saver) echo "[POWER-SAVER] Turbo OFF" ;;
        *)           echo "[$prof]" ;;
    esac
}

# Reads backlight percentage directly from Linux sysfs (/sys/class/backlight)
get_brightness() {
    local b_cur b_max b_perc
    if [ -d /sys/class/backlight ]; then
        b_cur=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1)
        b_max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1)
        if [ -n "$b_max" ] && [ "$b_max" -gt 0 ]; then
            b_perc=$(( b_cur * 100 / b_max ))
            echo "[$b_perc%]"
            return
        fi
    fi
    echo "[N/A]"
}

# Checks if hyprsunset (Hyprland's official night light filter) is running
get_nightlight() {
    if pidof hyprsunset &>/dev/null; then
        echo "[ON] Active"
    else
        echo "[OFF] Disabled (6000K)"
    fi
}

# Gets default audio output sink volume and mute status via WirePlumber (wpctl)
get_volume() {
    if command -v wpctl &>/dev/null; then
        local vol_raw vol_num
        vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        vol_num=$(echo "$vol_raw" | awk '{print int($2 * 100)}')
        if echo "$vol_raw" | grep -q "MUTED"; then
            echo "[MUTED] $vol_num%"
        else
            echo "[$vol_num%]"
        fi
    else
        echo "[N/A]"
    fi
}

# Checks if hypridle is running (active auto-sleep vs keep-awake mode)
get_idle() {
    if pidof hypridle &>/dev/null; then
        echo "[ACTIVE] Screen Auto-Sleep"
    else
        echo "[KEEP-AWAKE] Sleep Inhibited"
    fi
}

# Checks Dunst notification pause status
get_dnd() {
    if [ "$(dunstctl is-paused 2>/dev/null)" = "true" ]; then
        echo "[ON] Muted"
    else
        echo "[OFF] Normal"
    fi
}
# Helper to write values to USB sysfs attributes (handles direct write, passwordless sudo, and pkexec)
write_usb_sysfs() {
    local target_file="$1"
    local val="$2"
    if echo "$val" > "$target_file" 2>/dev/null; then
        return 0
    elif echo "$val" | sudo -n tee "$target_file" >/dev/null 2>&1; then
        return 0
    elif pkexec env DISPLAY="${DISPLAY:-:0}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}" sh -c "echo '$val' > '$target_file'" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

get_usb_profile_name() {
    local syspath="$1"
    local vid="$2"
    local cfg_num="$3"
    local cur_c="$4"

    if [ "$vid" = "05ac" ]; then
        case "$cfg_num" in
            1) echo "Camera & Photo Import (PTP)" ;;
            2) echo "iPod Digital Audio & Dock Controls" ;;
            3) echo "iOS Sync, Backup & Diagnostics (usbmuxd)" ;;
            4) echo "USB Personal Hotspot & Network Tethering" ;;
            *) echo "Apple Profile $cfg_num" ;;
        esac
        return
    fi

    local cfg_desc=$(cat "$syspath/configuration" 2>/dev/null | xargs)
    if [ -n "$cfg_desc" ] && [ "$cfg_num" -eq "${cur_c:-1}" ]; then
        echo "$cfg_desc"
        return
    fi

    echo "Configuration Profile $cfg_num"
}

# Queries all USB devices & power distribution summary from sysfs
get_usb() {
    local usb_count=0
    local total_ma=0
    for d in /sys/bus/usb/devices/[0-9]*-[0-9]*; do
        [ ! -f "$d/product" ] && continue
        local product=$(cat "$d/product" 2>/dev/null)
        echo "$product" | grep -qiE "^hub$|linux.*hub" && continue
        usb_count=$((usb_count + 1))
        local maxp=$(cat "$d/bMaxPower" 2>/dev/null | tr -d " ")
        local ma_val=$(echo "$maxp" | sed "s/mA//")
        if [ -n "$ma_val" ] && [ "$ma_val" -gt 0 ] 2>/dev/null; then
            total_ma=$((total_ma + ma_val))
        fi
    done
    if [ "$usb_count" -gt 0 ]; then
        local watts=$(awk "BEGIN {printf \"%.1f\", $total_ma * 5 / 1000}")
        echo "[$usb_count Devices] 󱐌 ~${watts}W (${total_ma}mA)"
    else
        echo "[NONE] No Devices"
    fi
}

# =============================================================================
# 4. ROW FORMATTING HELPER (Ensures 100% Monospace Column Alignment)
# =============================================================================
# Separates multi-byte UTF-8 Nerd Font icons from ASCII title strings during padding.
# `printf "%-18s"` pads pure ASCII titles to exactly 18 display characters so the
# vertical separator pipe (`│`) stays perfectly aligned across all rows.
format_row() {
    local icon="$1"
    local title="$2"
    local val="$3"
    local padded_title
    padded_title=$(printf "%-18s" "$title")
    echo "$icon  $padded_title │ $val"
}

# =============================================================================
# 5. MAIN INTERACTIVE CONTROL LOOP
# =============================================================================
while true; do
    # Fetch real-time system states
    WIFI_VAL=$(get_wifi)
    BT_VAL=$(get_bt)
    PROF_VAL=$(get_power_profile)
    BRIGHT_VAL=$(get_brightness)
    NL_VAL=$(get_nightlight)
    VOL_VAL=$(get_volume)
    IDLE_VAL=$(get_idle)
    DND_VAL=$(get_dnd)
    USB_VAL=$(get_usb)

    # Format menu items with fixed-width column alignment (Night Light directly under Brightness)
    OPT0=$(format_row "󰤨" "Wi-Fi" "$WIFI_VAL")
    OPT1=$(format_row "󰂯" "Bluetooth" "$BT_VAL")
    OPT2=$(format_row "󱐌" "Power Profile" "$PROF_VAL")
    OPT3=$(format_row "󰃟" "Brightness" "$BRIGHT_VAL")
    OPT4=$(format_row "󰌵" "Night Light" "$NL_VAL")
    OPT5=$(format_row "󰕾" "Audio & Volume" "$VOL_VAL")
    OPT6=$(format_row "󰈈" "Idle Auto-Lock" "$IDLE_VAL")
    OPT7=$(format_row "󰂛" "Do Not Disturb" "$DND_VAL")
    OPT8=$(format_row "󱊞" "USB Devices" "$USB_VAL")
    OPT9=$(format_row "󰸉" "Cycle Wallpaper" "Next Hyprpaper Wall")
    OPTA=$(format_row "󰤆" "Power & Session" "Lock / Reboot / Shutdown")

    # Combine all options separated by newlines
    options="${OPT0}\n${OPT1}\n${OPT2}\n${OPT3}\n${OPT4}\n${OPT5}\n${OPT6}\n${OPT7}\n${OPT8}\n${OPT9}\n${OPTA}"

    # Display Rofi dmenu using system style-1.rasi
    chosen=$(echo -e "$options" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Control Center" -selected-row "$SELECTED_ROW" -l 11)

    # Exit loop cleanly if user presses Esc or clicks outside
    [ -z "$chosen" ] && exit 0

    # -------------------------------------------------------------------------
    # 6. ACTION DISPATCHER
    # -------------------------------------------------------------------------
    case "$chosen" in
        *"Wi-Fi"*)
            SELECTED_ROW=0
            ~/.config/rofi/wifi/wifi.sh
            ;;
        *"Bluetooth"*)
            SELECTED_ROW=1
            ~/.config/rofi/bluetooth/blt-connect.sh
            ;;
        *"Power Profile"*)
            SELECTED_ROW=2
            p_chosen=$(echo -e "󱐌 Performance (Turbo ON)\n󰗑 Balanced (Turbo OFF)\n󰌪 Power Saver (Turbo OFF)" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Power Profile" -l 3)
            case "$p_chosen" in
                *"Performance"*) powerprofilesctl set performance ;;
                *"Balanced"*)    powerprofilesctl set balanced ;;
                *"Power Saver"*) powerprofilesctl set power-saver ;;
            esac
            ;;
        *"Brightness"*)
            SELECTED_ROW=3
            b_chosen=$(echo -e "󰃠 100%\n󰃟 75%\n󰃟 50%\n󰃞 25%\n󰃞 10%" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Brightness" -l 5)
            case "$b_chosen" in
                *"100%"*) brightnessctl set 100% ;;
                *"75%"*)  brightnessctl set 75% ;;
                *"50%"*)  brightnessctl set 50% ;;
                *"25%"*)  brightnessctl set 25% ;;
                *"10%"*)  brightnessctl set 10% ;;
            esac
            ;;
        *"Night Light"*)
            SELECTED_ROW=4
            nl_chosen=$(echo -e "󰌵 Soft Warm (5000K)\n󰌵 Medium Warm (4000K)\n󰌵 Deep Warm (3000K)\n󰌶 Disabled (6000K / Off)" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Night Light (hyprsunset)" -l 4)
            case "$nl_chosen" in
                *"5000K"*) pkill hyprsunset 2>/dev/null; hyprsunset -t 5000 & ;;
                *"4000K"*) pkill hyprsunset 2>/dev/null; hyprsunset -t 4000 & ;;
                *"3000K"*) pkill hyprsunset 2>/dev/null; hyprsunset -t 3000 & ;;
                *"Disabled"*) pkill hyprsunset 2>/dev/null ;;
            esac
            ;;
        *"Audio & Volume"*)
            SELECTED_ROW=5
            v_chosen=$(echo -e "󰝟 Toggle Mute\n󰕾 100%\n󰕾 75%\n󰕾 50%\n󰕾 25%\n󰓃 Audio Mixer (Pavucontrol)" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Volume Control" -l 6)
            case "$v_chosen" in
                *"Toggle Mute"*) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
                *"100%"*) wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 ;;
                *"75%"*)  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.75 ;;
                *"50%"*)  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.50 ;;
                *"25%"*)  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.25 ;;
                *"Audio Mixer"*) pavucontrol & ;;
            esac
            ;;
        *"Idle Auto-Lock"*)
            SELECTED_ROW=6
            if pidof hypridle &>/dev/null; then
                killall hypridle
                notify-send "Idle Guard" "Screen auto-sleep DISABLED (Keep-Awake ON)"
            else
                hypridle &
                notify-send "Idle Guard" "Screen auto-sleep ENABLED"
            fi
            ;;
        *"Do Not Disturb"*)
            SELECTED_ROW=7
            dunstctl set-paused toggle
            ;;
        *"USB Devices"*|*"Devices"*)
            SELECTED_ROW=8
            while true; do
                usb_storage_entries=""
                usb_periph_entries=""
                total_usb_ma=0
                active_usb_count=0

                # Helper to format USB entries with identical 100% monospaced column spacing
                format_usb_row() {
                    local icon="$1"
                    local title="$2"
                    local val="$3"
                    local padded_title
                    padded_title=$(printf "%-32s" "$title")
                    echo "$icon  $padded_title │ $val"
                }

                # --- 1. USB Storage Devices ---
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    dev_name=$(echo "$line" | awk '{print $1}')
                    dev_type=$(echo "$line" | awk '{print $4}')
                    dev_size=$(echo "$line" | awk '{print $5}')
                    dev_mount=$(echo "$line" | awk '{print $6}')

                    # Skip empty 0B drives
                    [ "$dev_size" = "0B" ] || [ "$dev_size" = "0" ] && continue

                    # Skip disk if it has partitions
                    if [ "$dev_type" = "disk" ]; then
                        pc=$(lsblk -o NAME,TYPE -nr /dev/"$dev_name" 2>/dev/null | grep -c "part")
                        [ "$pc" -gt 0 ] && continue
                    fi

                    dev_label=$(lsblk -o LABEL -nr /dev/"$dev_name" 2>/dev/null | head -1)
                    dev_model=$(lsblk -o MODEL -nr /dev/"$dev_name" 2>/dev/null | head -1 | xargs)
                    display="${dev_label:-${dev_model:-$dev_name}}"

                    if [ -n "$dev_mount" ]; then
                        usb_storage_entries+="$(format_usb_row "󰋊" "${display} [${dev_name}] (${dev_size})" "Mounted → ${dev_mount}")\n"
                    else
                        usb_storage_entries+="$(format_usb_row "󰋋" "${display} [${dev_name}] (${dev_size})" "Not Mounted")\n"
                    fi
                done < <(lsblk -o NAME,TRAN,RM,TYPE,SIZE,MOUNTPOINT -nr 2>/dev/null | awk '$2=="usb" && $3=="1" && ($4=="part" || $4=="disk")')

                # --- 2. USB Devices & Peripherals + Power Stats ---
                for sysdev in /sys/bus/usb/devices/[0-9]*-[0-9]*; do
                    [ ! -f "$sysdev/product" ] && continue
                    prod=$(cat "$sysdev/product" 2>/dev/null)
                    mfr=$(cat "$sysdev/manufacturer" 2>/dev/null)
                    echo "$prod" | grep -qiE "^hub$|linux.*hub" && continue
                    # Skip mass-storage (already in storage)
                    ls "$sysdev"/*/host* &>/dev/null && continue

                    # Power distribution queries
                    maxp=$(cat "$sysdev/bMaxPower" 2>/dev/null | tr -d " ")
                    ma_val=$(echo "$maxp" | sed "s/mA//")
                    pstat=$(cat "$sysdev/power/runtime_status" 2>/dev/null)

                    if [ -n "$ma_val" ] && [ "$ma_val" -gt 0 ] 2>/dev/null; then
                        total_usb_ma=$((total_usb_ma + ma_val))
                        w_calc=$(awk "BEGIN {printf \"%.1f\", $ma_val * 5 / 1000}")
                        power_str="${ma_val}mA (${w_calc}W)"
                    else
                        power_str="0mA"
                    fi

                    if [ "$pstat" = "active" ]; then
                        active_usb_count=$((active_usb_count + 1))
                        status_str="󱐌 Active"
                    else
                        status_str="󰤄 Suspended"
                    fi

                    auth=$(cat "$sysdev/authorized" 2>/dev/null)
                    if [ "$auth" = "1" ]; then
                        state_icon="󰄬"
                    else
                        state_icon="󰅖"
                        status_str="Disabled"
                    fi

                    bus_id=$(basename "$sysdev")
                    display="$prod"
                    [ -n "$mfr" ] && display="$prod ($mfr)"
                    usb_periph_entries+="$(format_usb_row "${state_icon}" "${display} [${bus_id}]" "${power_str} • ${status_str}")\n"
                done

                # Check if empty
                if [ -z "$usb_storage_entries" ] && [ -z "$usb_periph_entries" ]; then
                    notify-send "USB Devices" "No USB devices detected."
                    break
                fi

                # Power summary top row
                total_w=$(awk "BEGIN {printf \"%.2f\", $total_usb_ma * 5 / 1000}")
                OPT_PWR=$(format_usb_row "󱐌" "Total Power Allocated" "${total_usb_ma}mA (~${total_w}W @ 5V) • ${active_usb_count} Active")

                # Build menu without any dashed header lines
                final_menu="${OPT_PWR}\n${usb_storage_entries}${usb_periph_entries}"

                total_lines=$(echo -e "$final_menu" | wc -l)
                [ "$total_lines" -gt 15 ] && total_lines=15

                usb_chosen=$(echo -e "$final_menu" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "USB Devices" -l "$total_lines")
                [ -z "$usb_chosen" ] && break

                # --- 3. Handle Selected Item ---
                if echo "$usb_chosen" | grep -q "Total Power Allocated"; then
                    notify-send "USB Power Summary" "Total Power Allocated: ${total_usb_ma}mA (~${total_w}W @ 5V)\nActive Devices: ${active_usb_count}\nUSB Controller: Operational"
                elif echo "$usb_chosen" | grep -qE "│ Mounted|│ Not Mounted"; then
                    # STORAGE DEVICE
                    chosen_dev=$(echo "$usb_chosen" | sed -E 's/.*\[([^]]+)\].*/\1/')
                    dev_label=$(lsblk -o LABEL -nr /dev/"$chosen_dev" 2>/dev/null | head -1)
                    dev_model=$(lsblk -o MODEL -nr /dev/"$chosen_dev" 2>/dev/null | head -1 | xargs)
                    chosen_display="${dev_label:-${dev_model:-$chosen_dev}}"
                    dev_mount=$(lsblk -o MOUNTPOINT -nr /dev/"$chosen_dev" 2>/dev/null)

                    if [ -n "$dev_mount" ]; then
                        action_chosen=$(echo -e "󰅖  Unmount\n󰩈  Safely Eject (Unmount + Power Off)\n󰉋  Open in File Manager" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "$chosen_display" -l 3)
                        case "$action_chosen" in
                            *"Unmount"*)
                                if udisksctl unmount -b /dev/"$chosen_dev" 2>/dev/null; then
                                    notify-send "USB" "$chosen_display unmounted."
                                else
                                    notify-send -u critical "USB" "Failed to unmount $chosen_display."
                                fi ;;
                            *"Eject"*)
                                parent_disk=$(lsblk -ndo PKNAME /dev/"$chosen_dev" 2>/dev/null)
                                [ -z "$parent_disk" ] && parent_disk="$chosen_dev"
                                udisksctl unmount -b /dev/"$chosen_dev" 2>/dev/null
                                if udisksctl power-off -b /dev/"$parent_disk" 2>/dev/null; then
                                    notify-send "USB" "$chosen_display safely ejected."
                                else
                                    notify-send -u critical "USB" "Failed to eject $chosen_display."
                                fi ;;
                            *"File Manager"*)
                                nautilus "$dev_mount" &>/dev/null & disown
                                break ;;
                        esac
                    else
                        action_chosen=$(echo -e "󰄬  Mount\n󰩈  Safely Eject (Power Off)" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "$chosen_display" -l 2)
                        case "$action_chosen" in
                            *"Mount"*)
                                if udisksctl mount -b /dev/"$chosen_dev" 2>/dev/null; then
                                    new_mount=$(lsblk -o MOUNTPOINT -nr /dev/"$chosen_dev" 2>/dev/null)
                                    notify-send "USB" "$chosen_display mounted at $new_mount"
                                else
                                    notify-send -u critical "USB" "Failed to mount $chosen_display."
                                fi ;;
                            *"Eject"*)
                                parent_disk=$(lsblk -ndo PKNAME /dev/"$chosen_dev" 2>/dev/null)
                                [ -z "$parent_disk" ] && parent_disk="$chosen_dev"
                                if udisksctl power-off -b /dev/"$parent_disk" 2>/dev/null; then
                                    notify-send "USB" "$chosen_display safely ejected."
                                else
                                    notify-send -u critical "USB" "Failed to eject $chosen_display."
                                fi ;;
                        esac
                    fi

                else
                    # PERIPHERAL / INTERNAL DEVICE CONFIGURATION ENGINE
                    bus_id=$(echo "$usb_chosen" | sed -E 's/.*\[([^]]+)\].*/\1/')
                    syspath="/sys/bus/usb/devices/$bus_id"

                    if [ -d "$syspath" ]; then
                        prod=$(cat "$syspath/product" 2>/dev/null)
                        [ -z "$prod" ] && prod="$bus_id"
                        auth=$(cat "$syspath/authorized" 2>/dev/null)
                        pctrl=$(cat "$syspath/power/control" 2>/dev/null)
                        delay=$(cat "$syspath/power/autosuspend_delay_ms" 2>/dev/null)
                        wakeup=$(cat "$syspath/power/wakeup" 2>/dev/null)
                        num_cfg=$(cat "$syspath/bNumConfigurations" 2>/dev/null)
                        cur_cfg=$(cat "$syspath/bConfigurationValue" 2>/dev/null)

                        vid=$(cat "$syspath/idVendor" 2>/dev/null)

                        # Option labels
                        [ "$auth" = "1" ] && opt_auth="󰅖  Disable Device" || opt_auth="󰄬  Enable Device"
                        [ "$pctrl" = "auto" ] && opt_pctrl="󱐌  Autosuspend Mode: Auto (Power Saving ON)" || opt_pctrl="󰌪  Autosuspend Mode: Force ON (Always Powered)"
                        opt_delay="󱎫  Autosuspend Delay: ${delay:-2000}ms"
                        [ "$wakeup" = "enabled" ] && opt_wake="󰤄  Wake System from Sleep: Enabled" || opt_wake="󰤄  Wake System from Sleep: Disabled"
                        cur_pname=$(get_usb_profile_name "$syspath" "$vid" "${cur_cfg:-1}" "${cur_cfg:-1}")
                        opt_cfg="󰒓  USB Profile: ${cur_pname} [${cur_cfg:-1}/${num_cfg:-1}]"
                        opt_reset="󰑐  Reset USB Device Driver"
                        opt_info="󰋼  View Full Telemetry & Diagnostics"

                        # Build device config menu options
                        cfg_menu="${opt_auth}\n${opt_pctrl}\n${opt_delay}"
                        [ -n "$wakeup" ] && cfg_menu+="\n${opt_wake}"
                        [ -n "$num_cfg" ] && [ "$num_cfg" -gt 1 ] 2>/dev/null && cfg_menu+="\n${opt_cfg}"
                        cfg_menu+="\n${opt_reset}\n${opt_info}"

                        menu_count=$(echo -e "$cfg_menu" | wc -l)
                        action_chosen=$(echo -e "$cfg_menu" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "$prod" -l "$menu_count")
                        [ -z "$action_chosen" ] && continue

                        case "$action_chosen" in
                            *"Disable Device"*)
                                if write_usb_sysfs "$syspath/authorized" "0"; then
                                    notify-send "USB Device Config" "$prod disabled."
                                else
                                    notify-send -u critical "USB Device Config" "Failed to disable $prod."
                                fi ;;

                            *"Enable Device"*)
                                if write_usb_sysfs "$syspath/authorized" "1"; then
                                    notify-send "USB Device Config" "$prod enabled."
                                else
                                    notify-send -u critical "USB Device Config" "Failed to enable $prod."
                                fi ;;

                            *"Autosuspend Mode"*)
                                new_ctrl="auto"
                                [ "$pctrl" = "auto" ] && new_ctrl="on"
                                if write_usb_sysfs "$syspath/power/control" "$new_ctrl"; then
                                    notify-send "USB Power Config" "$prod power mode set to: $new_ctrl"
                                else
                                    notify-send -u critical "USB Power Config" "Failed to change power mode for $prod."
                                fi ;;

                            *"Autosuspend Delay"*)
                                d_chosen=$(echo -e "󱎫 0 ms (Immediate Autosuspend)\n󱎫 1000 ms (1 second)\n󱎫 2000 ms (2 seconds - Default)\n󱎫 5000 ms (5 seconds)\n󱎫 10000 ms (10 seconds)\n󱎫 -1 (Disable Autosuspend)" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Autosuspend Timeout" -l 6)
                                case "$d_chosen" in
                                    *"0 ms"*)     new_delay=0 ;;
                                    *"1000 ms"*)  new_delay=1000 ;;
                                    *"2000 ms"*)  new_delay=2000 ;;
                                    *"5000 ms"*)  new_delay=5000 ;;
                                    *"10000 ms"*) new_delay=10000 ;;
                                    *"-1"*)       new_delay=-1 ;;
                                    *) new_delay="" ;;
                                esac
                                if [ -n "$new_delay" ]; then
                                    if write_usb_sysfs "$syspath/power/autosuspend_delay_ms" "$new_delay"; then
                                        notify-send "USB Power Config" "$prod autosuspend delay set to: ${new_delay}ms"
                                    else
                                        notify-send -u critical "USB Power Config" "Failed to update autosuspend delay."
                                    fi
                                fi ;;

                            *"Wake System"*)
                                new_wake="enabled"
                                [ "$wakeup" = "enabled" ] && new_wake="disabled"
                                if write_usb_sysfs "$syspath/power/wakeup" "$new_wake"; then
                                    notify-send "USB Wakeup Config" "$prod sleep wakeup set to: $new_wake"
                                else
                                    notify-send -u critical "USB Wakeup Config" "Hardware does not support wakeup configuration."
                                fi ;;

                            *"USB Profile"*)
                                cfg_options=""
                                for ((i=1; i<=num_cfg; i++)); do
                                    p_name=$(get_usb_profile_name "$syspath" "$vid" "$i" "${cur_cfg:-1}")
                                    if [ "$i" -eq "${cur_cfg:-1}" ]; then
                                        cfg_options+="󰄬 Active: Profile $i — $p_name\n"
                                    else
                                        cfg_options+="󰒓 Profile $i — $p_name\n"
                                    fi
                                done
                                c_chosen=$(echo -e "$cfg_options" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Select Profile" -l "$num_cfg")
                                new_cfg=$(echo "$c_chosen" | grep -o "Profile [0-9]\+" | grep -o "[0-9]\+")
                                if [ -n "$new_cfg" ]; then
                                    new_pname=$(get_usb_profile_name "$syspath" "$vid" "$new_cfg" "${cur_cfg:-1}")
                                    if write_usb_sysfs "$syspath/bConfigurationValue" "$new_cfg"; then
                                        notify-send "USB Profile Config" "$prod switched to Profile $new_cfg ($new_pname)."
                                    else
                                        notify-send -u critical "USB Profile Config" "Failed to switch configuration profile."
                                    fi
                                fi ;;

                            *"Reset USB Device Driver"*)
                                drv_path=$(readlink -f "$syspath/driver" 2>/dev/null)
                                if [ -n "$drv_path" ]; then
                                    write_usb_sysfs "$drv_path/unbind" "$bus_id"
                                    sleep 0.2
                                    write_usb_sysfs "$drv_path/bind" "$bus_id"
                                    notify-send "USB Driver" "$prod driver reset successfully."
                                else
                                    notify-send -u critical "USB Driver" "No active driver found for $prod."
                                fi ;;

                            *"Telemetry"*)
                                mfr=$(cat "$syspath/manufacturer" 2>/dev/null)
                                serial=$(cat "$syspath/serial" 2>/dev/null)
                                vid=$(cat "$syspath/idVendor" 2>/dev/null)
                                pid=$(cat "$syspath/idProduct" 2>/dev/null)
                                speed=$(cat "$syspath/speed" 2>/dev/null)
                                ver=$(cat "$syspath/version" 2>/dev/null | xargs)
                                maxp=$(cat "$syspath/bMaxPower" 2>/dev/null | tr -d " ")
                                pstat=$(cat "$syspath/power/runtime_status" 2>/dev/null)
                                act_time=$(cat "$syspath/power/runtime_active_time" 2>/dev/null)
                                susp_time=$(cat "$syspath/power/runtime_suspended_time" 2>/dev/null)
                                rem=$(cat "$syspath/removable" 2>/dev/null)
                                ma_val=$(echo "$maxp" | sed "s/mA//")
                                w_str="0W"
                                [ -n "$ma_val" ] && [ "$ma_val" -gt 0 ] 2>/dev/null && w_str="$(awk "BEGIN {printf \"%.2f\", $ma_val * 5 / 1000}")W"
                                act_sec=$(( ${act_time:-0} / 1000 ))
                                susp_sec=$(( ${susp_time:-0} / 1000 ))
                                notify-send "USB Technical Telemetry" "${prod} (${mfr:-N/A})\nSerial: ${serial:-N/A}\nUSB ID: ${vid}:${pid} │ Bus: ${bus_id}\nSpeed: ${speed:-?} Mbps │ USB Ver: ${ver:-N/A}\nRemovable: ${rem:-unknown}\n\n󱐌 Max Power: ${maxp:-0mA} (~${w_str} @ 5V)\n󰌪 Power Status: ${pstat:-unknown} (Control: ${pctrl:-on})\n󱎫 Autosuspend Delay: ${delay:-0}ms\n󰤄 Wake System: ${wakeup:-N/A}\n󰒓 Config Profile: ${cur_cfg:-1}/${num_cfg:-1}\n⏱ Active: ${act_sec}s │ Suspended: ${susp_sec}s" ;;
                        esac
                    fi
                fi
            done
            ;;
        *"Cycle Wallpaper"*)
            SELECTED_ROW=9
            ~/.config/hypr/scripts/cycle_hyprpaper.sh next
            ;;
        *"Power & Session"*)
            SELECTED_ROW=10
            ~/.config/rofi/powermenu/type-2/powermenu.sh
            ;;
    esac
done
