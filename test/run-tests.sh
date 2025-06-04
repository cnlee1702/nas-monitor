#!/bin/bash
# NAS Monitor Test Runner
# Orchestrates all test suites and generates comprehensive reports

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="/tmp/nas-monitor-test-results"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test results tracking
declare -A TEST_RESULTS
declare -A TEST_DURATIONS

# Help function
show_help() {
    cat << EOF
NAS Monitor Test Runner

Usage: $0 [OPTIONS] [TEST_SUITES]

OPTIONS:
  -h, --help          Show this help message
  -v, --verbose       Enable verbose output
  -q, --quick         Run only essential tests
  -r, --report-only   Generate report from existing results
  --no-cleanup        Skip cleanup after tests
  --parallel          Run compatible tests in parallel

TEST_SUITES:
  unit                Run unit tests
  manual              Run manual tests (interactive)
  integration         Run integration tests
  performance         Run performance tests
  all                 Run all test suites (default)

EXAMPLES:
  $0                  # Run all tests
  $0 unit integration # Run only unit and integration tests
  $0 --quick          # Run essential tests only
  $0 --verbose unit   # Run unit tests with verbose output

EOF
}

# Logging functions
log() {
    echo "$(date '+%H:%M:%S') [RUNNER] $*" | tee -a "$TEST_RESULTS_DIR/test-runner.log"
}

log_section() {
    echo -e "${BOLD}${BLUE}$1${NC}"
    log "SECTION: $1"
}

log_test_start() {
    local test_name="$1"
    echo -e "${CYAN}Starting: $test_name${NC}"
    log "TEST_START: $test_name"
}

log_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    
    TEST_RESULTS["$test_name"]="$result"
    TEST_DURATIONS["$test_name"]="$duration"
    
    case "$result" in
        "PASS")
            echo -e "${GREEN}✓ PASS: $test_name (${duration}s)${NC}"
            ;;
        "FAIL")
            echo -e "${RED}✗ FAIL: $test_name (${duration}s)${NC}"
            ;;
        "SKIP")
            echo -e "${YELLOW}⚠ SKIP: $test_name (${duration}s)${NC}"
            ;;
        *)
            echo -e "${YELLOW}? UNKNOWN: $test_name (${duration}s)${NC}"
            ;;
    esac
    
    log "TEST_RESULT: $test_name = $result (${duration}s)"
}

# Setup test environment
setup_test_environment() {
    log_section "Setting up test environment"
    
    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Initialize log file
    echo "NAS Monitor Test Run - $(date)" > "$TEST_RESULTS_DIR/test-runner.log"
    
    # Copy current project state for reference
    log "Copying project state for reference..."
    cp -r "$PROJECT_ROOT" "$TEST_RESULTS_DIR/project-snapshot" 2>/dev/null || true
    
    # Check system requirements
    log "Checking system requirements..."
    local missing_deps=()
    
    # Check required commands
    local required_commands=("bash" "make" "gcc" "systemctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check optional but useful commands
    local optional_commands=("bc" "shellcheck" "jq")
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "WARNING: Optional command '$cmd' not found - some tests may be skipped"
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "ERROR: Missing required dependencies: ${missing_deps[*]}"
        echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
        echo "Please install missing dependencies and try again."
        exit 1
    fi
    
    log "Test environment setup complete"
}

# Run individual test suite
run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    local test_args="${3:-}"
    
    log_test_start "$test_name"
    
    local start_time
    start_time=$(date +%s)
    
    local result="FAIL"
    local output_file="$TEST_RESULTS_DIR/${test_name}-output.log"
    
    if [ -f "$test_script" ] && [ -x "$test_script" ]; then
        # Run the test script
        if [ -n "$test_args" ]; then
            if "$test_script" $test_args > "$output_file" 2>&1; then
                result="PASS"
            fi
        else
            if "$test_script" > "$output_file" 2>&1; then
                result="PASS"
            fi
        fi
    else
        echo "Test script not found or not executable: $test_script" > "$output_file"
        result="SKIP"
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_test_result "$test_name" "$result" "$duration"
    
    # Show output on failure or if verbose
    if [ "$result" = "FAIL" ] || [ "${VERBOSE:-false}" = "true" ]; then
        echo -e "${CYAN}--- Output from $test_name ---${NC}"
        tail -20 "$output_file" || echo "No output available"
        echo -e "${CYAN}--- End output ---${NC}"
    fi
    
    return $([ "$result" = "PASS" ] && echo 0 || echo 1)
}

# Run unit tests
run_unit_tests() {
    log_section "Running Unit Tests"
    run_test_suite "unit-tests" "$SCRIPT_DIR/unit-tests.sh"
}

# Run manual tests (if interactive)
run_manual_tests() {
    log_section "Running Manual Tests"
    
    if [ -t 0 ] && [ -t 1 ]; then
        # Interactive terminal available
        echo -e "${YELLOW}Manual tests require user interaction.${NC}"
        echo -e "${YELLOW}Press Enter to continue or Ctrl+C to skip...${NC}"
        read -r
        
        run_test_suite "manual-tests" "$SCRIPT_DIR/manual-test.sh"
    else
        log "Skipping manual tests - no interactive terminal available"
        log_test_result "manual-tests" "SKIP" "0"
    fi
}

# Run integration tests
run_integration_tests() {
    log_section "Running Integration Tests"
    run_test_suite "integration-tests" "$SCRIPT_DIR/integration-test.sh"
}

# Run performance tests
run_performance_tests() {
    log_section "Running Performance Tests"
    
    # Performance tests require bc calculator
    if command -v bc >/dev/null 2>&1; then
        run_test_suite "performance-tests" "$SCRIPT_DIR/performance-test.sh"
    else
        log "Skipping performance tests - bc calculator not available"
        log_test_result "performance-tests" "SKIP" "0"
    fi
}

# Run quick test suite (essential tests only)
run_quick_tests() {
    log_section "Running Quick Test Suite"
    
    run_unit_tests
    run_integration_tests
}

# Generate comprehensive test report
generate_test_report() {
    log_section "Generating Test Report"
    
    local report_file="$TEST_RESULTS_DIR/test-report-$TIMESTAMP.md"
    
    cat > "$report_file" << EOF
# NAS Monitor Test Report

**Generated:** $(date)  
**Test Run ID:** $TIMESTAMP  
**System:** $(uname -a)  

## Test Summary

EOF
    
    # Count results
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    local total_duration=0
    
    for test_name in "${!TEST_RESULTS[@]}"; do
        ((total_tests++))
        local result="${TEST_RESULTS[$test_name]}"
        local duration="${TEST_DURATIONS[$test_name]}"
        total_duration=$((total_duration + duration))
        
        case "$result" in
            "PASS") ((passed_tests++)) ;;
            "FAIL") ((failed_tests++)) ;;
            "SKIP") ((skipped_tests++)) ;;
        esac
    done
    
    cat >> "$report_file" << EOF
| Metric | Value |
|--------|-------|
| Total Tests | $total_tests |
| Passed | $passed_tests |
| Failed | $failed_tests |
| Skipped | $skipped_tests |
| Total Duration | ${total_duration}s |
| Success Rate | $(( total_tests > 0 ? (passed_tests * 100) / total_tests : 0 ))% |

## Test Results

| Test Suite | Result | Duration | Notes |
|------------|--------|----------|-------|
EOF
    
    # Add individual test results
    for test_name in $(printf '%s\n' "${!TEST_RESULTS[@]}" | sort); do
        local result="${TEST_RESULTS[$test_name]}"
        local duration="${TEST_DURATIONS[$test_name]}"
        local status_icon
        
        case "$result" in
            "PASS") status_icon="✅" ;;
            "FAIL") status_icon="❌" ;;
            "SKIP") status_icon="⚠️" ;;
            *) status_icon="❓" ;;
        esac
        
        echo "| $test_name | $status_icon $result | ${duration}s | See ${test_name}-output.log |" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## System Information

