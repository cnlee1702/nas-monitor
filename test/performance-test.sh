#!/bin/bash
# NAS Monitor Performance Tests
# Tests resource usage, responsiveness, and scalability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_LOG_DIR="/tmp/nas-monitor-performance"
PERFORMANCE_LOG="$TEST_LOG_DIR/performance.log"

# Test parameters
TEST_DURATION=60  # seconds
SAMPLE_INTERVAL=5  # seconds
MAX_MEMORY_MB=50   # Maximum expected memory usage
MAX_CPU_PERCENT=5  # Maximum expected CPU usage

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
declare -A RESULTS

# Setup
setup_performance_tests() {
    echo -e "${BLUE}Setting up performance test environment...${NC}"
    
    mkdir -p "$TEST_LOG_DIR"
    
    # Ensure service is stopped
    systemctl --user stop nas-monitor.service 2>/dev/null || true
    
    # Create performance log
    echo "timestamp,cpu_percent,memory_mb,memory_percent,processes" > "$PERFORMANCE_LOG"
    
    echo -e "${GREEN}Performance test environment ready${NC}"
}

# Performance monitoring
start_monitoring() {
    local service_name="$1"
    local output_file="$2"
    
    # Background monitoring loop
    while systemctl --user is-active "$service_name" >/dev/null 2>&1; do
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Get service PID
        local pid
        pid=$(systemctl --user show --property MainPID --value "$service_name" 2>/dev/null || echo "0")
        
        if [ "$pid" != "0" ] && kill -0 "$pid" 2>/dev/null; then
            # Get CPU and memory usage
            local cpu_percent memory_mb memory_percent processes
            
            # Use ps to get resource usage
            local ps_output
            ps_output=$(ps -p "$pid" -o pid,pcpu,pmem,rss,nlwp --no-headers 2>/dev/null || echo "")
            
            if [ -n "$ps_output" ]; then
                cpu_percent=$(echo "$ps_output" | awk '{print $2}')
                memory_percent=$(echo "$ps_output" | awk '{print $3}')
                memory_mb=$(echo "$ps_output" | awk '{print int($4/1024)}')
                processes=$(echo "$ps_output" | awk '{print $5}')
                
                # Log to CSV
                echo "$timestamp,$cpu_percent,$memory_mb,$memory_percent,$processes" >> "$output_file"
            fi
        fi
        
        sleep "$SAMPLE_INTERVAL"
    done
}

# Test 1: Baseline resource usage
test_baseline_resource_usage() {
    echo -e "${BLUE}Testing baseline resource usage...${NC}"
    
    local baseline_log="$TEST_LOG_DIR/baseline.csv"
    echo "timestamp,cpu_percent,memory_mb,memory_percent,processes" > "$baseline_log"
    
    # Start service
    systemctl --user start nas-monitor.service
    sleep 5  # Let it stabilize
    
    # Monitor for test duration
    start_monitoring "nas-monitor.service" "$baseline_log" &
    local monitor_pid=$!
    
    sleep "$TEST_DURATION"
    
    # Stop monitoring
    kill "$monitor_pid" 2>/dev/null || true
    systemctl --user stop nas-monitor.service
    
    # Analyze results
    if [ -f "$baseline_log" ] && [ "$(wc -l < "$baseline_log")" -gt 1 ]; then
        local avg_cpu avg_memory max_memory
        avg_cpu=$(tail -n +2 "$baseline_log" | awk -F, '{sum+=$2} END {printf "%.2f", sum/NR}')
        avg_memory=$(tail -n +2 "$baseline_log" | awk -F, '{sum+=$3} END {printf "%.1f", sum/NR}')
        max_memory=$(tail -n +2 "$baseline_log" | awk -F, '{if($3>max) max=$3} END {print max}')
        
        RESULTS["baseline_cpu"]="$avg_cpu"
        RESULTS["baseline_memory"]="$avg_memory"
        RESULTS["max_memory"]="$max_memory"
        
        echo -e "${GREEN}✓ Baseline test complete${NC}"
        echo "  Average CPU: ${avg_cpu}%"
        echo "  Average Memory: ${avg_memory}MB"
        echo "  Peak Memory: ${max_memory}MB"
        
        # Check against limits
        if (( $(echo "$avg_cpu < $MAX_CPU_PERCENT" | bc -l) )); then
            echo -e "${GREEN}  CPU usage within limits${NC}"
        else
            echo -e "${RED}  CPU usage exceeds limit (${MAX_CPU_PERCENT}%)${NC}"
        fi
        
        if (( $(echo "$max_memory < $MAX_MEMORY_MB" | bc -l) )); then
            echo -e "${GREEN}  Memory usage within limits${NC}"
        else
            echo -e "${RED}  Memory usage exceeds limit (${MAX_MEMORY_MB}MB)${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to collect baseline data${NC}"
    fi
    
    echo
}

# Test 2: Startup time
test_startup_time() {
    echo -e "${BLUE}Testing service startup time...${NC}"
    
    local startup_times=()
    local iterations=5
    
    for ((i=1; i<=iterations; i++)); do
        echo "  Startup test $i/$iterations..."
        
        local start_time
        start_time=$(date +%s.%N)
        
        # Start service
        if systemctl --user start nas-monitor.service; then
            # Wait for service to become active
            local timeout=30
            local elapsed=0
            
            while ! systemctl --user is-active nas-monitor.service >/dev/null 2>&1; do
                sleep 0.1
                elapsed=$((elapsed + 1))
                
                if [ $elapsed -gt $((timeout * 10)) ]; then
                    echo -e "${RED}  Startup timeout after ${timeout}s${NC}"
                    break
                fi
            done
            
            local end_time
            end_time=$(date +%s.%N)
            local startup_time
            startup_time=$(echo "$end_time - $start_time" | bc -l)
            
            startup_times+=("$startup_time")
            echo "    Startup time: ${startup_time}s"
            
            # Stop service for next iteration
            systemctl --user stop nas-monitor.service
            sleep 1
        else
            echo -e "${RED}  Failed to start service${NC}"
        fi
    done
    
    # Calculate statistics
    if [ ${#startup_times[@]} -gt 0 ]; then
        local total=0
        local min_time=${startup_times[0]}
        local max_time=${startup_times[0]}
        
        for time in "${startup_times[@]}"; do
            total=$(echo "$total + $time" | bc -l)
            if (( $(echo "$time < $min_time" | bc -l) )); then
                min_time=$time
            fi
            if (( $(echo "$time > $max_time" | bc -l) )); then
                max_time=$time
            fi
        done
        
        local avg_time
        avg_time=$(echo "scale=3; $total / ${#startup_times[@]}" | bc -l)
        
        RESULTS["startup_avg"]="$avg_time"
        RESULTS["startup_min"]="$min_time"
        RESULTS["startup_max"]="$max_time"
        
        echo -e "${GREEN}✓ Startup time test complete${NC}"
        echo "  Average: ${avg_time}s"
        echo "  Min: ${min_time}s"
        echo "  Max: ${max_time}s"
        
        # Check if startup is reasonable (under 10 seconds)
        if (( $(echo "$avg_time < 10.0" | bc -l) )); then
            echo -e "${GREEN}  Startup time acceptable${NC}"
        else
            echo -e "${YELLOW}  Startup time might be slow${NC}"
        fi
    else
        echo -e "${RED}✗ No successful startups recorded${NC}"
    fi
    
    echo
}

# Test 3: Configuration reload performance
test_config_reload_performance() {
    echo -e "${BLUE}Testing configuration reload performance...${NC}"
    
    local config_file="$HOME/.config/nas-monitor/config.conf"
    local reload_times=()
    local iterations=3
    
    # Start service
    systemctl --user start nas-monitor.service
    sleep 5  # Let it stabilize
    
    for ((i=1; i<=iterations; i++)); do
        echo "  Reload test $i/$iterations..."
        
        # Modify configuration (add comment to trigger reload)
        echo "# Reload test $i at $(date)" >> "$config_file"
        
        local start_time
        start_time=$(date +%s.%N)
        
        # Restart service (simulates configuration reload)
        if systemctl --user restart nas-monitor.service; then
            # Wait for service to become active again
            local timeout=15
            local elapsed=0
            
            while ! systemctl --user is-active nas-monitor.service >/dev/null 2>&1; do
                sleep 0.1
                elapsed=$((elapsed + 1))
                
                if [ $elapsed -gt $((timeout * 10)) ]; then
                    echo -e "${RED}  Reload timeout after ${timeout}s${NC}"
                    break
                fi
            done
            
            local end_time
            end_time=$(date +%s.%N)
            local reload_time
            reload_time=$(echo "$end_time - $start_time" | bc -l)
            
            reload_times+=("$reload_time")
            echo "    Reload time: ${reload_time}s"
            
            sleep 2  # Brief pause between tests
        else
            echo -e "${RED}  Failed to restart service${NC}"
        fi
    done
    
    # Stop service
    systemctl --user stop nas-monitor.service
    
    # Calculate statistics
    if [ ${#reload_times[@]} -gt 0 ]; then
        local total=0
        for time in "${reload_times[@]}"; do
            total=$(echo "$total + $time" | bc -l)
        done
        
        local avg_time
        avg_time=$(echo "scale=3; $total / ${#reload_times[@]}" | bc -l)
        
        RESULTS["reload_avg"]="$avg_time"
        
        echo -e "${GREEN}✓ Configuration reload test complete${NC}"
        echo "  Average reload time: ${avg_time}s"
    else
        echo -e "${RED}✗ No successful reloads recorded${NC}"
    fi
    
    echo
}

# Test 4: Memory leak detection
test_memory_leak_detection() {
    echo -e "${BLUE}Testing for memory leaks...${NC}"
    
    local leak_log="$TEST_LOG_DIR/memory_leak.csv"
    echo "timestamp,memory_mb" > "$leak_log"
    
    # Start service
    systemctl --user start nas-monitor.service
    sleep 10  # Initial stabilization
    
    # Record initial memory
    local pid
    pid=$(systemctl --user show --property MainPID --value nas-monitor.service)
    
    if [ "$pid" != "0" ] && kill -0 "$pid" 2>/dev/null; then
        # Monitor memory for extended period
        local test_duration=120  # 2 minutes for leak detection
        local sample_count=$((test_duration / SAMPLE_INTERVAL))
        
        echo "  Monitoring memory usage for ${test_duration}s..."
        
        for ((i=1; i<=sample_count; i++)); do
            if kill -0 "$pid" 2>/dev/null; then
                local memory_mb
                memory_mb=$(ps -p "$pid" -o rss --no-headers 2>/dev/null | awk '{print int($1/1024)}')
                
                echo "$(date '+%Y-%m-%d %H:%M:%S'),$memory_mb" >> "$leak_log"
                echo -n "."
            else
                echo -e "\n${RED}  Process died during test${NC}"
                break
            fi
            
            sleep "$SAMPLE_INTERVAL"
        done
        echo
        
        # Analyze memory trend
        if [ -f "$leak_log" ] && [ "$(wc -l < "$leak_log")" -gt 10 ]; then
            local initial_memory final_memory memory_growth
            initial_memory=$(head -2 "$leak_log" | tail -1 | cut -d',' -f2)
            final_memory=$(tail -1 "$leak_log" | cut -d',' -f2)
            memory_growth=$((final_memory - initial_memory))
            
            RESULTS["memory_growth"]="$memory_growth"
            RESULTS["initial_memory"]="$initial_memory"
            RESULTS["final_memory"]="$final_memory"
            
            echo -e "${GREEN}✓ Memory leak test complete${NC}"
            echo "  Initial memory: ${initial_memory}MB"
            echo "  Final memory: ${final_memory}MB"
            echo "  Memory growth: ${memory_growth}MB"
            
            # Check for significant memory growth (>10MB over 2 minutes indicates potential leak)
            if [ "$memory_growth" -lt 10 ]; then
                echo -e "${GREEN}  No significant memory growth detected${NC}"
            else
                echo -e "${YELLOW}  Possible memory growth detected${NC}"
            fi
        else
            echo -e "${RED}✗ Insufficient data for memory leak analysis${NC}"
        fi
    else
        echo -e "${RED}✗ Could not find service process${NC}"
    fi
    
    systemctl --user stop nas-monitor.service
    echo
}

# Test 5: GUI performance
test_gui_performance() {
    echo -e "${BLUE}Testing GUI performance...${NC}"
    
    local gui_binary="$HOME/.local/bin/nas-config-gui"
    
    if [ -f "$gui_binary" ] && [ -x "$gui_binary" ]; then
        # Test GUI startup time
        local gui_startup_times=()
        local iterations=3
        
        for ((i=1; i<=iterations; i++)); do
            echo "  GUI startup test $i/$iterations..."
            
            local start_time
            start_time=$(date +%s.%N)
            
            # Start GUI in background and immediately terminate
            # This tests startup time without requiring display
            timeout 3 "$gui_binary" >/dev/null 2>&1 &
            local gui_pid=$!
            
            # Wait a moment for startup
            sleep 0.5
            
            # Kill the GUI
            kill "$gui_pid" 2>/dev/null || true
            wait "$gui_pid" 2>/dev/null || true
            
            local end_time
            end_time=$(date +%s.%N)
            local startup_time
            startup_time=$(echo "$end_time - $start_time" | bc -l)
            
            gui_startup_times+=("$startup_time")
            echo "    GUI startup time: ${startup_time}s"
        done
        
        # Calculate average
        if [ ${#gui_startup_times[@]} -gt 0 ]; then
            local total=0
            for time in "${gui_startup_times[@]}"; do
                total=$(echo "$total + $time" | bc -l)
            done
            
            local avg_time
            avg_time=$(echo "scale=3; $total / ${#gui_startup_times[@]}" | bc -l)
            
            RESULTS["gui_startup_avg"]="$avg_time"
            
            echo -e "${GREEN}✓ GUI performance test complete${NC}"
            echo "  Average GUI startup: ${avg_time}s"
            
            # Check if GUI startup is reasonable (under 5 seconds)
            if (( $(echo "$avg_time < 5.0" | bc -l) )); then
                echo -e "${GREEN}  GUI startup time acceptable${NC}"
            else
                echo -e "${YELLOW}  GUI startup might be slow${NC}"
            fi
        else
            echo -e "${RED}✗ No successful GUI startups recorded${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ GUI binary not found, skipping GUI performance test${NC}"
    fi
    
    echo
}

# Test 6: Stress test with multiple configurations
test_stress_configuration() {
    echo -e "${BLUE}Testing with stress configuration...${NC}"
    
    local stress_config="$TEST_LOG_DIR/stress-config.conf"
    local original_config="$HOME/.config/nas-monitor/config.conf"
    local backup_config="$original_config.perf-backup"
    
    # Backup original configuration
    if [ -f "$original_config" ]; then
        cp "$original_config" "$backup_config"
    fi
    
    # Create stress configuration with many NAS devices
    cat > "$stress_config" << 'EOF'
[networks]
home_networks=StressTest-WiFi1,StressTest-WiFi2,StressTest-WiFi3,StressTest-5G1,StressTest-5G2

[nas_devices]
nas1.local/share1
nas2.local/share2
nas3.local/share3
nas4.local/share4
nas5.local/share5
nas6.local/share6
nas7.local/share7
nas8.local/share8
nas9.local/share9
nas10.local/share10

[intervals]
home_ac_interval=2
home_battery_interval=4
away_ac_interval=6
away_battery_interval=8

[behavior]
max_failed_attempts=5
min_battery_level=5
enable_notifications=false
EOF
    
    # Deploy stress configuration
    mkdir -p "$(dirname "$original_config")"
    cp "$stress_config" "$original_config"
    
    local stress_log="$TEST_LOG_DIR/stress.csv"
    echo "timestamp,cpu_percent,memory_mb,memory_percent,processes" > "$stress_log"
    
    # Start service with stress configuration
    echo "  Starting service with stress configuration..."
    if systemctl --user start nas-monitor.service; then
        sleep 5  # Stabilization
        
        # Monitor under stress for shorter duration
        start_monitoring "nas-monitor.service" "$stress_log" &
        local monitor_pid=$!
        
        local stress_duration=30
        echo "  Running stress test for ${stress_duration}s..."
        sleep "$stress_duration"
        
        # Stop monitoring
        kill "$monitor_pid" 2>/dev/null || true
        
        # Analyze stress results
        if [ -f "$stress_log" ] && [ "$(wc -l < "$stress_log")" -gt 1 ]; then
            local stress_cpu stress_memory
            stress_cpu=$(tail -n +2 "$stress_log" | awk -F, '{sum+=$2} END {printf "%.2f", sum/NR}')
            stress_memory=$(tail -n +2 "$stress_log" | awk -F, '{sum+=$3} END {printf "%.1f", sum/NR}')
            
            RESULTS["stress_cpu"]="$stress_cpu"
            RESULTS["stress_memory"]="$stress_memory"
            
            echo -e "${GREEN}✓ Stress test complete${NC}"
            echo "  Stress CPU: ${stress_cpu}%"
            echo "  Stress Memory: ${stress_memory}MB"
            
            # Compare with baseline
            if [ -n "${RESULTS[baseline_cpu]:-}" ]; then
                local cpu_increase
                cpu_increase=$(echo "$stress_cpu - ${RESULTS[baseline_cpu]}" | bc -l)
                echo "  CPU increase: ${cpu_increase}%"
                
                if (( $(echo "$cpu_increase < 2.0" | bc -l) )); then
                    echo -e "${GREEN}  CPU scaling acceptable${NC}"
                else
                    echo -e "${YELLOW}  High CPU increase under stress${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ Failed to collect stress test data${NC}"
        fi
        
        systemctl --user stop nas-monitor.service
    else
        echo -e "${RED}✗ Failed to start service with stress configuration${NC}"
    fi
    
    # Restore original configuration
    if [ -f "$backup_config" ]; then
        mv "$backup_config" "$original_config"
    else
        rm -f "$original_config"
    fi
    
    echo
}

# Generate performance report
generate_performance_report() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}      Performance Test Results         ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    # Resource Usage Summary
    echo -e "${CYAN}Resource Usage:${NC}"
    if [ -n "${RESULTS[baseline_cpu]:-}" ]; then
        echo "  Average CPU Usage: ${RESULTS[baseline_cpu]}%"
    fi
    if [ -n "${RESULTS[baseline_memory]:-}" ]; then
        echo "  Average Memory Usage: ${RESULTS[baseline_memory]}MB"
    fi
    if [ -n "${RESULTS[max_memory]:-}" ]; then
        echo "  Peak Memory Usage: ${RESULTS[max_memory]}MB"
    fi
    echo
    
    # Startup Performance
    echo -e "${CYAN}Startup Performance:${NC}"
    if [ -n "${RESULTS[startup_avg]:-}" ]; then
        echo "  Average Startup Time: ${RESULTS[startup_avg]}s"
        echo "  Min Startup Time: ${RESULTS[startup_min]}s"
        echo "  Max Startup Time: ${RESULTS[startup_max]}s"
    fi
    if [ -n "${RESULTS[reload_avg]:-}" ]; then
        echo "  Average Reload Time: ${RESULTS[reload_avg]}s"
    fi
    if [ -n "${RESULTS[gui_startup_avg]:-}" ]; then
        echo "  Average GUI Startup: ${RESULTS[gui_startup_avg]}s"
    fi
    echo
    
    # Memory Analysis
    echo -e "${CYAN}Memory Analysis:${NC}"
    if [ -n "${RESULTS[memory_growth]:-}" ]; then
        echo "  Memory Growth (2min): ${RESULTS[memory_growth]}MB"
        echo "  Initial Memory: ${RESULTS[initial_memory]}MB"
        echo "  Final Memory: ${RESULTS[final_memory]}MB"
    fi
    echo
    
    # Stress Test Results
    echo -e "${CYAN}Stress Test Results:${NC}"
    if [ -n "${RESULTS[stress_cpu]:-}" ]; then
        echo "  Stress CPU Usage: ${RESULTS[stress_cpu]}%"
        echo "  Stress Memory Usage: ${RESULTS[stress_memory]}MB"
    fi
    echo
    
    # Performance Assessment
    echo -e "${CYAN}Performance Assessment:${NC}"
    
    local issues=0
    
    # Check CPU usage
    if [ -n "${RESULTS[baseline_cpu]:-}" ] && (( $(echo "${RESULTS[baseline_cpu]} > $MAX_CPU_PERCENT" | bc -l) )); then
        echo -e "${RED}  ✗ High CPU usage detected${NC}"
        ((issues++))
    else
        echo -e "${GREEN}  ✓ CPU usage acceptable${NC}"
    fi
    
    # Check memory usage
    if [ -n "${RESULTS[max_memory]:-}" ] && (( $(echo "${RESULTS[max_memory]} > $MAX_MEMORY_MB" | bc -l) )); then
        echo -e "${RED}  ✗ High memory usage detected${NC}"
        ((issues++))
    else
        echo -e "${GREEN}  ✓ Memory usage acceptable${NC}"
    fi
    
    # Check startup time
    if [ -n "${RESULTS[startup_avg]:-}" ] && (( $(echo "${RESULTS[startup_avg]} > 10.0" | bc -l) )); then
        echo -e "${YELLOW}  ⚠ Slow startup time${NC}"
    else
        echo -e "${GREEN}  ✓ Startup time acceptable${NC}"
    fi
    
    # Check memory growth
    if [ -n "${RESULTS[memory_growth]:-}" ] && [ "${RESULTS[memory_growth]}" -gt 10 ]; then
        echo -e "${YELLOW}  ⚠ Possible memory growth detected${NC}"
    else
        echo -e "${GREEN}  ✓ No significant memory growth${NC}"
    fi
    
    echo
    
    # Overall assessment
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}✓ Overall Performance: EXCELLENT${NC}"
        echo -e "${GREEN}NAS Monitor meets all performance criteria.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ Overall Performance: ACCEPTABLE WITH ISSUES${NC}"
        echo -e "${YELLOW}$issues performance issue(s) detected. Review recommended.${NC}"
        exit 1
    fi
}

# Cleanup
cleanup_performance_tests() {
    echo -e "${BLUE}Cleaning up performance test environment...${NC}"
    
    # Stop service
    systemctl --user stop nas-monitor.service 2>/dev/null || true
    
    # Clean up test files
    # Keep logs for analysis
    echo "Performance logs saved in: $TEST_LOG_DIR"
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  NAS Monitor Performance Test Suite   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo

    # Check if NAS Monitor is installed
    if ! systemctl --user list-unit-files nas-monitor.service >/dev/null 2>&1; then
        echo -e "${YELLOW}NAS Monitor not installed - skipping performance tests${NC}"
        echo "Install first with: make install"
        exit 0
    fi
    
    # Check for required tools
    if ! command -v bc >/dev/null 2>&1; then
        echo -e "${RED}Error: bc calculator required for performance tests${NC}"
        echo "Install with: sudo apt install bc"
        exit 1
    fi
    
    # Setup
    setup_performance_tests
    trap cleanup_performance_tests EXIT
    
    # Run performance tests
    test_baseline_resource_usage
    test_startup_time
    test_config_reload_performance
    test_memory_leak_detection
    test_gui_performance
    test_stress_configuration
    
    # Generate report
    generate_performance_report
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi