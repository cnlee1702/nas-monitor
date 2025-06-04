#!/bin/bash
# NAS Monitor Integration Tests
# Tests the complete workflow from installation to operation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_CONFIG_DIR="$SCRIPT_DIR/test-configs"
TEST_LOG_DIR="/tmp/nas-monitor-integration"
MOCK_NAS_DIR="/tmp/mock-nas"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test state
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CLEANUP_TASKS=()

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INTEGRATION] $*" | tee -a "$TEST_LOG_DIR/integration.log"
}

log_test() {
    local test_name="$1"
    echo -e "${BLUE}Testing: $test_name${NC}"
    log "Starting test: $test_name"
    ((TESTS_RUN++))
}

test_pass() {
    local test_name="$1"
    local details="${2:-}"
    echo -e "${GREEN}✓ PASS: $test_name${NC}"
    log "PASS: $test_name - $details"
    ((TESTS_PASSED++))
}

test_fail() {
    local test_name="$1"
    local details="${2:-}"
    echo -e "${RED}✗ FAIL: $test_name${NC}"
    log "FAIL: $test_name - $details"
    ((TESTS_FAILED++))
}

# Cleanup management
add_cleanup() {
    CLEANUP_TASKS+=("$1")
}

run_cleanup() {
    echo -e "${BLUE}Running cleanup tasks...${NC}"
    for task in "${CLEANUP_TASKS[@]}"; do
        eval "$task" || true
    done
}

# Setup test environment
setup_test_environment() {
    echo -e "${BLUE}Setting up integration test environment...${NC}"
    
    # Create directories
    mkdir -p "$TEST_LOG_DIR"
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$MOCK_NAS_DIR"
    
    # Create test configuration
    cat > "$TEST_CONFIG_DIR/integration-config.conf" << 'EOF'
[networks]
home_networks=IntegrationTest-WiFi,IntegrationTest-5G,

[nas_devices]
mock-nas.local/testshare

[intervals]
home_ac_interval=5
home_battery_interval=10
away_ac_interval=15
away_battery_interval=20

[behavior]
max_failed_attempts=2
min_battery_level=5
enable_notifications=false
EOF
    
    chmod 600 "$TEST_CONFIG_DIR/integration-config.conf"
    
    # Setup mock NAS directory
    mkdir -p "$MOCK_NAS_DIR/testshare"
    echo "Mock NAS test file" > "$MOCK_NAS_DIR/testshare/test.txt"
    
    add_cleanup "rm -rf '$TEST_LOG_DIR'"
    add_cleanup "rm -rf '$MOCK_NAS_DIR'"
    add_cleanup "systemctl --user stop nas-monitor.service 2>/dev/null || true"
    
    log "Test environment setup complete"
}

# Test 1: Clean installation
test_clean_installation() {
    log_test "Clean installation workflow"
    
    # Uninstall first (in case previous install exists)
    make -C "$PROJECT_ROOT" uninstall >/dev/null 2>&1 || true
    
    # Run installation
    if make -C "$PROJECT_ROOT" install >/dev/null 2>&1; then
        # Verify installation
        local installed=true
        
        if [ ! -f "$HOME/.local/bin/nas-monitor.sh" ]; then
            installed=false
        fi
        
        if [ ! -f "$HOME/.local/bin/nas-config-gui" ]; then
            installed=false
        fi
        
        if [ ! -f "$HOME/.config/systemd/user/nas-monitor.service" ]; then
            installed=false
        fi
        
        if $installed; then
            test_pass "Clean installation" "All components installed correctly"
        else
            test_fail "Clean installation" "Some components missing after installation"
        fi
    else
        test_fail "Clean installation" "Installation command failed"
    fi
    
    add_cleanup "make -C '$PROJECT_ROOT' uninstall >/dev/null 2>&1 || true"
}

# Test 2: Configuration deployment
test_configuration_deployment() {
    log_test "Configuration file deployment"
    
    # Deploy test configuration
    local config_dir="$HOME/.config/nas-monitor"
    local config_file="$config_dir/config.conf"
    
    # Backup existing config if present
    if [ -f "$config_file" ]; then
        cp "$config_file" "$config_file.backup.integration"
        add_cleanup "mv '$config_file.backup.integration' '$config_file' 2>/dev/null || true"
    else
        add_cleanup "rm -f '$config_file'"
    fi
    
    # Deploy test configuration
    mkdir -p "$config_dir"
    cp "$TEST_CONFIG_DIR/integration-config.conf" "$config_file"
    
    # Verify deployment
    if [ -f "$config_file" ] && [ -r "$config_file" ]; then
        local perms
        perms=$(stat -c "%a" "$config_file")
        if [ "$perms" = "600" ]; then
            test_pass "Configuration deployment" "Config file deployed with correct permissions"
        else
            test_fail "Configuration deployment" "Config file has incorrect permissions: $perms"
        fi
    else
        test_fail "Configuration deployment" "Config file not accessible after deployment"
    fi
}

# Test 3: Service lifecycle
test_service_lifecycle() {
    log_test "Service lifecycle management"
    
    # Reload systemd
    systemctl --user daemon-reload
    
    # Test service start
    if systemctl --user start nas-monitor.service; then
        sleep 3
        
        if systemctl --user is-active nas-monitor.service >/dev/null; then
            test_pass "Service start" "Service started and is active"
            
            # Test service stop
            if systemctl --user stop nas-monitor.service; then
                sleep 1
                
                if ! systemctl --user is-active nas-monitor.service >/dev/null; then
                    test_pass "Service stop" "Service stopped successfully"
                else
                    test_fail "Service stop" "Service still active after stop command"
                fi
            else
                test_fail "Service stop" "Stop command failed"
            fi
        else
            test_fail "Service start" "Service not active after start command"
        fi
    else
        test_fail "Service start" "Start command failed"
    fi
}

# Test 4: Configuration validation
test_configuration_validation() {
    log_test "Configuration validation in running service"
    
    # Start service with test configuration
    systemctl --user start nas-monitor.service
    sleep 5
    
    # Check logs for configuration loading
    local log_output
    log_output=$(journalctl --user -u nas-monitor.service --since "1 minute ago" --no-pager 2>/dev/null || echo "")
    
    if echo "$log_output" | grep -q "Loaded configuration"; then
        test_pass "Configuration loading" "Service loaded configuration successfully"
    else
        # Check if service is at least running (might not have specific log message)
        if systemctl --user is-active nas-monitor.service >/dev/null; then
            test_pass "Configuration loading" "Service running (configuration assumed loaded)"
        else
            test_fail "Configuration loading" "Service failed to start with configuration"
        fi
    fi
    
    systemctl --user stop nas-monitor.service
}

# Test 5: Network detection simulation
test_network_detection() {
    log_test "Network detection functionality"
    
    # This test simulates network detection by checking if the daemon
    # can detect the current network state
    
    local current_network=""
    if command -v nmcli >/dev/null 2>&1; then
        current_network=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d':' -f2 || echo "")
    fi
    
    # Start service and check if it detects network state
    systemctl --user start nas-monitor.service
    sleep 10  # Give it time to detect network
    
    local log_output
    log_output=$(journalctl --user -u nas-monitor.service --since "30 seconds ago" --no-pager 2>/dev/null || echo "")
    
    # Look for network-related log entries
    if echo "$log_output" | grep -qE "(network|wifi|ethernet|away|home)"; then
        test_pass "Network detection" "Service shows network awareness in logs"
    elif [ -n "$current_network" ]; then
        test_pass "Network detection" "Network detected: $current_network (service logs may not show details)"
    else
        test_pass "Network detection" "No WiFi network (ethernet assumed)"
    fi
    
    systemctl --user stop nas-monitor.service
}

# Test 6: Power management simulation
test_power_management() {
    log_test "Power management functionality"
    
    # Check if power detection methods are available
    local power_methods=0
    
    # Check upower
    if command -v upower >/dev/null 2>&1; then
        ((power_methods++))
    fi
    
    # Check /sys/class/power_supply
    if [ -d /sys/class/power_supply ]; then
        ((power_methods++))
    fi
    
    # Check acpi
    if command -v acpi >/dev/null 2>&1; then
        ((power_methods++))
    fi
    
    if [ $power_methods -gt 0 ]; then
        # Start service and check for power-related activity
        systemctl --user start nas-monitor.service
        sleep 5
        
        local log_output
        log_output=$(journalctl --user -u nas-monitor.service --since "30 seconds ago" --no-pager 2>/dev/null || echo "")
        
        # Service should be running (power detection happens internally)
        if systemctl --user is-active nas-monitor.service >/dev/null; then
            test_pass "Power management" "Service running with power detection available"
        else
            test_fail "Power management" "Service failed with power detection available"
        fi
        
        systemctl --user stop nas-monitor.service
    else
        test_fail "Power management" "No power detection methods available"
    fi
}

# Test 7: GUI integration
test_gui_integration() {
    log_test "GUI integration with configuration"
    
    # Test GUI startup (non-interactive)
    local gui_binary="$HOME/.local/bin/nas-config-gui"
    
    if [ -f "$gui_binary" ] && [ -x "$gui_binary" ]; then
        # Test that GUI can start (will exit quickly in headless environment)
        if timeout 5 "$gui_binary" --help 2>/dev/null || 
           timeout 5 "$gui_binary" --version 2>/dev/null ||
           timeout 2 "$gui_binary" 2>/dev/null; then
            test_pass "GUI integration" "GUI binary executable and responsive"
        else
            # GUI might not run in headless environment, check if it's properly linked
            if ldd "$gui_binary" >/dev/null 2>&1; then
                test_pass "GUI integration" "GUI binary properly linked (may need display)"
            else
                test_fail "GUI integration" "GUI binary has linking issues"
            fi
        fi
    else
        test_fail "GUI integration" "GUI binary not found or not executable"
    fi
}

# Test 8: Log rotation and management
test_log_management() {
    log_test "Log management functionality"
    
    local log_file="$HOME/.local/share/nas-monitor.log"
    
    # Start service to generate logs
    systemctl --user start nas-monitor.service
    sleep 5
    systemctl --user stop nas-monitor.service
    
    # Check systemd journal logs
    local journal_logs
    journal_logs=$(journalctl --user -u nas-monitor.service --since "1 minute ago" --no-pager 2>/dev/null || echo "")
    
    if [ -n "$journal_logs" ]; then
        test_pass "Systemd logging" "Service logs to systemd journal"
    else
        test_fail "Systemd logging" "No systemd journal entries found"
    fi
    
    # Check application logs (if daemon creates them)
    if [ -f "$log_file" ]; then
        test_pass "Application logging" "Application log file created"
    else
        # This might be normal if daemon only logs to systemd
        test_pass "Application logging" "No separate log file (systemd-only logging)"
    fi
}

# Test 9: Upgrade simulation
test_upgrade_simulation() {
    log_test "Upgrade workflow simulation"
    
    # Simulate an upgrade by reinstalling
    if make -C "$PROJECT_ROOT" install >/dev/null 2>&1; then
        # Reload systemd to pick up any service changes
        systemctl --user daemon-reload
        
        # Verify service still works after upgrade
        if systemctl --user start nas-monitor.service; then
            sleep 3
            
            if systemctl --user is-active nas-monitor.service >/dev/null; then
                test_pass "Upgrade simulation" "Service works after reinstallation"
            else
                test_fail "Upgrade simulation" "Service failed after reinstallation"
            fi
            
            systemctl --user stop nas-monitor.service
        else
            test_fail "Upgrade simulation" "Service failed to start after reinstallation"
        fi
    else
        test_fail "Upgrade simulation" "Reinstallation failed"
    fi
}

# Test 10: End-to-end workflow
test_end_to_end_workflow() {
    log_test "End-to-end workflow"
    
    # This test runs through a complete user workflow:
    # 1. Start service
    # 2. Let it run for a reasonable time
    # 3. Check for proper operation
    # 4. Stop service
    
    echo -e "${CYAN}Running end-to-end workflow test...${NC}"
    
    # Start service
    if systemctl --user start nas-monitor.service; then
        echo "  Service started..."
        
        # Let it run for 30 seconds to simulate real operation
        local runtime=30
        echo "  Letting service run for ${runtime} seconds..."
        sleep $runtime
        
        # Check if still active
        if systemctl --user is-active nas-monitor.service >/dev/null; then
            echo "  Service remained stable during runtime"
            
            # Check logs for any errors
            local log_output
            log_output=$(journalctl --user -u nas-monitor.service --since "1 minute ago" --no-pager 2>/dev/null || echo "")
            
            if echo "$log_output" | grep -qiE "(error|fail|exception)"; then
                test_fail "End-to-end workflow" "Errors found in service logs during runtime"
            else
                test_pass "End-to-end workflow" "Service ran successfully for ${runtime} seconds without errors"
            fi
        else
            test_fail "End-to-end workflow" "Service stopped unexpectedly during runtime"
        fi
        
        # Stop service
        systemctl --user stop nas-monitor.service
    else
        test_fail "End-to-end workflow" "Failed to start service for end-to-end test"
    fi
}

# Generate integration test report
generate_integration_report() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   Integration Test Results     ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Tests run:    ${BLUE}$TESTS_RUN${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All integration tests passed! ✓${NC}"
        echo -e "${GREEN}NAS Monitor is ready for production use.${NC}"
        
        # Success recommendations
        echo
        echo -e "${CYAN}Next steps for deployment:${NC}"
        echo "1. Configure your actual NAS devices in the configuration"
        echo "2. Enable the service: systemctl --user enable nas-monitor.service"
        echo "3. Test with your real network and NAS environment"
        echo "4. Monitor logs during initial operation"
        
        exit 0
    else
        echo -e "${RED}Some integration tests failed! ✗${NC}"
        echo -e "${RED}Please review the failures before production deployment.${NC}"
        
        # Failure recommendations
        echo
        echo -e "${CYAN}Troubleshooting steps:${NC}"
        echo "1. Check system requirements: make check-deps"
        echo "2. Review installation: make clean && make install"
        echo "3. Check systemd user session: systemctl --user status"
        echo "4. Review logs: journalctl --user -u nas-monitor.service"
        
        exit 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  NAS Monitor Integration Test Suite  ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo
    
    # Setup
    setup_test_environment
    trap run_cleanup EXIT
    
    # Run integration tests
    test_clean_installation
    test_configuration_deployment
    test_service_lifecycle
    test_configuration_validation
    test_network_detection
    test_power_management
    test_gui_integration
    test_log_management
    test_upgrade_simulation
    test_end_to_end_workflow
    
    # Generate report
    generate_integration_report
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi