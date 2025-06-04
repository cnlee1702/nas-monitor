# Test Makefile for NAS Monitor
# Provides convenient targets for running different test suites

.PHONY: all unit integration performance manual quick clean help

# Default target
all: unit integration performance

# Individual test suites
unit:
	@echo "Running unit tests..."
	./unit-tests.sh

integration:
	@echo "Running integration tests..."
	./integration-test.sh

performance:
	@echo "Running performance tests..."
	./performance-test.sh

manual:
	@echo "Running manual tests..."
	./manual-test.sh

# Convenience targets
quick:
	@echo "Running quick test suite..."
	./run-tests.sh --quick

verbose:
	@echo "Running all tests with verbose output..."
	./run-tests.sh --verbose

# Test runner with all options
run-all:
	@echo "Running complete test suite..."
	./run-tests.sh all

run-essential:
	@echo "Running essential tests only..."
	./run-tests.sh unit integration

# Cleanup
clean:
	@echo "Cleaning up test artifacts..."
	rm -rf /tmp/nas-monitor-test*
	rm -rf /tmp/nas-monitor-integration*
	rm -rf /tmp/nas-monitor-performance*

# Check test dependencies
check-deps:
	@echo "Checking test dependencies..."
	@command -v bash >/dev/null || echo "Missing: bash"
	@command -v bc >/dev/null || echo "Missing: bc (for performance tests)"
	@command -v shellcheck >/dev/null || echo "Optional: shellcheck (for code quality)"
	@echo "Dependency check complete"

# Make all test scripts executable
setup:
	@echo "Setting up test environment..."
	chmod +x *.sh
	@echo "Test scripts are now executable"

# Help target
help:
	@echo "NAS Monitor Test Makefile"
	@echo "========================="
	@echo ""
	@echo "Test Suites:"
	@echo "  unit          Run unit tests"
	@echo "  integration   Run integration tests"
	@echo "  performance   Run performance tests"
	@echo "  manual        Run manual tests (interactive)"
	@echo ""
	@echo "Convenience:"
	@echo "  all           Run unit, integration, and performance tests"
	@echo "  quick         Run essential tests only"
	@echo "  verbose       Run all tests with verbose output"
	@echo "  run-all       Run complete test suite including manual"
	@echo "  run-essential Run only unit and integration tests"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean         Clean up test artifacts"
	@echo "  check-deps    Check test dependencies"
	@echo "  setup         Make test scripts executable"
	@echo "  help          Show this help message"