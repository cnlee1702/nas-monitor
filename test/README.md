# NAS Monitor Test Suite

This directory contains comprehensive test suites for the NAS Monitor project. The tests are designed to validate functionality, performance, and integration across different systems.

## Test Structure

```
test/
├── README.md                    # This file
├── Makefile                     # Test automation
├── run-tests.sh                 # Master test runner
├── unit-tests.sh                # Unit tests
├── manual-test.sh               # Interactive manual tests
├── integration-test.sh          # End-to-end integration tests
├── performance-test.sh          # Performance and resource tests
└── test-configs/               # Test configuration files
    ├── valid-config.conf
    ├── invalid-config.conf
    └── minimal-config.conf
```

## Quick Start

### Run All Tests
```bash
# Run the complete test suite
./run-tests.sh

# Or use make
make all
```

### Run Specific Test Suites
```bash
# Unit tests only
./run-tests.sh unit
make unit

# Integration tests only
./run-tests.sh integration
make integration

# Performance tests only
./run-tests.sh performance
make performance

# Quick essential tests
./run-tests.sh --quick
make quick
```

## Test Suites

### 1. Unit Tests (`unit-tests.sh`)

**Purpose**: Validate individual components and basic functionality.

**Tests Include**:
- Script syntax validation
- Configuration file parsing
- Network name validation
- NAS device format validation
- Interval value validation
- Power source detection simulation
- GUI compilation
- systemd service file validation
- File permissions
- Dependencies check

**Runtime**: ~30 seconds  
**Requirements**: bash, basic system tools

**Example**:
```bash
./unit-tests.sh
```

### 2. Manual Tests (`manual-test.sh`)

**Purpose**: Interactive testing of features requiring user interaction or real hardware.

**Tests Include**:
- GUI application testing
- Network detection verification
- Power management behavior
- Service integration
- Real NAS connectivity (optional)
- Configuration file handling

**Runtime**: 10-30 minutes (user-dependent)  
**Requirements**: Interactive terminal, GUI display (for GUI tests)

**Example**:
```bash
./manual-test.sh
```

### 3. Integration Tests (`integration-test.sh`)

**Purpose**: End-to-end workflow testing from installation to operation.

**Tests Include**:
- Clean installation workflow
- Configuration deployment
- Service lifecycle management
- Configuration validation in running service
- Network detection functionality
- Power management simulation
- GUI integration
- Log management
- Upgrade simulation
- End-to-end workflow

**Runtime**: ~2-3 minutes  
**Requirements**: systemd user session, write access to ~/.local

**Example**:
```bash
./integration-test.sh
```

### 4. Performance Tests (`performance-test.sh`)

**Purpose**: Resource usage, responsiveness, and scalability testing.

**Tests Include**:
- Baseline resource usage
- Service startup time
- Configuration reload performance
- Memory leak detection
- GUI performance
- Stress testing with multiple configurations

**Runtime**: ~5-10 minutes  
**Requirements**: bc calculator, systemd, monitoring tools

**Example**:
```bash
./performance-test.sh
```

## Test Runner (`run-tests.sh`)

The master test runner orchestrates all test suites and provides comprehensive reporting.

### Options

```bash
./run-tests.sh [OPTIONS] [TEST_SUITES]

OPTIONS:
  -h, --help          Show help message
  -v, --verbose       Enable verbose output
  -q, --quick         Run only essential tests
  -r, --report-only   Generate report from existing results
  --no-cleanup        Skip cleanup after tests
  --parallel          Run compatible tests in parallel (future)

TEST_SUITES:
  unit                Run unit tests
  manual              Run manual tests (interactive)
  integration         Run integration tests
  performance         Run performance tests
  all                 Run all test suites (default)
```

### Examples

```bash
# Run all tests with verbose output
./run-tests.sh --verbose

# Run only unit and integration tests
./run-tests.sh unit integration

# Quick test for CI/CD
./run-tests.sh --quick

# Generate report from previous run
./run-tests.sh --report-only
```

## Test Configuration

Test configurations are stored in `test-configs/` and include:

- **valid-config.conf**: Complete valid configuration
- **invalid-config.conf**: Configuration with errors for validation testing
- **minimal-config.conf**: Minimal working configuration

## Test Results

Test results are stored in `/tmp/nas-monitor-test-results/` and include:

- **test-runner.log**: Master log file
- **test-report-TIMESTAMP.md**: Comprehensive markdown report
- **TESTNAME-output.log**: Individual test outputs
- **project-snapshot/**: Copy of project state during testing

## Continuous Integration

For automated testing environments:

```bash
# Check dependencies first
make -C ../test check-deps

# Run essential tests (no manual interaction)
make -C ../test run-essential

# Or use the test runner
./run-tests.sh --quick unit integration performance
```

## Troubleshooting

### Common Issues

**Tests fail with permission errors**:
```bash
# Ensure scripts are executable
make setup
# Or manually:
chmod +x *.sh
```

**Performance tests fail**:
```bash
# Install bc calculator
sudo apt install bc  # Ubuntu/Debian
sudo dnf install bc  # Fedora
```

**GUI tests fail**:
```bash
# Check GTK development files
pkg-config --exists gtk+-3.0

# Install if missing
sudo apt install libgtk-3-dev  # Ubuntu/Debian
```

**Service tests fail**:
```bash
# Check systemd user session
systemctl --user status

# Start user session if needed
sudo loginctl enable-linger $USER
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Verbose test execution
./run-tests.sh --verbose unit

# Keep test artifacts
./run-tests.sh --no-cleanup unit

# Manual inspection of test logs
tail -f /tmp/nas-monitor-test-results/unit-tests-output.log
```

## Test Development

### Adding New Tests

1. **Unit Tests**: Add test functions to `unit-tests.sh`
2. **Integration Tests**: Add test functions to `integration-test.sh`
3. **Performance Tests**: Add test functions to `performance-test.sh`
4. **Manual Tests**: Add test functions to `manual-test.sh`

### Test Function Template

```bash
test_new_feature() {
    log_test "New feature validation"
    
    # Test setup
    local test_data="test_value"
    
    # Test execution
    if some_command "$test_data"; then
        test_result "pass" "Feature works correctly"
    else
        test_result "fail" "Feature validation failed"
    fi
}
```

### Test Guidelines

- **Idempotent**: Tests should be repeatable without side effects
- **Isolated**: Tests should not depend on other tests
- **Clear Output**: Provide clear pass/fail indicators
- **Cleanup**: Always clean up test artifacts
- **Documentation**: Update this README when adding new tests

## Performance Baselines

Expected performance characteristics:

| Metric | Target | Limit |
|--------|--------|-------|
| CPU Usage (average) | <2% | <5% |
| Memory Usage (average) | <20MB | <50MB |
| Startup Time | <5s | <10s |
| GUI Startup | <3s | <5s |
| Configuration Reload | <3s | <5s |

## Platform Testing

The test suite is designed to work across:

- **Ubuntu 20.04+**
- **Debian 11+**
- **Linux Mint 20+**
- **Fedora 35+**
- **Arch Linux**

Platform-specific considerations are handled automatically where possible.

## Contributing to Tests

When contributing to the project, please:

1. **Run tests** before submitting changes
2. **Add tests** for new functionality
3. **Update tests** when changing existing functionality
4. **Document** any new test requirements

```bash
# Recommended pre-commit testing
make quick
```

## Support

For test-related issues:

1. Check this README
2. Review test logs in `/tmp/nas-monitor-test-results/`
3. Run tests with `--verbose` flag
4. Open an issue with test output and system information