#!/usr/bin/env bash
# =============================================================================
# Idle Guard — blocks hypridle actions if audio is playing or a call is active
# Usage: idle_guard.sh <command to run>
# =============================================================================

# Check if any audio sink-input is actively running (playing audio)
if pactl list sink-inputs 2>/dev/null | grep -q "state: RUNNING"; then
    exit 0  # Audio is playing — do nothing
fi

# Check for active PipeWire streams (catches calls in Zoom, Teams, Discord, etc.)
if command -v pw-cli &>/dev/null; then
    if pw-dump 2>/dev/null | grep -q '"state": "streaming"'; then
        exit 0  # Active stream (mic/call) — do nothing
    fi
fi

# No audio/call activity — execute the idle action
exec "$@"
