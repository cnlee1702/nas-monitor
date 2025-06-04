#!/bin/bash
# NAS Monitor Manual Testing Script
# Interactive testing for features requiring user interaction or real hardware

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_CONFIG_DIR="$SCRIPT_DIR/test-configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test state
CURRENT_TEST=""
TEST_COUNT=0

# Helper functions
print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  $1  ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo
}

print_section() {
    echo -e "${CYAN}--- $1 ---${NC}"
    echo
}

ask_user() {
    local question="$1"
    local default="${2:-}"
    
    if [ -n "$default" ]; then
        echo -e "${YELLOW}$question [default: $default]: ${NC}"
    else
        echo -e "${YELLOW}$question: ${NC}"
    fi
    
    read -r response
    echo "${response:-$default}"
}

confirm_action() {
    local message="$1"
    echo -e "${YELLOW}$message (y/N): ${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

wait_for_user() {
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

test_step() {
    ((TEST_COUNT++))
    CURRENT_TEST="$1"
    echo -e "${BLUE}Test $TEST_COUNT: $CURRENT_TEST${NC}"
}

test_result() {
    local result="$1"
    local details="${2:-}"
    
    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✓ PASS: $CURRENT_TEST${NC}"
    elif [ "$result" = "fail" ]; then
        echo -e "${RED}✗ FAIL: $CURRENT_TEST${NC}"
    elif [ "$result" = "skip" ]; then
        echo -e "${YELLOW}⚠ SKIP: $CURRENT_TEST${NC}"
    fi
    
    if [ -n "$details" ]; then
        echo -e "  $details"
    fi
    echo
}

# Pre-flight checks
preflight_checks() {
    print_header "Pre-flight Checks"
    
    # Check if project is built
    test_step "Check if project is built"
    if [ -f "$PROJECT_ROOT/nas-config-gui" ]; then
        test_result "pass" "GUI binary found"
    else
        echo -e "${YELLOW}GUI not built. Building now...${NC}"
        if make -C "$PROJECT_ROOT" nas-config-gui; then
            test_result "pass" "GUI built successfully"
        else
            test_result "fail" "Failed to build GUI"
            exit 1
        fi
    fi
    
    # Check daemon script
    test_step "Check daemon script availability"
    if [ -f "$PROJECT_ROOT/src/nas-monitor.sh" ]; then
        test_result "pass" "Daemon script found"
    else
        test_result "fail" "Daemon script not found"
        exit 1
    fi
    
    # Check systemd user session
    test_step "Check systemd user session"
    if systemctl --user status >/dev/null 2>&1; then
        test_result "pass" "User systemd session active"
    else
        test_result "fail" "User systemd session not available"
        echo -e "${RED}This is required for service testing${NC}"
    fi
    
    echo -e "${GREEN}Pre-flight checks complete${NC}"
    wait_for_user
}

# Test configuration GUI
test_configuration_gui() {
    print_header "Configuration GUI Testing"
    
    test_step "Launch configuration GUI"
    echo -e "${CYAN}This will launch the configuration GUI for manual testing.${NC}"
    echo -e "${CYAN}Please test the following:${NC}"
    echo "1. Add/remove network names"
    echo "2. Add/remove NAS devices"
    echo "3. Adjust interval settings"
    echo "4. Toggle notifications"
    echo "5. Save configuration"
    echo "6. Close application"
    echo
    
    if confirm_action "Launch GUI now?"; then
        "$PROJECT_ROOT/nas-config-gui" &
        local gui_pid=$!
        
        echo -e "${CYAN}GUI launched with PID: $gui_pid${NC}"
        echo -e "${CYAN}Test the interface, then close it normally${NC}"
        
        wait_for_user
        
        # Check if GUI is still running
        if kill -0 "$gui_pid" 2>/dev/null; then
            echo -e "${YELLOW}GUI still running. Waiting for normal exit...${NC}"
            wait "$gui_pid"
        fi
        
        if confirm_action "Did the GUI work correctly?"; then
            test_result "pass" "User confirmed GUI functionality"
        else
            test_result "fail" "User reported GUI issues"
        fi
    else
        test_result "skip" "User skipped GUI testing"
    fi
}

# Test network detection
test_network_detection() {
    print_header "Network Detection Testing"
    
    test_step "Current network detection"
    echo -e "${CYAN}Testing network detection capability...${NC}"
    
    # Get current network
    local current_network=""
    if command -v nmcli >/dev/null 2>&1; then
        current_network=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d':' -f2 || echo "")
    fi
    
    if [ -n "$current_network" ]; then
        echo -e "${GREEN}Current network: $current_network${NC}"
        test_result "pass" "Network detection working"
    elif confirm_action "No WiFi network detected. Are you on Ethernet?"; then
        echo -e "${GREEN}Ethernet connection confirmed${NC}"
        test_result "pass" "Ethernet connection detected"
    else
        test_result "fail" "No network connection detected"
    fi
    
    # Test network switching (if WiFi available)
    if [ -n "$current_network" ]; then
        test_step "Network switching behavior"
        echo -e "${CYAN}For comprehensive testing, you could:${NC}"
        echo "1. Switch to a different WiFi network"
        echo "2. Disconnect from WiFi temporarily"
        echo "3. Reconnect to the original network"
        echo
        echo -e "${CYAN}This would test the daemon's network transition handling${NC}"
        
        if confirm_action "Have you tested network switching behavior?"; then
            test_result "pass" "User confirmed network switching tests"
        else
            test_result "skip" "Network switching tests skipped"
        fi
    fi
}

# Test power management features
test_power_management() {
    print_header "Power Management Testing"
    
    test_step "Power source detection"
    echo -e "${CYAN}Testing power source detection...${NC}"
    
    # Check multiple power detection methods
    local power_detected=false
    
    # Method 1: upower
    if command -v upower >/dev/null 2>&1; then
        local adapters
        adapters=$(upower -e | grep -E 'ADP|AC' || echo "")
        if [ -n "$adapters" ]; then
            for adapter in $adapters; do
                local status
                status=$(upower -i "$adapter" 2>/dev/null | grep "online:" | grep -o "true\|false" || echo "unknown")
                echo "  upower adapter $adapter: $status"
                if [ "$status" != "unknown" ]; then
                    power_detected=true
                fi
            done
        fi
    fi
    
    # Method 2: /sys/class/power_supply
    if [ -d /sys/class/power_supply ]; then
        for adapter in /sys/class/power_supply/A{C,DP}*; do
            if [ -f "$adapter/online" ]; then
                local status
                status=$(cat "$adapter/online" 2>/dev/null || echo "unknown")
                echo "  sysfs adapter $(basename "$adapter"): $status"
                if [ "$status" != "unknown" ]; then
                    power_detected=true
                fi
            fi
        done
    fi
    
    if $power_detected; then
        test_result "pass" "Power source detection working"
    else
        test_result "fail" "No power source detection available"
    fi
    
    # Battery level testing
    test_step "Battery level detection"
    local battery_detected=false
    
    if command -v upower >/dev/null 2>&1; then
        local batteries
        batteries=$(upower -e | grep 'BAT' || echo "")
        if [ -n "$batteries" ]; then
            for battery in $batteries; do
                local level
                level=$(upower -i "$battery" 2>/dev/null | grep "percentage" | grep -o '[0-9]*' || echo "unknown")
                echo "  Battery level: $level%"
                if [ "$level" != "unknown" ]; then
                    battery_detected=true
                fi
            done
        fi
    fi
    
    if $battery_detected; then
        test_result "pass" "Battery level detection working"
    elif confirm_action "No battery detected. Is this a desktop system?"; then
        test_result "pass" "Desktop system confirmed (no battery expected)"
    else
        test_result "fail" "Battery detection failed on laptop"
    fi
    
    # Power management behavior testing
    test_step "Power management behavior"
    echo -e "${CYAN}For thorough power management testing:${NC}"
    echo "1. Unplug AC adapter (if laptop)"
    echo "2. Monitor interval changes in logs"
    echo "3. Plug AC adapter back in"
    echo "4. Verify intervals change back"
    echo
    
    if confirm_action "Have you tested power management behavior?"; then
        test_result "pass" "User confirmed power management tests"
    else
        test_result "skip" "Power management behavior tests skipped"
    fi
}

# Test service integration
test_service_integration() {
    print_header "Service Integration Testing"
    
    # Check if service is installed
    test_step "Service installation check"
    local service_file="$HOME/.config/systemd/user/nas-monitor.service"
    if [ -f "$service_file" ]; then
        test_result "pass" "Service file found"
    else
        echo -e "${YELLOW}Service not installed. Installing now...${NC}"
        if make -C "$PROJECT_ROOT" install-service; then
            test_result "pass" "Service installed successfully"
        else
            test_result "fail" "Service installation failed"
            return
        fi
    fi
    
    # Test service start/stop
    test_step "Service lifecycle management"
    echo -e "${CYAN}Testing service start/stop functionality...${NC}"
    
    # Stop service if running
    systemctl --user stop nas-monitor.service 2>/dev/null || true
    
    # Start service
    if systemctl --user start nas-monitor.service; then
        echo -e "${GREEN}Service started successfully${NC}"
        
        # Check status
        sleep 2
        if systemctl --user is-active nas-monitor.service >/dev/null; then
            echo -e "${GREEN}Service is active${NC}"
            
            # Stop service
            if systemctl --user stop nas-monitor.service; then
                echo -e "${GREEN}Service stopped successfully${NC}"
                test_result "pass" "Service lifecycle management working"
            else
                test_result "fail" "Failed to stop service"
            fi
        else
            test_result "fail" "Service failed to become active"
        fi
    else
        test_result "fail" "Failed to start service"
    fi
    
    # Test logging
    test_step "Service logging"
    echo -e "${CYAN}Testing service logging functionality...${NC}"
    
    # Start service briefly to generate logs
    systemctl --user start nas-monitor.service
    sleep 5
    systemctl --user stop nas-monitor.service
    
    # Check for log output
    local log_output
    log_output=$(journalctl --user -u nas-monitor.service --since "1 minute ago" --no-pager 2>/dev/null || echo "")
    
    if [ -n "$log_output" ]; then
        echo -e "${GREEN}Log output detected:${NC}"
        echo "$log_output" | head -5
        test_result "pass" "Service logging working"
    else
        test_result "fail" "No log output detected"
    fi
}

# Test real NAS connectivity (if available)
test_nas_connectivity() {
    print_header "NAS Connectivity Testing (Optional)"
    
    echo -e "${CYAN}This section tests actual NAS connectivity.${NC}"
    echo -e "${CYAN}Only proceed if you have a real NAS available for testing.${NC}"
    echo
    
    if ! confirm_action "Do you have a NAS available for testing?"; then
        echo -e "${YELLOW}Skipping NAS connectivity tests${NC}"
        return
    fi
    
    # Get NAS details from user
    local nas_host
    nas_host=$(ask_user "Enter NAS hostname or IP address" "my-nas.local")
    
    local nas_share
    nas_share=$(ask_user "Enter share name" "home")
    
    # Test network connectivity
    test_step "NAS network connectivity"
    echo -e "${CYAN}Testing connectivity to $nas_host...${NC}"
    
    if ping -c 3 -W 5 "$nas_host" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Network connectivity to $nas_host successful${NC}"
        test_result "pass" "NAS network connectivity working"
    else
        echo -e "${RED}✗ Cannot reach $nas_host${NC}"
        test_result "fail" "NAS network connectivity failed"
        return
    fi
    
    # Test SMB connectivity
    test_step "SMB share accessibility"
    echo -e "${CYAN}Testing SMB connectivity to $nas_host/$nas_share...${NC}"
    
    if gio mount "smb://$nas_host/$nas_share" 2>/dev/null; then
        echo -e "${GREEN}✓ SMB mount successful${NC}"
        
        # Check if mount is visible
        local mount_point
        mount_point=$(gio mount -l | grep "$nas_host" | grep "$nas_share" || echo "")
        
        if [ -n "$mount_point" ]; then
            echo -e "${GREEN}✓ Mount point visible: $mount_point${NC}"
            test_result "pass" "SMB connectivity working"
            
            # Unmount for cleanup
            gio mount -u "smb://$nas_host/$nas_share" 2>/dev/null || true
        else
            test_result "fail" "Mount succeeded but not visible"
        fi
    else
        echo -e "${RED}✗ SMB mount failed${NC}"
        echo -e "${YELLOW}This might be due to:${NC}"
        echo "  - Incorrect credentials"
        echo "  - Share not accessible"
        echo "  - SMB version compatibility"
        test_result "fail" "SMB connectivity failed"
    fi
}

# Test configuration file handling
test_configuration_handling() {
    print_header "Configuration File Handling"
    
    # Create test configuration
    test_step "Configuration file creation and parsing"
    local test_config="$TEST_CONFIG_DIR/manual-test-config.conf"
    
    cat > "$test_config" << EOF
[networks]
home_networks=TestNetwork1,TestNetwork2

[nas_devices]
test-nas.local/share1
another-nas.local/share2

[intervals]
home_ac_interval=20
home_battery_interval=80
away_ac_interval=200
away_battery_interval=800

[behavior]
max_failed_attempts=5
min_battery_level=15
enable_notifications=true
EOF
    
    chmod 600 "$test_config"
    
    if [ -f "$test_config" ]; then
        echo -e "${GREEN}✓ Test configuration created${NC}"
        
        # Test GUI with this configuration
        if confirm_action "Test GUI with this configuration?"; then
            # Backup existing config if it exists
            local user_config="$HOME/.config/nas-monitor/config.conf"
            local backup_config=""
            
            if [ -f "$user_config" ]; then
                backup_config="$user_config.backup.$(date +%s)"
                cp "$user_config" "$backup_config"
                echo -e "${YELLOW}Backed up existing config to $backup_config${NC}"
            fi
            
            # Copy test config
            mkdir -p "$(dirname "$user_config")"
            cp "$test_config" "$user_config"
            
            # Launch GUI
            "$PROJECT_ROOT/nas-config-gui" &
            local gui_pid=$!
            
            echo -e "${CYAN}GUI launched with test configuration${NC}"
            echo -e "${CYAN}Verify that the configuration values are loaded correctly${NC}"
            
            wait_for_user
            
            # Kill GUI if still running
            if kill -0 "$gui_pid" 2>/dev/null; then
                kill "$gui_pid" 2>/dev/null || true
            fi
            
            # Restore backup if it exists
            if [ -n "$backup_config" ]; then
                mv "$backup_config" "$user_config"
                echo -e "${YELLOW}Restored original configuration${NC}"
            else
                rm -f "$user_config"
            fi
            
            if confirm_action "Did the configuration load correctly in the GUI?"; then
                test_result "pass" "Configuration file handling working"
            else
                test_result "fail" "Configuration file handling failed"
            fi
        else
            test_result "skip" "GUI configuration test skipped"
        fi
    else
        test_result "fail" "Failed to create test configuration"
    fi
    
    # Clean up
    rm -f "$test_config"
}

# Generate test report
generate_report() {
    print_header "Manual Test Report"
    
    echo -e "${CYAN}Manual testing completed with $TEST_COUNT tests.${NC}"
    echo
    echo -e "${CYAN}Summary of tested components:${NC}"
    echo "✓ Pre-flight checks"
    echo "✓ Configuration GUI"
    echo "✓ Network detection"
    echo "✓ Power management"
    echo "✓ Service integration"
    echo "✓ Configuration handling"
    echo "○ NAS connectivity (optional)"
    echo
    
    echo -e "${CYAN}For production deployment, ensure:${NC}"
    echo "1. All tests pass on target systems"
    echo "2. Real NAS connectivity is verified"
    echo "3. Power management works on actual laptops"
    echo "4. Network switching is tested in real scenarios"
    echo "5. Service auto-start is configured"
    echo
    
    echo -e "${GREEN}Manual testing completed!${NC}"
}

# Cleanup
cleanup() {
    # Stop any running services
    systemctl --user stop nas-monitor.service 2>/dev/null || true
    
    # Clean up test files
    rm -rf "$TEST_CONFIG_DIR/manual-test-*"
}

# Main execution
main() {
    # Setup
    mkdir -p "$TEST_CONFIG_DIR"
    trap cleanup EXIT
    
    print_header "NAS Monitor Manual Test Suite"
    echo -e "${CYAN}This script performs interactive testing of NAS Monitor components.${NC}"
    echo -e "${CYAN}It requires user interaction and may launch GUI applications.${NC}"
    echo
    
    if ! confirm_action "Continue with manual testing?"; then
        echo -e "${YELLOW}Manual testing cancelled${NC}"
        exit 0
    fi
    
    # Run tests
    preflight_checks
    test_configuration_gui
    test_network_detection
    test_power_management
    test_service_integration
    test_configuration_handling
    test_nas_connectivity
    
    # Generate report
    generate_report
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi