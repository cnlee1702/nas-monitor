# NAS Monitor - Makefile
# Power-aware NAS monitoring for Linux laptops

# Project information
PROJECT = nas-monitor
VERSION = 1.0.0
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share
CONFIGDIR = $(HOME)/.config
SYSTEMDDIR = $(CONFIGDIR)/systemd/user

# Build configuration
BUILD_DIR = build
CC = gcc
CFLAGS = -std=c99 -Wall -Wextra -O2 -DVERSION=\"$(VERSION)\"
DEBUG_CFLAGS = -std=c99 -Wall -Wextra -g -DDEBUG -DVERSION=\"$(VERSION)\"
GTK_FLAGS = $(shell pkg-config --cflags --libs gtk+-3.0)

# Source files
GUI_SOURCE = src/nas-config-gui.c
DAEMON_SOURCE = src/nas-monitor.sh
SERVICE_FILE = systemd/nas-monitor.service
CONFIG_EXAMPLE = config/config.conf.example

# Target binaries
GUI_TARGET = nas-config-gui
DAEMON_TARGET = nas-monitor.sh

# Default target
.PHONY: all
all: $(BUILD_DIR)/$(GUI_TARGET) check-daemon

# Build the GUI application
$(BUILD_DIR)/$(GUI_TARGET): $(GUI_SOURCE)
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $(BUILD_DIR)/$(GUI_TARGET) $(GUI_SOURCE) $(GTK_FLAGS)

# Check daemon script syntax
.PHONY: check-daemon
check-daemon: $(DAEMON_SOURCE)
	@echo "Checking daemon script syntax..."
	@bash -n $(DAEMON_SOURCE) && echo "✓ Daemon script syntax OK"

# Debug build
.PHONY: debug
debug: CFLAGS = $(DEBUG_CFLAGS)
debug: $(BUILD_DIR)/$(GUI_TARGET)

# Static build for portability
.PHONY: static
static: CFLAGS += -static
static: $(BUILD_DIR)/$(GUI_TARGET)

# Install everything
.PHONY: install
install: install-daemon install-gui install-service install-config

# Install daemon script
.PHONY: install-daemon
install-daemon: $(DAEMON_SOURCE)
	@echo "Installing daemon..."
	mkdir -p $(BINDIR)
	cp $(DAEMON_SOURCE) $(BINDIR)/$(DAEMON_TARGET)
	chmod +x $(BINDIR)/$(DAEMON_TARGET)

# Install GUI application
.PHONY: install-gui
install-gui: $(BUILD_DIR)/$(GUI_TARGET)
	@echo "Installing GUI..."
	mkdir -p $(BINDIR)
	cp $(BUILD_DIR)/$(GUI_TARGET) $(BINDIR)/$(GUI_TARGET)
	chmod +x $(BINDIR)/$(GUI_TARGET)

# Install systemd service
.PHONY: install-service
install-service: $(SERVICE_FILE)
	@echo "Installing systemd service..."
	mkdir -p $(SYSTEMDDIR)
	sed 's|%h|$(HOME)|g' $(SERVICE_FILE) > $(SYSTEMDDIR)/nas-monitor.service
	systemctl --user daemon-reload

# Install configuration example
.PHONY: install-config
install-config: $(CONFIG_EXAMPLE)
	@echo "Installing configuration example..."
	mkdir -p $(CONFIGDIR)/nas-monitor
	if [ ! -f $(CONFIGDIR)/nas-monitor/config.conf ]; then \
		cp $(CONFIG_EXAMPLE) $(CONFIGDIR)/nas-monitor/config.conf; \
		chmod 600 $(CONFIGDIR)/nas-monitor/config.conf; \
		echo "Created default configuration at $(CONFIGDIR)/nas-monitor/config.conf"; \
	else \
		echo "Configuration already exists, skipping..."; \
	fi

# Create desktop entry
.PHONY: desktop-entry
desktop-entry: install-gui
	@echo "Creating desktop entry..."
	mkdir -p $(SHAREDIR)/applications
	echo "[Desktop Entry]" > $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Name=NAS Monitor Config" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Comment=Configure NAS Monitor Settings" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Exec=$(BINDIR)/nas-config-gui" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Icon=network-server" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Terminal=false" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Type=Application" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Categories=Settings;Network;System;" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	echo "Keywords=NAS;SMB;CIFS;Network;Storage;" >> $(SHAREDIR)/applications/nas-config-gui.desktop
	chmod +x $(SHAREDIR)/applications/nas-config-gui.desktop

# Enable and start service
.PHONY: enable-service
enable-service: install-service
	@echo "Enabling and starting service..."
	systemctl --user enable nas-monitor.service
	systemctl --user start nas-monitor.service
	@echo "Service status:"
	systemctl --user status nas-monitor.service --no-pager

# Development targets
.PHONY: dev-install
dev-install: debug install desktop-entry
	@echo "Development installation complete"

# Testing
.PHONY: test
test: test-syntax test-gui

.PHONY: test-syntax
test-syntax:
	@echo "Testing shell script syntax..."
	@bash -n $(DAEMON_SOURCE) && echo "✓ Daemon syntax OK"
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "Running shellcheck..."; \
		shellcheck $(DAEMON_SOURCE) && echo "✓ shellcheck passed"; \
	else \
		echo "⚠ shellcheck not available, skipping..."; \
	fi

.PHONY: test-gui
test-gui: $(BUILD_DIR)/$(GUI_TARGET)
	@echo "Testing GUI compilation..."
	@echo "✓ GUI compiles successfully"

# Linting and code quality
.PHONY: lint
lint:
	@echo "Running code quality checks..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "Checking shell scripts..."; \
		shellcheck $(DAEMON_SOURCE); \
	fi
	@if command -v cppcheck >/dev/null 2>&1; then \
		echo "Checking C code..."; \
		cppcheck --enable=all --std=c99 $(GUI_SOURCE); \
	fi

# Documentation generation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	@if command -v pandoc >/dev/null 2>&1; then \
		mkdir -p docs/html; \
		pandoc README.md -o docs/html/index.html; \
		pandoc CONTRIBUTING.md -o docs/html/contributing.html; \
		echo "✓ HTML documentation generated in docs/html/"; \
	else \
		echo "⚠ pandoc not available, skipping HTML generation"; \
	fi

# Clean build artifacts
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	rm -rf docs/html

# Uninstall everything
.PHONY: uninstall
uninstall:
	@echo "Uninstalling NAS Monitor..."
	systemctl --user stop nas-monitor.service 2>/dev/null || true
	systemctl --user disable nas-monitor.service 2>/dev/null || true
	rm -f $(BINDIR)/$(GUI_TARGET)
	rm -f $(BINDIR)/$(DAEMON_TARGET)
	rm -f $(SYSTEMDDIR)/nas-monitor.service
	rm -f $(SHAREDIR)/applications/nas-config-gui.desktop
	systemctl --user daemon-reload
	@echo "Uninstall complete. Configuration files preserved."

# Package creation
.PHONY: package
package: clean
	@echo "Creating source package..."
	mkdir -p dist
	tar -czf dist/$(PROJECT)-$(VERSION).tar.gz \
		--exclude='.git*' \
		--exclude='dist' \
		--exclude='build' \
		--exclude='*.o' \
		--transform 's,^,$(PROJECT)-$(VERSION)/,' \
		.
	@echo "Source package created: dist/$(PROJECT)-$(VERSION).tar.gz"

# Check dependencies
.PHONY: check-deps
check-deps:
	@echo "Checking dependencies..."
	@pkg-config --exists gtk+-3.0 && echo "✓ GTK+3.0 found" || echo "✗ GTK+3.0 missing"
	@which gcc >/dev/null && echo "✓ GCC found" || echo "✗ GCC missing"
	@which systemctl >/dev/null && echo "✓ systemd found" || echo "✗ systemd missing"
	@which bash >/dev/null && echo "✓ Bash found" || echo "✗ Bash missing"
	@pkg-config --exists gio-2.0 && echo "✓ GIO found" || echo "✗ GIO missing"

# Check system requirements
.PHONY: check-system
check-system: check-deps
	@echo "Checking system requirements..."
	@if systemctl --user status >/dev/null 2>&1; then \
		echo "✓ User systemd available"; \
	else \
		echo "✗ User systemd not available"; \
	fi
	@if command -v gio >/dev/null 2>&1; then \
		echo "✓ gio command available"; \
	else \
		echo "✗ gio command missing"; \
	fi

# Show help
.PHONY: help
help:
	@echo "NAS Monitor Build System"
	@echo "========================"
	@echo ""
	@echo "Building:"
	@echo "  all              Build all components"
	@echo "  debug            Build with debug symbols"
	@echo "  static           Build static binary"
	@echo ""
	@echo "Installation:"
	@echo "  install          Install all components"
	@echo "  desktop-entry    Create desktop menu entry"
	@echo "  enable-service   Enable and start systemd service"
	@echo "  dev-install      Development installation"
	@echo ""
	@echo "Testing:"
	@echo "  test             Run all tests"
	@echo "  lint             Run code quality checks"
	@echo "  check-deps       Check build dependencies"
	@echo "  check-system     Check system requirements"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean            Remove build artifacts"
	@echo "  uninstall        Remove installed files"
	@echo "  package          Create source package"
	@echo "  docs             Generate documentation"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX           Installation prefix (default: ~/.local)"
	@echo "  VERSION          Project version (default: $(VERSION))"

# Default help target
.DEFAULT_GOAL := help