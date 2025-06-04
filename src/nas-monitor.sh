#!/bin/bash

# Power-aware NAS monitor for laptops
# Automatically mounts SMB shares when on home network with power source awareness

CONFIG_FILE="$HOME/.config/nas-monitor/config.conf"
LOG_FILE="$HOME/.local/share/nas-monitor.log"
LOCK_FILE="/tmp/nas-monitor-$USER.lock"

# Global variables
declare -a HOME_NETWORKS
declare -a NAS_DEVICES
HOME_AC_INTERVAL=15
HOME_BATTERY_INTERVAL=60
AWAY_AC_INTERVAL=180
AWAY_BATTERY_INTERVAL=600
MIN_BATTERY_LEVEL=10
ENABLE_NOTIFICATIONS=true

# Runtime state
declare -A FAILED_ATTEMPTS
CURRENT_NETWORK=""
IS_HOME_NETWORK=false
ON_AC_POWER=false
LAST_STATUS_LOG=0

setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    exec 1> >(while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S'): $line" >> "$LOG_FILE"; done)
    exec 2>&1
}

cleanup() {
    echo "NAS monitor stopping"
    rm -f "$LOCK_FILE"
    exit 0
}

check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Another instance is already running (PID: $pid)"
            exit 1
        else
            echo "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ERROR: Configuration file not found: $CONFIG_FILE"
        echo "Please create the configuration file first."
        exit 1
    fi

    # Parse networks section
    local in_networks=false
    local in_nas=false
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Section headers
        if [[ "$line" =~ ^\[networks\]$ ]]; then
            in_networks=true
            in_nas=false
            continue
        elif [[ "$line" =~ ^\[nas_devices\]$ ]]; then
            in_networks=false
            in_nas=true
            continue
        elif [[ "$line" =~ ^\[.*\]$ ]]; then
            in_networks=false
            in_nas=false
        fi
        
        # Parse network names
        if $in_networks && [[ "$line" =~ ^home_networks=(.*)$ ]]; then
            IFS=',' read -ra HOME_NETWORKS <<< "${BASH_REMATCH[1]}"
        fi
        
        # Parse NAS devices
        if $in_nas && [[ "$line" =~ ^[^=]*\.[^=]*/[^=]*$ ]]; then
            NAS_DEVICES+=("$line")
        fi
        
        # Parse configuration values
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            case "$key" in
                home_ac_interval) HOME_AC_INTERVAL="$value" ;;
                home_battery_interval) HOME_BATTERY_INTERVAL="$value" ;;
                away_ac_interval) AWAY_AC_INTERVAL="$value" ;;
                away_battery_interval) AWAY_BATTERY_INTERVAL="$value" ;;
                min_battery_level) MIN_BATTERY_LEVEL="$value" ;;
                enable_notifications) ENABLE_NOTIFICATIONS="$value" ;;
            esac
        fi
    done < "$CONFIG_FILE"
    
    # Validate configuration
    if [ ${#NAS_DEVICES[@]} -eq 0 ]; then
        echo "ERROR: No NAS devices configured"
        exit 1
    fi
    
    echo "Loaded configuration:"
    echo "  Home networks: ${HOME_NETWORKS[*]}"
    echo "  NAS devices: ${NAS_DEVICES[*]}"
    echo "  Intervals: AC($HOME_AC_INTERVAL) Battery($HOME_BATTERY_INTERVAL) Away-AC($AWAY_AC_INTERVAL) Away-Battery($AWAY_BATTERY_INTERVAL)"
}

get_current_network() {
    if command -v nmcli >/dev/null 2>&1; then
        nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d':' -f2
    else
        echo ""  # Assume ethernet if nmcli not available
    fi
}

is_home_network() {
    local current_network="$1"
    
    for network in "${HOME_NETWORKS[@]}"; do
        if [[ "$current_network" == "$network" ]]; then
            return 0
        fi
    done
    return 1
}

check_power_source() {
    # Method 1: upower (most reliable)
    if command -v upower >/dev/null 2>&1; then
        local adapters
        adapters=$(upower -e | grep -E 'ADP|AC')
        for adapter in $adapters; do
            if upower -i "$adapter" 2>/dev/null | grep -q "online:.*true"; then
                return 0
            fi
        done
    fi
    
    # Method 2: /sys/class/power_supply
    for adapter in /sys/class/power_supply/A{C,DP}*; do
        if [ -f "$adapter/online" ] && [ "$(cat "$adapter/online" 2>/dev/null)" = "1" ]; then
            return 0
        fi
    done
    
    # Method 3: acpi command
    if command -v acpi >/dev/null 2>&1; then
        if acpi -a 2>/dev/null | grep -q "on-line"; then
            return 0
        fi
    fi
    
    return 1  # Assume battery power if can't determine
}

get_battery_level() {
    local battery_level=""
    
    # Method 1: upower
    if command -v upower >/dev/null 2>&1; then
        local batteries
        batteries=$(upower -e | grep 'BAT')
        for battery in $batteries; do
            battery_level=$(upower -i "$battery" 2>/dev/null | grep -E "percentage" | grep -o '[0-9]*' | head -1)
            [ -n "$battery_level" ] && break
        done
    fi
    
    # Method 2: /sys/class/power_supply
    if [ -z "$battery_level" ]; then
        for bat in /sys/class/power_supply/BAT*; do
            if [ -f "$bat/capacity" ]; then
                battery_level=$(cat "$bat/capacity" 2>/dev/null)
                break
            fi
        done
    fi
    
    # Default if can't determine
    echo "${battery_level:-50}"
}

determine_check_interval() {
    local battery_level
    battery_level=$(get_battery_level)
    local base_interval
    
    if $IS_HOME_NETWORK; then
        if $ON_AC_POWER; then
            base_interval=$HOME_AC_INTERVAL
        else
            base_interval=$HOME_BATTERY_INTERVAL
        fi
    else
        if $ON_AC_POWER; then
            base_interval=$AWAY_AC_INTERVAL
        else
            base_interval=$AWAY_BATTERY_INTERVAL
        fi
    fi
    
    # Adjust interval based on battery level
    if ! $ON_AC_POWER; then
        if [ "$battery_level" -lt 20 ]; then
            base_interval=$((base_interval * 2))
        fi
        if [ "$battery_level" -lt "$MIN_BATTERY_LEVEL" ]; then
            base_interval=$((base_interval * 4))
        fi
    fi
    
    echo "$base_interval"
}

send_notification() {
    if $ENABLE_NOTIFICATIONS && command -v notify-send >/dev/null 2>&1; then
        notify-send "$@"
    fi
}

check_and_mount_nas() {
    local mounted_count=0
    local attempted_count=0
    
    # Only attempt mounting on home network
    if ! $IS_HOME_NETWORK; then
        return 0
    fi
    
    # Skip on very low battery
    local battery_level
    battery_level=$(get_battery_level)
    if ! $ON_AC_POWER && [ "$battery_level" -lt "$MIN_BATTERY_LEVEL" ]; then
        echo "Skipping mount attempts - critical battery level ($battery_level%)"
        return 0
    fi
    
    for nas_device in "${NAS_DEVICES[@]}"; do
        local nas_host nas_share
        nas_host=$(echo "$nas_device" | cut -d'/' -f1)
        nas_share=$(echo "$nas_device" | cut -d'/' -f2-)
        local mount_key="$nas_device"
        
        # Check if already mounted
        if gio mount -l 2>/dev/null | grep -q "$nas_host.*$nas_share"; then
            FAILED_ATTEMPTS["$mount_key"]=0
            ((mounted_count++))
            continue
        fi
        
        ((attempted_count++))
        
        # Check connectivity before mount attempt
        if ! ping -c 1 -W 3 "$nas_host" >/dev/null 2>&1; then
            FAILED_ATTEMPTS["$mount_key"]=$((${FAILED_ATTEMPTS["$mount_key"]:-0} + 1))
            echo "Cannot reach $nas_host (attempt ${FAILED_ATTEMPTS["$mount_key"]})"
            continue
        fi
        
        # Attempt mount
        if gio mount "smb://$nas_device" >/dev/null 2>&1; then
            echo "Successfully mounted $nas_device"
            send_notification "NAS Connected" "$nas_device is now available"
            FAILED_ATTEMPTS["$mount_key"]=0
            ((mounted_count++))
        else
            FAILED_ATTEMPTS["$mount_key"]=$((${FAILED_ATTEMPTS["$mount_key"]:-0} + 1))
            echo "Failed to mount $nas_device (attempt ${FAILED_ATTEMPTS["$mount_key"]})"
            
            # Notify on first failure
            if [ "${FAILED_ATTEMPTS["$mount_key"]}" -eq 1 ]; then
                send_notification "NAS Mount Failed" "Cannot connect to $nas_device"
            fi
        fi
    done
    
    return "$attempted_count"
}

log_periodic_status() {
    local current_time
    current_time=$(date +%s)
    
    # Log status every hour
    if [ $((current_time - LAST_STATUS_LOG)) -gt 3600 ]; then
        local power_status
        power_status="Battery($(get_battery_level)%)"
        $ON_AC_POWER && power_status="AC Power"
        
        local network_status="Away"
        $IS_HOME_NETWORK && network_status="Home($CURRENT_NETWORK)"
        
        local interval
        interval=$(determine_check_interval)
        echo "Status: $network_status, $power_status, Check interval: ${interval}s"
        
        LAST_STATUS_LOG=$current_time
    fi
}

main() {
    echo "Starting power-aware NAS monitor"
    
    setup_logging
    check_lock
    trap cleanup EXIT INT TERM
    
    load_config
    
    # Wait for desktop environment to be ready
    sleep 10
    
    while true; do
        # Update current state
        CURRENT_NETWORK=$(get_current_network)
        
        if check_power_source; then
            ON_AC_POWER=true
        else
            ON_AC_POWER=false
        fi
        
        if is_home_network "$CURRENT_NETWORK"; then
            IS_HOME_NETWORK=true
        else
            IS_HOME_NETWORK=false
        fi
        
        # Determine check interval
        CHECK_INTERVAL=$(determine_check_interval)
        
        # Log status periodically
        log_periodic_status
        
        # Attempt NAS mounting
        check_and_mount_nas
        
        # Sleep until next check
        sleep "$CHECK_INTERVAL"
    done
}

# Run main function
main "$@"