\`\`\`
$(uname -a)
\`\`\`

### Installed Dependencies

\`\`\`
$(command -v gcc && gcc --version | head -1 || echo "gcc: not found")
$(command -v make && make --version | head -1 || echo "make: not found")
$(command -v systemctl && systemctl --version | head -2 || echo "systemctl: not found")
\`\`\`

### GTK Version

\`\`\`
$(pkg-config --modversion gtk+-3.0 2>/dev/null || echo "GTK+3.0: not found")
\`\`\`

## Project Structure

\`\`\`
$(find "$PROJECT_ROOT" -type f -name "*.sh" -o -name "*.c" -o -name "Makefile" | head -20)
\`\`\`

## Failed Test Details

EOF
    
    # Add details for failed tests
    local has_failures=false
    for test_name in "${!TEST_RESULTS[@]}"; do
        if [ "${TEST_RESULTS[$test_name]}" = "FAIL" ]; then
            has_failures=true
            cat >> "$report_file" << EOF

### $test_name

\`\`\`
$(tail -50 "$TEST_RESULTS_DIR/${test_name}-output.log" 2>/dev/null || echo "No output available")
\`\`\`

EOF
        fi
    done
    
    if [ "$has_failures" = "false" ]; then
        echo "No failed tests! 🎉" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Recommendations

EOF
    
    # Add recommendations based on results
    if [ $failed_tests -gt 0 ]; then
        cat >> "$report_file" << EOF
### Issues Found

- $failed_tests test(s) failed
- Review failed test output above
- Check system requirements and dependencies
- Verify installation completed successfully

### Next Steps

1. Address failed test issues
2. Re-run tests after fixes
3. Consider running manual tests if not done
4. Review performance results if available

EOF
    else
        cat >> "$report_file" << EOF
### All Tests Passed! ✅

The NAS Monitor project is ready for deployment:

1. **Installation**: All components install correctly
2. **Configuration**: Configuration system works properly
3. **Service Management**: systemd integration is functional
4. **Performance**: Resource usage is within acceptable limits

### Deployment Checklist

- [ ] Configure actual NAS devices in config file
- [ ] Test with real network environment
- [ ] Enable service: \`systemctl --user enable nas-monitor.service\`
- [ ] Monitor initial operation logs
- [ ] Set up desktop autostart if desired

EOF
    fi
    
    echo "Test report generated: $report_file"
    log "Test report generated: $report_file"
    
    # Also create a summary for console output
    echo -e "\n${BOLD}Test Summary:${NC}"
    echo -e "Total: $total_tests | Passed: ${GREEN}$passed_tests${NC} | Failed: ${RED}$failed_tests${NC} | Skipped: ${YELLOW}$skipped_tests${NC}"
    echo -e "Duration: ${total_duration}s | Success Rate: $(( total_tests > 0 ? (passed_tests * 100) / total_tests : 0 ))%"
}

# Cleanup function
cleanup_tests() {
    if [ "${NO_CLEANUP:-false}" != "true" ]; then
        log "Running cleanup tasks..."
        
        # Stop any running services
        systemctl --user stop nas-monitor.service 2>/dev/null || true
        
        # Clean up temporary files (but preserve test results)
        find /tmp -name "nas-monitor-*" -type d -mtime +1 -exec rm -rf {} \; 2>/dev/null || true
        
        log "Cleanup complete"
    else
        log "Skipping cleanup (--no-cleanup specified)"
    fi
}

# Main execution
main() {
    local test_suites=()
    local quick_mode=false
    local verbose=false
    local report_only=false
    local no_cleanup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                VERBOSE=true
                shift
                ;;
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -r|--report-only)
                report_only=true
                shift
                ;;
            --no-cleanup)
                no_cleanup=true
                NO_CLEANUP=true
                shift
                ;;
            --parallel)
                echo -e "${YELLOW}Parallel execution not yet implemented${NC}"
                shift
                ;;
            unit|manual|integration|performance|all)
                test_suites+=("$1")
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to all tests if none specified
    if [ ${#test_suites[@]} -eq 0 ]; then
        if [ "$quick_mode" = "true" ]; then
            test_suites=("quick")
        else
            test_suites=("all")
        fi
    fi
    
    # Setup
    setup_test_environment
    trap cleanup_tests EXIT
    
    # Print header
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}     NAS Monitor Test Suite Runner     ${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo
    
    if [ "$report_only" = "true" ]; then
        log "Report-only mode - generating report from existing results"
        generate_test_report
        exit 0
    fi
    
    # Run requested test suites
    for suite in "${test_suites[@]}"; do
        case "$suite" in
            "unit")
                run_unit_tests
                ;;
            "manual")
                run_manual_tests
                ;;
            "integration")
                run_integration_tests
                ;;
            "performance")
                run_performance_tests
                ;;
            "quick")
                run_quick_tests
                ;;
            "all")
                run_unit_tests
                run_integration_tests
                run_performance_tests
                run_manual_tests
                ;;
            *)
                log "WARNING: Unknown test suite: $suite"
                ;;
        esac
    done
    
    # Generate final report
    generate_test_report
    
    # Exit with appropriate code
    local exit_code=0
    for result in "${TEST_RESULTS[@]}"; do
        if [ "$result" = "FAIL" ]; then
            exit_code=1
            break
        fi
    done
    
    if [ $exit_code -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}All tests completed successfully! ✅${NC}"
    else
        echo -e "\n${RED}${BOLD}Some tests failed! ❌${NC}"
        echo -e "${YELLOW}Review the test report for details.${NC}"
    fi
    
    exit $exit_code
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi