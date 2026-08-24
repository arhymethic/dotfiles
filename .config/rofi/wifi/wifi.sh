#!/bin/bash
# =============================================================================
# ROFI WI-FI NETWORK MANAGER & CONFIGURATOR
# =============================================================================

dir="$HOME/.config/rofi"
theme='style-1'

# Helper function to send notifications cleanly
notify() {
    local title="$1"
    local msg="$2"
    if command -v dunstify &>/dev/null; then
        dunstify -u normal -h string:x-dunst-stack-tag:wifi -i network-wireless "$title" "$msg"
    else
        notify-send "$title" "$msg"
    fi
}

# Get current Wi-Fi status for dynamic toggle text
wifi_status=$(nmcli radio wifi)
if [ "$wifi_status" = "enabled" ]; then
    toggle_text="󰖩  Disable Wi-Fi"
else
    toggle_text="󰖩  Enable Wi-Fi"
fi

# Get current active Wi-Fi connection
active_info=$(nmcli -t -f TYPE,NAME,DEVICE connection show --active 2>/dev/null | grep 802-11-wireless | head -n1)
active_ssid=$(echo "$active_info" | cut -d: -f2)
active_dev=$(echo "$active_info" | cut -d: -f3)

# Get list of saved connection profiles
known_connections=$(nmcli -t -f NAME connection show 2>/dev/null)

# Sub-menu function to configure or manage a specific network profile (Connected or Saved)
manage_network() {
    local ssid="$1"
    [ -z "$ssid" ] && return

    while true; do
        local is_active=false
        [ "$ssid" = "$active_ssid" ] && is_active=true

        # Get current auto-connect setting
        local autoconnect
        autoconnect=$(nmcli -g connection.autoconnect connection show id "$ssid" 2>/dev/null)
        [ -z "$autoconnect" ] && autoconnect="yes"

        local opts=""
        if [ "$is_active" = true ]; then
            opts="󰅖  Disconnect Network\n"
        else
            opts="󰤨  Connect to Network\n"
        fi

        opts="${opts}ℹ  View Connection Details\n"
        opts="${opts}⚙  Configure IPv4 (DHCP / Static IP)\n"
        opts="${opts}🌐  Configure DNS Servers\n"
        opts="${opts}🔄  Toggle Auto-Connect (Current: ${autoconnect})\n"
        opts="${opts}🔑  Update Saved Password\n"
        opts="${opts}🗑  Forget Network Profile\n"
        opts="${opts}⬅  Back to Wi-Fi Menu"

        local prompt_title="  Manage: $ssid"
        local choice
        choice=$(echo -e "$opts" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "$prompt_title" -lines 8)

        [ -z "$choice" ] && exit 0

        case "$choice" in
            *"Disconnect Network"*)
                nmcli connection down id "$ssid" &>/dev/null || nmcli device disconnect "$active_dev" &>/dev/null
                notify "📶 Wi-Fi Disconnected" "Disconnected from $ssid"
                exit 0
                ;;
            *"Connect to Network"*)
                notify "📶 Connecting..." "Connecting to $ssid"
                if nmcli connection up id "$ssid" &>/dev/null; then
                    notify "📶 Connected" "Successfully connected to $ssid"
                else
                    notify "❌ Connection Failed" "Could not connect to $ssid"
                fi
                exit 0
                ;;
            *"View Connection Details"*)
                local ip_addr gw dns mac
                if [ "$is_active" = true ] && [ -n "$active_dev" ]; then
                    ip_addr=$(nmcli -g IP4.ADDRESS device show "$active_dev" 2>/dev/null | head -n1)
                    gw=$(nmcli -g IP4.GATEWAY device show "$active_dev" 2>/dev/null)
                    dns=$(nmcli -g IP4.DNS device show "$active_dev" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
                    mac=$(nmcli -g GENERAL.HWADDR device show "$active_dev" 2>/dev/null)
                else
                    ip_addr=$(nmcli -g ipv4.addresses connection show id "$ssid" 2>/dev/null)
                    [ -z "$ip_addr" ] && ip_addr="DHCP (Automatic)"
                    gw=$(nmcli -g ipv4.gateway connection show id "$ssid" 2>/dev/null)
                    [ -z "$gw" ] && gw="Automatic"
                    dns=$(nmcli -g ipv4.dns connection show id "$ssid" 2>/dev/null)
                    [ -z "$dns" ] && dns="Automatic (DHCP)"
                    mac="N/A"
                fi

                local info_str="Network SSID : $ssid\n"
                info_str="${info_str}Status       : $( [ "$is_active" = true ] && echo "Active (Connected)" || echo "Saved Profile" )\n"
                info_str="${info_str}IP Address   : ${ip_addr:-N/A}\n"
                info_str="${info_str}Gateway      : ${gw:-N/A}\n"
                info_str="${info_str}DNS Servers  : ${dns:-N/A}\n"
                info_str="${info_str}Auto-Connect : $autoconnect\n"
                info_str="${info_str}MAC Address  : ${mac:-N/A}"

                echo -e "$info_str" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "ℹ Info: $ssid" -lines 7
                ;;
            *"Configure IPv4"*)
                local ip_opts="󰗑  Automatic (DHCP)\n󱐌  Manual (Static IP)"
                local ip_choice
                ip_choice=$(echo -e "$ip_opts" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "IPv4 Method for $ssid" -lines 2)
                
                if [[ "$ip_choice" =~ "Automatic" ]]; then
                    nmcli connection modify "$ssid" ipv4.method auto ipv4.addresses "" ipv4.gateway ""
                    notify "⚙ IPv4 Config" "$ssid set to Automatic (DHCP)"
                    [ "$is_active" = true ] && nmcli connection up id "$ssid" &>/dev/null
                elif [[ "$ip_choice" =~ "Manual" ]]; then
                    local new_ip new_gw new_dns
                    new_ip=$(rofi -dmenu -theme "${dir}/${theme}.rasi" -p "IP/Prefix (e.g. 192.168.1.150/24):" -lines 1)
                    [ -z "$new_ip" ] && continue

                    new_gw=$(rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Gateway (e.g. 192.168.1.1):" -lines 1)
                    [ -z "$new_gw" ] && continue

                    new_dns=$(rofi -dmenu -theme "${dir}/${theme}.rasi" -p "DNS (e.g. 8.8.8.8,1.1.1.1):" -lines 1)
                    [ -z "$new_dns" ] && new_dns="8.8.8.8,1.1.1.1"

                    nmcli connection modify "$ssid" ipv4.method manual ipv4.addresses "$new_ip" ipv4.gateway "$new_gw" ipv4.dns "$new_dns"
                    notify "⚙ IPv4 Config" "Static IP ($new_ip) set for $ssid"
                    [ "$is_active" = true ] && nmcli connection up id "$ssid" &>/dev/null
                fi
                ;;
            *"Configure DNS"*)
                local dns_opts="󰅡  Cloudflare (1.1.1.1, 1.0.0.1)\n󰅡  Google (8.8.8.8, 8.8.4.4)\n󰅡  Quad9 (9.9.9.9, 149.112.112.112)\n󰅡  Custom DNS Servers...\n󰑐  Automatic (DHCP Default)"
                local dns_choice
                dns_choice=$(echo -e "$dns_opts" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "DNS Provider for $ssid" -lines 5)

                if [[ "$dns_choice" =~ "Cloudflare" ]]; then
                    nmcli connection modify "$ssid" ipv4.dns "1.1.1.1,1.0.0.1" ipv4.ignore-auto-dns yes
                    notify "🌐 DNS Updated" "Set Cloudflare DNS for $ssid"
                elif [[ "$dns_choice" =~ "Google" ]]; then
                    nmcli connection modify "$ssid" ipv4.dns "8.8.8.8,8.8.4.4" ipv4.ignore-auto-dns yes
                    notify "🌐 DNS Updated" "Set Google DNS for $ssid"
                elif [[ "$dns_choice" =~ "Quad9" ]]; then
                    nmcli connection modify "$ssid" ipv4.dns "9.9.9.9,149.112.112.112" ipv4.ignore-auto-dns yes
                    notify "🌐 DNS Updated" "Set Quad9 DNS for $ssid"
                elif [[ "$dns_choice" =~ "Custom" ]]; then
                    local custom_dns
                    custom_dns=$(rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Enter DNS IPs (comma separated):" -lines 1)
                    if [ -n "$custom_dns" ]; then
                        nmcli connection modify "$ssid" ipv4.dns "$custom_dns" ipv4.ignore-auto-dns yes
                        notify "🌐 DNS Updated" "Set custom DNS ($custom_dns) for $ssid"
                    fi
                elif [[ "$dns_choice" =~ "Automatic" ]]; then
                    nmcli connection modify "$ssid" ipv4.dns "" ipv4.ignore-auto-dns no
                    notify "🌐 DNS Updated" "Restored automatic DHCP DNS for $ssid"
                fi
                [ "$is_active" = true ] && nmcli connection up id "$ssid" &>/dev/null
                ;;
            *"Toggle Auto-Connect"*)
                if [ "$autoconnect" = "yes" ]; then
                    nmcli connection modify "$ssid" connection.autoconnect no
                    notify "🔄 Auto-Connect" "Disabled auto-connect for $ssid"
                else
                    nmcli connection modify "$ssid" connection.autoconnect yes
                    notify "🔄 Auto-Connect" "Enabled auto-connect for $ssid"
                fi
                ;;
            *"Update Saved Password"*)
                local new_pass
                new_pass=$(rofi -dmenu -theme "${dir}/${theme}.rasi" -p "New Password for $ssid:" -password -lines 1)
                if [ -n "$new_pass" ]; then
                    nmcli connection modify "$ssid" 802-11-wireless-security.psk "$new_pass"
                    notify "🔑 Password Updated" "Updated saved password for $ssid"
                    [ "$is_active" = true ] && nmcli connection up id "$ssid" &>/dev/null
                fi
                ;;
            *"Forget Network Profile"*)
                local confirm
                confirm=$(echo -e "󰗑  Yes, Delete Profile\n󰅖  Cancel" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Delete profile for $ssid?" -lines 2)
                if [[ "$confirm" =~ "Yes" ]]; then
                    nmcli connection delete id "$ssid" &>/dev/null
                    notify "🗑 Network Forgotten" "Deleted profile $ssid"
                    exit 0
                fi
                ;;
            *"Back"*)
                return 0
                ;;
        esac
    done
}

# Parse available Wi-Fi networks safely
wifi_list=$(nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL,FREQ device wifi list 2>/dev/null | awk -F'[:]' -v active="$active_ssid" -v known="$known_connections" '
BEGIN {
    split(known, k_arr, "\n")
    for (i in k_arr) {
        if (k_arr[i] != "") saved[k_arr[i]] = 1
    }
}
{
    in_use = $1
    ssid = $2
    sec = $3
    sig = $4
    freq = $5

    # Skip empty SSIDs
    if (ssid != "") {
        if (freq ~ /^2/) {
            ghz = "2.4 GHz"
        } else if (freq ~ /^5/) {
            ghz = "5 GHz"
        } else if (freq ~ /^6/) {
            ghz = "6 GHz"
        } else {
            ghz = "Other"
        }

        key = ssid " (" ghz ")"
        if (!seen[key]++) {
            tag = ""
            if (in_use == "*" || ssid == active) {
                tag = "󰄬 [Connected] "
            } else if (ssid in saved) {
                tag = "󰋙 [Saved] "
            }
            print sig "% | " tag ssid " | " ghz " | [" sec "]"
        }
    }
}' | sort -t'|' -k1,1nr)

# Build main menu options
menu_options="$toggle_text\n󰑐  Rescan Networks"

if [ -n "$active_ssid" ]; then
    menu_options="${menu_options}\n󰄬  Connected: $active_ssid (Click to Configure)\n󰅖  Disconnect from $active_ssid"
fi

menu_options="${menu_options}\n──────────────\n$wifi_list"

chosen_option=$(echo -e "$menu_options" | rofi -dmenu -theme "${dir}/${theme}.rasi" -p " " -lines 14)

[ -z "$chosen_option" ] && exit 0

# Handle Wi-Fi Radio Toggle
if [ "$chosen_option" = "$toggle_text" ]; then
    if [ "$wifi_status" = "enabled" ]; then
        nmcli radio wifi off
        notify "📶 Wi-Fi Disabled" "Wi-Fi radio turned off"
    else
        nmcli radio wifi on
        notify "📶 Wi-Fi Enabled" "Wi-Fi radio turned on"
    fi
    exit 0
fi

# Handle Manual Rescan
if [ "$chosen_option" = "󰑐  Rescan Networks" ]; then
    nmcli device wifi rescan &>/dev/null
    notify "🔄 Scanning Networks" "Rescanning available Wi-Fi access points..."
    exec "$0"
fi

# Handle Direct Disconnect from Main Menu
if [[ "$chosen_option" =~ "Disconnect from" ]]; then
    nmcli connection down id "$active_ssid" &>/dev/null || nmcli device disconnect "$active_dev" &>/dev/null
    notify "📶 Wi-Fi Disconnected" "Disconnected from $active_ssid"
    exit 0
fi

# Handle Direct Click on Active Connected Header
if [[ "$chosen_option" =~ "Connected: " ]]; then
    manage_network "$active_ssid"
    exit 0
fi

# Ignore separator line click
if [[ "$chosen_option" =~ "──" ]]; then
    exit 0
fi

# Extract the exact SSID from chosen option block
raw_ssid_field=$(echo "$chosen_option" | awk -F' \\| ' '{print $2}')

# Remove tags if present
chosen_id=$(echo "$raw_ssid_field" | sed 's/^󰄬 \[Connected\] //; s/^󰋙 \[Saved\] //')

[ -z "$chosen_id" ] && exit 0

# Check if network is active or saved in NetworkManager
if [ "$chosen_id" = "$active_ssid" ] || echo "$known_connections" | grep -Fxq "$chosen_id"; then
    manage_network "$chosen_id"
else
    # Prompt for password via hidden Rofi input if not saved
    wifi_password=$(rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Password for $chosen_id: " -password -lines 1)
    
    if [ -n "$wifi_password" ]; then
        notify "📶 Connecting..." "Connecting to $chosen_id"
        if nmcli device wifi connect "$chosen_id" password "$wifi_password" &>/dev/null; then
            notify "📶 Connected" "Successfully connected to $chosen_id"
        else
            notify "❌ Connection Failed" "Password incorrect or connection failed"
        fi
    fi
fi