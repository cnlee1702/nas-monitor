#!/bin/bash
# NAS Monitor Quick Installer
# One-command installation script for end users

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_LOG="/tmp/nas-monitor-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Installation options
INTERACTIVE=true
ENABLE_SERVICE=true
CREATE_DESKTOP_ENTRY=true
RUN_TESTS=false
BACKUP_EXISTING=true

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INSTALL] $*" | tee -a "$INSTALL_LOG"
}

print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
    log "SECTION: $1"
}

print_step() {
    echo -e "${CYAN}$1${NC}"
    log "STEP: $1"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
}

# Help function
show_help() {
    cat << EOF
NAS Monitor Quick Installer

Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help              Show this help message
  -y, --yes               Non-interactive mode (assume yes)
  -n, --no-service        Don't enable systemd service
  -d, --no-desktop        Don't create desktop entry
  -t, --run-tests         Run tests after installation
  -b, --no-backup         Don't backup existing configuration
  -v, --verbose           Enable verbose output
  --prefix PREFIX         Installation prefix (default: ~/.local)

EXAMPLES:
  $0                      # Interactive installation
  $0 -y                   # Automatic installation
  $0 -y -t                # Auto install with tests
  $0 --no-service         # Install without enabling service

This script will:
1. Check system requirements
2. Build the project
3. Install binaries and configuration
4. Set up systemd service
5. Create desktop integration
6. Optionally run tests

EOF
}

# System detection
detect_system() {
    print_step "Detecting system information..."
    
    # Operating system
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        log "Detected OS: $OS_NAME $OS_VERSION"
    else
        OS_NAME="Unknown Linux"
        OS_VERSION="Unknown"
        log "Could not detect OS version"
    fi
    
    # Desktop environment
    if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
        DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
    elif [ -n "${DESKTOP_SESSION:-}" ]; then
        DESKTOP_ENV="$DESKTOP_SESSION"
    else
        DESKTOP_ENV="Unknown"
    fi
    log "Desktop environment: $DESKTOP_ENV"
    
    # Package manager
    if command -v apt >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
        INSTALL_CMD="sudo apt install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
    elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
    elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
        INSTALL_CMD="sudo zypper install -y"
    else
        PACKAGE_MANAGER="unknown"
        INSTALL_CMD=""
    fi
    log "Package manager: $PACKAGE_MANAGER"
    
    print_success "System detection complete"
}

# Check dependencies
check_dependencies() {
    print_step "Checking system dependencies..."
    
    local missing_deps=()
    local optional_deps=()
    
    # Required dependencies
    local required_commands=("gcc" "make" "pkg-config" "systemctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # GTK development libraries
    if ! pkg-config --exists gtk+-3.0; then
        missing_deps+=("libgtk-3-dev")
    fi
    
    # Check for gio (usually part of glib)
    if ! command -v gio >/dev/null 2>&1; then
        missing_deps+=("glib2")
    fi
    
    # Optional dependencies
    local optional_commands=("notify-send" "nmcli" "upower" "secret-tool")
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            optional_deps+=("$cmd")
        fi
    done
    
    # Report results
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "All required dependencies are available"
    else
        print_error "Missing required dependencies: ${missing_deps[*]}"
        
        if [ -n "$INSTALL_CMD" ]; then
            echo -e "${YELLOW}Attempting to install missing dependencies...${NC}"
            install_dependencies "${missing_deps[@]}"
        else
            echo -e "${RED}Please install missing dependencies manually:${NC}"
            for dep in "${missing_deps[@]}"; do
                echo "  - $dep"
            done
            exit 1
        fi
    fi
    
    if [ ${#optional_deps[@]} -gt 0 ]; then
        print_warning "Optional dependencies missing: ${optional_deps[*]}"
        echo "These are not required but may limit functionality"
    fi
}

# Install system dependencies
install_dependencies() {
    local deps=("$@")
    print_step "Installing system dependencies..."
    
    case "$PACKAGE_MANAGER" in
        "apt")
            # Ubuntu/Debian packages
            local apt_packages=()
            for dep in "${deps[@]}"; do
                case "$dep" in
                    "gcc") apt_packages+=("build-essential") ;;
                    "libgtk-3-dev") apt_packages+=("libgtk-3-dev") ;;
                    "pkg-config") apt_packages+=("pkg-config") ;;
                    "glib2") apt_packages+=("libglib2.0-bin") ;;
                    *) apt_packages+=("$dep") ;;
                esac
            done
            
            if $INTERACTIVE; then
                echo -e "${YELLOW}About to install: ${apt_packages[*]}${NC}"
                echo -e "${YELLOW}Continue? (y/N): ${NC}"
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    print_error "Installation cancelled by user"
                    exit 1
                fi
            fi
            
            sudo apt update
            $INSTALL_CMD "${apt_packages[@]}"
            ;;
            
        "dnf")
            # Fedora packages
            local dnf_packages=()
            for dep in "${deps[@]}"; do
                case "$dep" in
                    "gcc") dnf_packages+=("gcc" "make") ;;
                    "libgtk-3-dev") dnf_packages+=("gtk3-devel") ;;
                    "pkg-config") dnf_packages+=("pkgconfig") ;;
                    "glib2") dnf_packages+=("glib2") ;;
                    *) dnf_packages+=("$dep") ;;
                esac
            done
            
            $INSTALL_CMD "${dnf_packages[@]}"
            ;;
            
        "pacman")
            # Arch Linux packages
            local pacman_packages=()
            for dep in "${deps[@]}"; do
                case "$dep" in
                    "gcc") pacman_packages+=("base-devel") ;;
                    "libgtk-3-dev") pacman_packages+=("gtk3") ;;
                    "pkg-config") pacman_packages+=("pkgconf") ;;
                    "glib2") pacman_packages+=("glib2") ;;
                    *) pacman_packages+=("$dep") ;;
                esac
            done
            
            $INSTALL_CMD "${pacman_packages[@]}"
            ;;
            
        *)
            print_error "Automatic package installation not supported for $PACKAGE_MANAGER"
            echo "Please install these packages manually:"
            for dep in "${deps[@]}"; do
                echo "  - $dep"
            done
            exit 1
            ;;
    esac
    
    print_success "Dependencies installed successfully"
}

# Backup existing installation
backup_existing() {
    if [ "$BACKUP_EXISTING" != "true" ]; then
        return 0
    fi
    
    print_step "Checking for existing installation..."
    
    local backup_dir="$HOME/.nas-monitor-backup-$(date +%Y%m%d_%H%M%S)"
    local backed_up=false
    
    # Check for existing files
    local files_to_backup=(
        "$HOME/.local/bin/nas-monitor.sh"
        "$HOME/.local/bin/nas-config-gui"
        "$HOME/.config/systemd/user/nas-monitor.service"
        "$HOME/.config/nas-monitor/config.conf"
        "$HOME/.local/share/applications/nas-config-gui.desktop"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            if [ "$backed_up" = "false" ]; then
                mkdir -p "$backup_dir"
                print_step "Creating backup in $backup_dir"
                backed_up=true
            fi
            
            local backup_path="$backup_dir${file#$HOME}"
            mkdir -p "$(dirname "$backup_path")"
            cp "$file" "$backup_path"
            log "Backed up: $file -> $backup_path"
        fi
    done
    
    if [ "$backed_up" = "true" ]; then
        print_success "Existing installation backed up to $backup_dir"
    else
        print_success "No existing installation found"
    fi
}

# Build project
build_project() {
    print_step "Building NAS Monitor..."
    
    # Clean any existing build
    make -C "$PROJECT_ROOT" clean >/dev/null 2>&1 || true
    
    # Build the project
    if make -C "$PROJECT_ROOT" all >> "$INSTALL_LOG" 2>&1; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        echo "Check the build log: $INSTALL_LOG"
        tail -20 "$INSTALL_LOG"
        exit 1
    fi
}

# Install project
install_project() {
    print_step "Installing NAS Monitor..."
    
    # Run the installation
    if make -C "$PROJECT_ROOT" install >> "$INSTALL_LOG" 2>&1; then
        print_success "Installation completed successfully"
    else
        print_error "Installation failed"
        echo "Check the installation log: $INSTALL_LOG"
        tail -20 "$INSTALL_LOG"
        exit 1
    fi
    
    # Verify installation
    local installed_files=(
        "$HOME/.local/bin/nas-monitor.sh"
        "$HOME/.local/bin/nas-config-gui"
        "$HOME/.config/systemd/user/nas-monitor.service"
    )
    
    for file in "${installed_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Installation verification failed: $file not found"
            exit 1
        fi
    done
    
    print_success "Installation verification passed"
}

# Create desktop integration
create_desktop_integration() {
    if [ "$CREATE_DESKTOP_ENTRY" != "true" ]; then
        return 0
    fi
    
    print_step "Creating desktop integration..."
    
    if make -C "$PROJECT_ROOT" desktop-entry >> "$INSTALL_LOG" 2>&1; then
        print_success "Desktop integration created"
    else
        print_warning "Desktop integration creation failed (non-critical)"
        log "Desktop integration failed - continuing installation"
    fi
}

# Configure service
configure_service() {
    if [ "$ENABLE_SERVICE" != "true" ]; then
        return 0
    fi
    
    print_step "Configuring systemd service..."
    
    # Reload systemd
    systemctl --user daemon-reload
    
    if $INTERACTIVE; then
        echo -e "${YELLOW}Enable and start the NAS Monitor service? (Y/n): ${NC}"
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            print_step "Service configuration skipped by user"
            return 0
        fi
    fi
    
    # Enable service
    if systemctl --user enable nas-monitor.service >> "$INSTALL_LOG" 2>&1; then
        print_success "Service enabled for auto-start"
    else
        print_warning "Failed to enable service auto-start"
    fi
    
    # Start service
    if systemctl --user start nas-monitor.service >> "$INSTALL_LOG" 2>&1; then
        sleep 2
        if systemctl --user is-active nas-monitor.service >/dev/null; then
            print_success "Service started successfully"
        else
            print_warning "Service enabled but failed to start"
            print_warning "You may need to configure NAS devices first"
        fi
    else
        print_warning "Failed to start service"
        print_warning "This is normal if no NAS devices are configured yet"
    fi
}

# Create default configuration
create_default_config() {
    print_step "Setting up configuration..."
    
    local config_file="$HOME/.config/nas-monitor/config.conf"
    
    if [ -f "$config_file" ]; then
        print_success "Configuration file already exists"
        return 0
    fi
    
    # Create default configuration
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << 'EOF'
# NAS Monitor Configuration
# Edit this file to match your network and NAS setup

[networks]
# Add your home network names (comma-separated)
# Include an empty entry for wired connections
home_networks=YourWiFi-Network,YourWiFi-5G,

[nas_devices]
# Add your NAS devices in format: hostname/share
# Examples:
# my-nas.local/home
# 192.168.1.100/media

[intervals]
# Check intervals in seconds
home_ac_interval=15
home_battery_interval=60
away_ac_interval=180
away_battery_interval=600

[behavior]
max_failed_attempts=3
min_battery_level=10
enable_notifications=true
EOF
    
    chmod 600 "$config_file"
    
    print_success "Default configuration created at $config_file"
    print_warning "Please edit the configuration to add your NAS devices"
}

# Run post-installation tests
run_post_install_tests() {
    if [ "$RUN_TESTS" != "true" ]; then
        return 0
    fi
    
    print_step "Running post-installation tests..."
    
    local test_script="$PROJECT_ROOT/test/run-tests.sh"
    if [ -f "$test_script" ]; then
        if "$test_script" --quick unit integration >> "$INSTALL_LOG" 2>&1; then
            print_success "Post-installation tests passed"
        else
            print_warning "Some post-installation tests failed"
            print_warning "Check $INSTALL_LOG for details"
        fi
    else
        print_warning "Test suite not available"
    fi
}

# Show completion message
show_completion() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}NAS Monitor has been successfully installed.${NC}"
    echo
    echo -e "${CYAN}Next steps:${NC}"
    echo "1. Configure your NAS devices:"
    echo -e "   ${YELLOW}nas-config-gui${NC}  # GUI configuration"
    echo -e "   ${YELLOW}nano ~/.config/nas-monitor/config.conf${NC}  # Manual editing"
    echo
    echo "2. Manage the service:"
    echo -e "   ${YELLOW}systemctl --user status nas-monitor.service${NC}   # Check status"
    echo -e "   ${YELLOW}systemctl --user start nas-monitor.service${NC}    # Start service"
    echo -e "   ${YELLOW}systemctl --user stop nas-monitor.service${NC}     # Stop service"
    echo
    echo "3. Monitor operation:"
    echo -e "   ${YELLOW}journalctl --user -u nas-monitor.service -f${NC}   # Follow logs"
    echo
    echo -e "${CYAN}Troubleshooting:${NC}"
    echo -e "  Installation log: ${YELLOW}$INSTALL_LOG${NC}"
    echo -e "  Project documentation: ${YELLOW}$PROJECT_ROOT/README.md${NC}"
    echo -e "  GUI configuration: ${YELLOW}nas-config-gui${NC}"
    echo
    
    if [ "$ENABLE_SERVICE" = "true" ]; then
        local service_status
        if systemctl --user is-active nas-monitor.service >/dev/null; then
            service_status="${GREEN}running${NC}"
        else
            service_status="${YELLOW}stopped${NC}"
        fi
        echo -e "Service status: $service_status"
    fi
}

# Cleanup on error
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Installation failed with exit code $exit_code"
        echo -e "${YELLOW}Check the installation log: $INSTALL_LOG${NC}"
        echo -e "${YELLOW}You can try running the installation again or install manually:${NC}"
        echo -e "  ${CYAN}make install${NC}"
    fi
}

# Main installation process
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -y|--yes)
                INTERACTIVE=false
                shift
                ;;
            -n|--no-service)
                ENABLE_SERVICE=false
                shift
                ;;
            -d|--no-desktop)
                CREATE_DESKTOP_ENTRY=false
                shift
                ;;
            -t|--run-tests)
                RUN_TESTS=true
                shift
                ;;
            -b|--no-backup)
                BACKUP_EXISTING=false
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            --prefix)
                echo -e "${YELLOW}Custom prefix not yet supported${NC}"
                shift 2
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Setup
    trap cleanup_on_error EXIT
    
    # Initialize log
    echo "NAS Monitor Installation - $(date)" > "$INSTALL_LOG"
    
    # Show header
    print_header "NAS Monitor Installation"
    echo -e "${CYAN}This script will install NAS Monitor and set up the service.${NC}"
    echo
    
    if $INTERACTIVE; then
        echo -e "${YELLOW}Continue with installation? (Y/n): ${NC}"
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            echo "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Installation steps
    detect_system
    check_dependencies
    backup_existing
    build_project
    install_project
    create_default_config
    create_desktop_integration
    configure_service
    run_post_install_tests
    show_completion
    
    # Success
    log "Installation completed successfully"
    exit 0
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi