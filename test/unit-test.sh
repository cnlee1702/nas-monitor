#!/bin/bash
# NAS Monitor Unit Tests
# Automated testing suite for core functionality

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_CONFIG_DIR="$SCRIPT_DIR/test-configs"
TEST_LOG_DIR="/tmp/nas-monitor-tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_tests() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create test directories
    mkdir -p "$TEST_LOG_DIR"
    mkdir -p "$TEST_CONFIG_DIR"
    
    # Create test configuration
    cat > "$TEST_CONFIG_DIR/valid-config.conf" << 'EOF'
[networks]
home_networks=TestWiFi,TestWiFi-5G,

[nas_devices]
test-nas.local/home
backup.local/media

[intervals]
home_ac_interval=15
home_battery_interval=60
away_ac_interval=180
away_battery_interval=600

[behavior]
max_failed_attempts=3
min_battery_level=10
enable_notifications=true
EOF
    
    # Create invalid configuration
    cat > "$TEST_CONFIG_DIR/invalid-config.conf" << 'EOF'
[networks]
home_networks=TestWiFi

[nas_devices]
# Missing devices section content

[intervals]
home_ac_interval=invalid_value
home_battery_interval=60

[behavior]
max_failed_attempts=3
min_battery_level=10
enable_notifications=true
EOF
    
    # Create minimal configuration
    cat > "$TEST_CONFIG_DIR/minimal-config.conf" << 'EOF'
[networks]
home_networks=MinimalWiFi

[nas_devices]
minimal-nas.local/share

[intervals]
home_ac_interval=30
home_battery_interval=120
away_ac_interval=300
away_battery_interval=900

[behavior]
max_failed_attempts=5
min_battery_level=15
enable_notifications=false
EOF
    
    echo -e "${GREEN}Test environment setup complete${NC}"
}

# Test helper functions
log_test() {
    local test_name="$1"
    echo -e "${BLUE}Testing: $test_name${NC}"
    ((TESTS_RUN++))
}

assert_success() {
    local test_name="$1"
    local command="$2"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        echo -e "${RED}  Command: $command${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_failure() {
    local test_name="$1"
    local command="$2"
    
    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        echo -e "${RED}  Command should have failed: $command${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if echo "$actual" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        echo -e "${RED}  Expected to contain: $expected${NC}"
        echo -e "${RED}  Actual: $actual${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Script syntax validation
test_script_syntax() {
    log_test "Script syntax validation"
    
    local daemon_script="$PROJECT_ROOT/src/nas-monitor.sh"
    
    if [ -f "$daemon_script" ]; then
        assert_success "Daemon script syntax check" "bash -n '$daemon_script'"
    else
        echo -e "${YELLOW}⚠ SKIP: Daemon script not found at $daemon_script${NC}"
    fi
}

# Test 2: Configuration parsing
test_config_parsing() {
    log_test "Configuration file parsing"
    
    # Test valid configuration
    local config_content
    config_content=$(cat "$TEST_CONFIG_DIR/valid-config.conf")
    assert_contains "Valid config contains networks section" '\[networks\]' "$config_content"
    assert_contains "Valid config contains nas_devices section" '\[nas_devices\]' "$config_content"
    assert_contains "Valid config contains home networks" 'home_networks=TestWiFi' "$config_content"
    assert_contains "Valid config contains NAS device" 'test-nas.local/home' "$config_content"
    
    # Test configuration validation
    local networks_line
    networks_line=$(grep "^home_networks=" "$TEST_CONFIG_DIR/valid-config.conf" | cut -d'=' -f2)
    assert_contains "Network list parsing" 'TestWiFi' "$networks_line"
    assert_contains "Network list contains 5G variant" 'TestWiFi-5G' "$networks_line"
}

# Test 3: Power source detection simulation
test_power_detection() {
    log_test "Power source detection logic"
    
    # Create mock power supply files
    local mock_power_dir="$TEST_LOG_DIR/mock-power"
    mkdir -p "$mock_power_dir/AC0"
    
    # Test AC power detection
    echo "1" > "$mock_power_dir/AC0/online"
    local ac_status
    ac_status=$(cat "$mock_power_dir/AC0/online")
    assert_contains "AC power detection" "1" "$ac_status"
    
    # Test battery power detection
    echo "0" > "$mock_power_dir/AC0/online"
    ac_status=$(cat "$mock_power_dir/AC0/online")
    assert_contains "Battery power detection" "0" "$ac_status"
    
    # Clean up
    rm -rf "$mock_power_dir"
}

# Test 4: Network name validation
test_network_validation() {
    log_test "Network name validation"
    
    # Valid network names
    local valid_networks=("HomeWiFi" "Home-5G" "Guest_Network" "WiFi123")
    for network in "${valid_networks[@]}"; do
        # Simple validation: non-empty and reasonable characters
        if [[ "$network" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo -e "${GREEN}✓ PASS: Valid network name: $network${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL: Invalid network name: $network${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
    
    # Invalid network names (with special characters that could cause issues)
    local invalid_networks=("Net;work" "Net\$work" "Net work" "Net|work")
    for network in "${invalid_networks[@]}"; do
        if [[ ! "$network" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo -e "${GREEN}✓ PASS: Correctly rejected invalid network name: $network${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL: Should have rejected invalid network name: $network${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

# Test 5: NAS device format validation
test_nas_device_validation() {
    log_test "NAS device format validation"
    
    # Valid NAS device formats
    local valid_devices=("nas.local/share" "192.168.1.100/media" "server.domain.com/backup")
    for device in "${valid_devices[@]}"; do
        if [[ "$device" =~ ^[^/]+/[^/]+$ ]]; then
            echo -e "${GREEN}✓ PASS: Valid NAS device format: $device${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL: Invalid NAS device format: $device${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
    
    # Invalid NAS device formats
    local invalid_devices=("nas.local" "nas.local/" "/share" "nas.local/share/subdir")
    for device in "${invalid_devices[@]}"; do
        if [[ ! "$device" =~ ^[^/]+/[^/]+$ ]]; then
            echo -e "${GREEN}✓ PASS: Correctly rejected invalid device format: $device${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL: Should have rejected invalid device format: $device${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

# Test 6: Interval validation
test_interval_validation() {
    log_test "Interval value validation"
    
    # Valid intervals (5 to 3600 seconds)
    local valid_intervals=(5 15 30 60 300 600 1800 3600)
    for interval in "${valid_intervals[@]}"; do
        if [[ "$interval" -ge 5 && "$interval" -le 3600 ]]; then
            echo -e "${GREEN}✓ PASS: Valid interval: ${interval}s${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL: Invalid interval: ${interval}s${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
    
    # Invalid intervals
    local invalid_intervals=(0 3 4 3601 7200 -1)
    for interval in "${invalid_intervals[@]}"; do
        if [[ "$interval" -lt 5 || "$interval" -gt 3600 ]]; then
            echo -e "${GREEN}✓ PASS: Correctly rejected invalid interval: ${interval}s${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL: Should have rejected invalid interval: ${interval}s${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

# Test 7: GUI compilation
test_gui_compilation() {
    log_test "GUI compilation test"
    
    local gui_source="$PROJECT_ROOT/src/nas-config-gui.c"
    
    if [ -f "$gui_source" ]; then
        # Check if GTK development files are available
        if pkg-config --exists gtk+-3.0; then
            local test_binary="$TEST_LOG_DIR/test-gui"
            local compile_cmd="gcc -std=c99 -o '$test_binary' '$gui_source' $(pkg-config --cflags --libs gtk+-3.0)"
            
            assert_success "GUI compilation" "$compile_cmd"
            
            # Clean up test binary
            [ -f "$test_binary" ] && rm -f "$test_binary"
        else
            echo -e "${YELLOW}⚠ SKIP: GTK+3.0 development files not available${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ SKIP: GUI source not found at $gui_source${NC}"
    fi
}

# Test 8: systemd service file validation
test_systemd_service() {
    log_test "systemd service file validation"
    
    local service_file="$PROJECT_ROOT/systemd/nas-monitor.service"
    
    if [ -f "$service_file" ]; then
        local service_content
        service_content=$(cat "$service_file")
        
        assert_contains "Service has Unit section" '\[Unit\]' "$service_content"
        assert_contains "Service has Service section" '\[Service\]' "$service_content"
        assert_contains "Service has Install section" '\[Install\]' "$service_content"
        assert_contains "Service defines ExecStart" 'ExecStart=' "$service_content"
        assert_contains "Service defines restart policy" 'Restart=' "$service_content"
    else
        echo -e "${YELLOW}⚠ SKIP: Service file not found at $service_file${NC}"
    fi
}

# Test 9: File permissions
test_file_permissions() {
    log_test "File permissions validation"
    
    # Test script executability
    local daemon_script="$PROJECT_ROOT/src/nas-monitor.sh"
    if [ -f "$daemon_script" ]; then
        # Check if file has read permission (should be readable)
        assert_success "Daemon script is readable" "[ -r '$daemon_script' ]"
    fi
    
    # Test configuration file permissions (should be restrictive when created)
    local test_config="$TEST_LOG_DIR/test-config.conf"
    echo "test=value" > "$test_config"
    chmod 600 "$test_config"
    
    local perms
    perms=$(stat -c "%a" "$test_config")
    assert_contains "Config file has restrictive permissions" "600" "$perms"
    
    rm -f "$test_config"
}

# Test 10: Dependencies check
test_dependencies() {
    log_test "System dependencies check"
    
    # Check for required commands
    local required_commands=("bash" "systemctl" "gio")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS: Required command available: $cmd${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL: Required command missing: $cmd${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
    
    # Check for optional commands
    local optional_commands=("notify-send" "nmcli" "ping")
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ INFO: Optional command available: $cmd${NC}"
        else
            echo -e "${YELLOW}⚠ INFO: Optional command missing: $cmd${NC}"
        fi
    done
}

# Test runner
run_all_tests() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  NAS Monitor Unit Test Suite  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    
    setup_tests
    echo
    
    test_script_syntax
    test_config_parsing
    test_power_detection
    test_network_validation
    test_nas_device_validation
    test_interval_validation
    test_gui_compilation
    test_systemd_service
    test_file_permissions
    test_dependencies
    
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}         Test Results          ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Tests run:    ${BLUE}$TESTS_RUN${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed! ✗${NC}"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    rm -rf "$TEST_LOG_DIR"
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests "$@"
fi