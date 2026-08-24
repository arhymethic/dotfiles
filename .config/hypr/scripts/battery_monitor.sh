#!/usr/bin/env bash
# =============================================================================
# Low Battery Monitor for Hyprland + Dunst
# Monitors battery level and handles:
#   1. Low battery warning (<= 20%)
#   2. Critical battery sleep/suspend (<= 10%)
#   3. Emergency shutdown (<= 5%)
# =============================================================================

# Auto-detect battery device
BATTERY=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT' | head -n 1)

# If running on desktop PC without a battery, exit cleanly
if [ -z "$BATTERY" ]; then
    exit 0
fi

LOW_THRESHOLD=20      # Low battery notification threshold
SLEEP_THRESHOLD=10    # System suspend threshold
SHUTDOWN_THRESHOLD=5  # System poweroff threshold

# Polling intervals (seconds)
NORMAL_INTERVAL=60
ALERT_INTERVAL=15

last_notified=""
slept_at_10=false
shutdown_triggered=false
grace_until=0

while true; do
    capacity=$(cat /sys/class/power_supply/"$BATTERY"/capacity 2>/dev/null)
    status=$(cat /sys/class/power_supply/"$BATTERY"/status 2>/dev/null)
    now=$(date +%s)

    if [[ "$status" == "Discharging" && -n "$capacity" ]]; then
        # 1. EMERGENCY SHUTDOWN (<= 5%)
        if (( capacity <= SHUTDOWN_THRESHOLD )); then
            if [[ "$shutdown_triggered" == false ]]; then
                shutdown_triggered=true
                dunstify -u critical -i battery-empty \
                    -h string:x-dunst-stack-tag:battery \
                    "🚨 Emergency Shutdown" "Battery at ${capacity}%! System is shutting down NOW to protect hardware."
                sleep 3
                # Re-verify still discharging before powering off
                current_status=$(cat /sys/class/power_supply/"$BATTERY"/status 2>/dev/null)
                if [[ "$current_status" == "Discharging" ]]; then
                    systemctl poweroff
                else
                    shutdown_triggered=false
                fi
            fi

        # 2. CRITICAL BATTERY SLEEP (<= 10%)
        elif (( capacity <= SLEEP_THRESHOLD )); then
            if [[ "$slept_at_10" == false && "$now" -ge "$grace_until" ]]; then
                dunstify -u critical -i battery-caution \
                    -h string:x-dunst-stack-tag:battery \
                    "⚠ Critical Battery (${capacity}%)" "System will sleep in 5 seconds! Plug in charger immediately."
                sleep 5
                # Re-verify still discharging before suspending
                current_status=$(cat /sys/class/power_supply/"$BATTERY"/status 2>/dev/null)
                if [[ "$current_status" == "Discharging" ]]; then
                    slept_at_10=true
                    # Give 120s grace period after waking up before suspending again
                    grace_until=$(( $(date +%s) + 120 ))
                    systemctl suspend
                fi
            fi
            last_notified="critical"

        # 3. LOW BATTERY WARNING (<= 20%)
        elif (( capacity <= LOW_THRESHOLD )); then
            if [[ "$last_notified" != "low" ]]; then
                dunstify -u normal -i battery-low \
                    -h string:x-dunst-stack-tag:battery \
                    "🔋 Battery Low" "Battery at ${capacity}% — consider plugging in."
                last_notified="low"
            fi
            # Reset sleep flag if battery went above 10%
            slept_at_10=false
        else
            # Battery > 20%
            last_notified=""
            slept_at_10=false
            shutdown_triggered=false
        fi

        interval=$ALERT_INTERVAL
    else
        # Charging or Full — reset state
        last_notified=""
        slept_at_10=false
        shutdown_triggered=false
        interval=$NORMAL_INTERVAL
    fi

    sleep "$interval"
done
