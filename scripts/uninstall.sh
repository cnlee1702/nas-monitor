#!/bin/bash
# NAS Monitor Uninstaller
# Clean removal of NAS Monitor and all associated files

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UNINSTALL_LOG="/tmp/nas-monitor-uninstall.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Uninstall options
INTERACTIVE=true
PRESERVE_CONFIG=true
PRESERVE_LOGS=false
FORCE_REMOVE=false
DRY_RUN=false

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [UNINSTALL] $*" | tee -a "$UNINSTALL_LOG"
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

print_dry_run() {
    echo -e "${BLUE}[DRY RUN] $1${NC}"
    log "DRY_RUN: $1"
}

# Help function
show_help() {
    cat << EOF
NAS Monitor Uninstaller

Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help              Show this help message
  -y, --yes               Non-interactive mode (assume yes)
  -f, --force             Force removal (don't prompt for dangerous operations)
  -c, --remove-config     Remove configuration files (default: preserve)
  -l, --preserve-logs     Preserve log files (default: remove)
  -n, --dry-run          Show what would be removed without actually removing
  -v, --verbose          Enable verbose output

REMOVAL MODES:
  Default mode:           Remove binaries and service, preserve config
  --remove-config:        Remove everything including configuration
  --force:                Skip all confirmation prompts

EXAMPLES:
  $0                      # Interactive uninstall (preserve config)
  $0 -y                   # Automatic uninstall (preserve config)
  $0 -y -c                # Remove everything including config
  $0 -n                   # Dry run (show what would be removed)
  $0 -f -c                # Force complete removal

This script will remove:
- NAS Monitor binaries
- systemd service files
- Desktop integration files
- Optionally: configuration and log files

EOF
}

# Detect current installation
detect_installation() {
    print_step "Detecting current installation..."
    
    local found_files=()
    local service_running=false
    
    # Check for installed files
    local potential_files=(
        "$HOME/.local/bin/nas-monitor.sh"
        "$HOME/.local/bin/nas-config-gui"
        "$HOME/.config/systemd/user/nas-monitor.service"
        "$HOME/.config/nas-monitor/config.conf"
        "$HOME/.local/share/applications/nas-config-gui.desktop"
        "$HOME/.local/share/nas-monitor.log"
    )
    
    for file in "${potential_files[@]}"; do
        if [ -f "$file" ]; then
            found_files+=("$file")
            log "Found: $file"
        fi
    done
    
    # Check service status
    if systemctl --user is-active nas-monitor.service >/dev/null 2>&1; then
        service_running=true
        log "Service is currently running"
    fi
    
    # Check if service is enabled
    local service_enabled=false
    if systemctl --user is-enabled nas-monitor.service >/dev/null 2>&1; then
        service_enabled=true
        log "Service is enabled for auto-start"
    fi
    
    # Report findings
    if [ ${#found_files[@]} -eq 0 ] && [ "$service_running" = "false" ]; then
        print_warning "No NAS Monitor installation detected"
        if $INTERACTIVE; then
            echo -e "${YELLOW}Continue anyway? (y/N): ${NC}"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo "Uninstall cancelled"
                exit 0
            fi
        fi
    else
        print_success "NAS Monitor installation detected"
        echo "  Files found: ${#found_files[@]}"
        echo "  Service running: $service_running"
        echo "  Service enabled: $service_enabled"
    fi
    
    log "Installation detection complete"
}

# Stop and disable service
stop_service() {
    print_step "Stopping NAS Monitor service..."
    
    local service_was_running=false
    local service_was_enabled=false
    
    # Check current status
    if systemctl --user is-active nas-monitor.service >/dev/null 2>&1; then
        service_was_running=true
    fi
    
    if systemctl --user is-enabled nas-monitor.service >/dev/null 2>&1; then
        service_was_enabled=true
    fi
    
    if [ "$service_was_running" = "false" ] && [ "$service_was_enabled" = "false" ]; then
        print_success "Service not running or enabled"
        return 0
    fi
    
    # Stop service
    if [ "$service_was_running" = "true" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            print_dry_run "Would stop service: systemctl --user stop nas-monitor.service"
        else
            if systemctl --user stop nas-monitor.service 2>/dev/null; then
                print_success "Service stopped"
            else
                print_warning "Failed to stop service (may not be running)"
            fi
        fi
    fi
    
    # Disable service
    if [ "$service_was_enabled" = "true" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            print_dry_run "Would disable service: systemctl --user disable nas-monitor.service"
        else
            if systemctl --user disable nas-monitor.service 2>/dev/null; then
                print_success "Service disabled"
            else
                print_warning "Failed to disable service"
            fi
        fi
    fi
    
    # Reload systemd
    if [ "$DRY_RUN" = "true" ]; then
        print_dry_run "Would reload systemd: systemctl --user daemon-reload"
    else
        systemctl --user daemon-reload 2>/dev/null || true
        print_success "systemd configuration reloaded"
    fi
}

# Remove files
remove_files() {
    print_step "Removing NAS Monitor files..."
    
    # Define file categories
    local binary_files=(
        "$HOME/.local/bin/nas-monitor.sh"
        "$HOME/.local/bin/nas-config-gui"
    )
    
    local service_files=(
        "$HOME/.config/systemd/user/nas-monitor.service"
    )
    
    local desktop_files=(
        "$HOME/.local/share/applications/nas-config-gui.desktop"
    )
    
    local config_files=(
        "$HOME/.config/nas-monitor/config.conf"
    )
    
    local log_files=(
        "$HOME/.local/share/nas-monitor.log"
    )
    
    local config_dirs=(
        "$HOME/.config/nas-monitor"
    )
    
    # Remove binary files
    for file in "${binary_files[@]}"; do
        if [ -f "$file" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                print_dry_run "Would remove binary: $file"
            else
                rm -f "$file"
                print_success "Removed binary: $(basename "$file")"
            fi
        fi
    done
    
    # Remove service files
    for file in "${service_files[@]}"; do
        if [ -f "$file" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                print_dry_run "Would remove service file: $file"
            else
                rm -f "$file"
                print_success "Removed service file: $(basename "$file")"
            fi
        fi
    done
    
    # Remove desktop files
    for file in "${desktop_files[@]}"; do
        if [ -f "$file" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                print_dry_run "Would remove desktop file: $file"
            else
                rm -f "$file"
                print_success "Removed desktop file: $(basename "$file")"
            fi
        fi
    done
    
    # Handle log files
    if [ "$PRESERVE_LOGS" = "false" ]; then
        for file in "${log_files[@]}"; do
            if [ -f "$file" ]; then
                if [ "$DRY_RUN" = "true" ]; then
                    print_dry_run "Would remove log file: $file"
                else
                    rm -f "$file"
                    print_success "Removed log file: $(basename "$file")"
                fi
            fi
        done
    else
        local preserved_logs=()
        for file in "${log_files[@]}"; do
            if [ -f "$file" ]; then
                preserved_logs+=("$file")
            fi
        done
        if [ ${#preserved_logs[@]} -gt 0 ]; then
            print_warning "Preserved log files: ${preserved_logs[*]}"
        fi
    fi
    
    # Handle configuration files
    if [ "$PRESERVE_CONFIG" = "false" ]; then
        # Ask for confirmation unless forced
        if $INTERACTIVE && [ "$FORCE_REMOVE" = "false" ] && [ "$DRY_RUN" = "false" ]; then
            echo -e "${YELLOW}This will permanently delete your NAS Monitor configuration.${NC}"
            echo -e "${YELLOW}Are you sure? (type 'yes' to confirm): ${NC}"
            read -r response
            if [ "$response" != "yes" ]; then
                print_step "Configuration removal cancelled by user"
                PRESERVE_CONFIG=true
            fi
        fi
        
        if [ "$PRESERVE_CONFIG" = "false" ]; then
            for file in "${config_files[@]}"; do
                if [ -f "$file" ]; then
                    if [ "$DRY_RUN" = "true" ]; then
                        print_dry_run "Would remove config file: $file"
                    else
                        rm -f "$file"
                        print_success "Removed config file: $(basename "$file")"
                    fi
                fi
            done
            
            # Remove config directories if empty
            for dir in "${config_dirs[@]}"; do
                if [ -d "$dir" ]; then
                    if [ "$DRY_RUN" = "true" ]; then
                        print_dry_run "Would remove config directory: $dir"
                    else
                        rmdir "$dir" 2>/dev/null && print_success "Removed config directory: $(basename "$dir")" || true
                    fi
                fi
            done
        fi
    else
        local preserved_configs=()
        for file in "${config_files[@]}"; do
            if [ -f "$file" ]; then
                preserved_configs+=("$file")
            fi
        done
        if [ ${#preserved_configs[@]} -gt 0 ]; then
            print_warning "Preserved configuration files: ${preserved_configs[*]}"
        fi
    fi
}

# Clean up process artifacts
cleanup_processes() {
    print_step "Checking for running processes..."
    
    # Look for any running NAS Monitor processes
    local nas_processes
    nas_processes=$(pgrep -f "nas-monitor" 2>/dev/null || echo "")
    
    if [ -n "$nas_processes" ]; then
        print_warning "Found running NAS Monitor processes: $nas_processes"
        
        if $INTERACTIVE && [ "$FORCE_REMOVE" = "false" ] && [ "$DRY_RUN" = "false" ]; then
            echo -e "${YELLOW}Terminate these processes? (y/N): ${NC}"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                if [ "$DRY_RUN" = "true" ]; then
                    print_dry_run "Would terminate processes: $nas_processes"
                else
                    echo "$nas_processes" | xargs -r kill 2>/dev/null || true
                    print_success "Terminated NAS Monitor processes"
                fi
            fi
        elif [ "$FORCE_REMOVE" = "true" ] && [ "$DRY_RUN" = "false" ]; then
            echo "$nas_processes" | xargs -r kill 2>/dev/null || true
            print_success "Terminated NAS Monitor processes"
        fi
    else
        print_success "No running NAS Monitor processes found"
    fi
}

# Clean up mounts
cleanup_mounts() {
    print_step "Checking for active mounts..."
    
    # Check for any GVfs mounts that might be from NAS Monitor
    local gvfs_mounts
    gvfs_mounts=$(gio mount -l 2>/dev/null | grep -i smb || echo "")
    
    if [ -n "$gvfs_mounts" ]; then
        print_warning "Found active SMB mounts:"
        echo "$gvfs_mounts"
        
        if $INTERACTIVE && [ "$FORCE_REMOVE" = "false" ]; then
            echo -e "${YELLOW}These mounts may have been created by NAS Monitor.${NC}"
            echo -e "${YELLOW}Leave them mounted? (Y/n): ${NC}"
            read -r response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                if [ "$DRY_RUN" = "true" ]; then
                    print_dry_run "Would unmount SMB shares"
                else
                    print_step "Unmounting SMB shares..."
                    # This is complex and risky, so we'll just warn for now
                    print_warning "Manual unmounting may be required"
                    print_warning "Use 'gio mount -l' and 'gio mount -u' to manage mounts"
                fi
            fi
        fi
    else
        print_success "No SMB mounts found"
    fi
}

# Verify removal
verify_removal() {
    print_step "Verifying removal..."
    
    local remaining_files=()
    
    # Check for any remaining files
    local check_files=(
        "$HOME/.local/bin/nas-monitor.sh"
        "$HOME/.local/bin/nas-config-gui"
        "$HOME/.config/systemd/user/nas-monitor.service"
        "$HOME/.local/share/applications/nas-config-gui.desktop"
    )
    
    if [ "$PRESERVE_CONFIG" = "false" ]; then
        check_files+=("$HOME/.config/nas-monitor/config.conf")
    fi
    
    if [ "$PRESERVE_LOGS" = "false" ]; then
        check_files+=("$HOME/.local/share/nas-monitor.log")
    fi
    
    for file in "${check_files[@]}"; do
        if [ -f "$file" ]; then
            remaining_files+=("$file")
        fi
    done
    
    if [ ${#remaining_files[@]} -eq 0 ]; then
        print_success "Removal verification passed"
    else
        print_warning "Some files remain: ${remaining_files[*]}"
        if [ "$DRY_RUN" = "false" ]; then
            print_warning "You may need to remove these manually"
        fi
    fi
    
    # Check service status
    if systemctl --user is-enabled nas-monitor.service >/dev/null 2>&1; then
        print_warning "Service is still enabled"
    elif systemctl --user is-active nas-monitor.service >/dev/null 2>&1; then
        print_warning "Service is still running"
    else
        print_success "Service completely removed"
    fi
}

# Show completion message
show_completion() {
    if [ "$DRY_RUN" = "true" ]; then
        print_header "Dry Run Complete"
        echo -e "${CYAN}This was a dry run. No files were actually removed.${NC}"
        echo -e "${CYAN}Run without -n/--dry-run to perform the actual uninstall.${NC}"
    else
        print_header "Uninstall Complete"
        echo -e "${GREEN}NAS Monitor has been removed from your system.${NC}"
    fi
    
    echo
    
    if [ "$PRESERVE_CONFIG" = "true" ]; then
        echo -e "${CYAN}Configuration preserved:${NC}"
        echo "  ~/.config/nas-monitor/config.conf"
        echo "  (Remove manually if desired)"
        echo
    fi
    
    if [ "$PRESERVE_LOGS" = "true" ]; then
        echo -e "${CYAN}Logs preserved:${NC}"
        echo "  ~/.local/share/nas-monitor.log"
        echo "  (Remove manually if desired)"
        echo
    fi
    
    echo -e "${CYAN}To reinstall NAS Monitor:${NC}"
    echo "  Run the installation script again"
    echo
    
    echo -e "${CYAN}Uninstall log:${NC}"
    echo "  $UNINSTALL_LOG"
}

# Main uninstall process
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
            -f|--force)
                FORCE_REMOVE=true
                INTERACTIVE=false
                shift
                ;;
            -c|--remove-config)
                PRESERVE_CONFIG=false
                shift
                ;;
            -l|--preserve-logs)
                PRESERVE_LOGS=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Initialize log
    echo "NAS Monitor Uninstall - $(date)" > "$UNINSTALL_LOG"
    
    # Show header
    print_header "NAS Monitor Uninstaller"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}DRY RUN MODE - No files will be actually removed${NC}"
    else
        echo -e "${CYAN}This script will remove NAS Monitor from your system.${NC}"
    fi
    
    echo
    
    if $INTERACTIVE && [ "$DRY_RUN" = "false" ]; then
        echo -e "${YELLOW}Continue with uninstall? (y/N): ${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Uninstall cancelled by user"
            exit 0
        fi
    fi
    
    # Uninstall steps
    detect_installation
    stop_service
    cleanup_processes
    cleanup_mounts
    remove_files
    verify_removal
    show_completion
    
    # Success
    log "Uninstall completed successfully"
    exit 0
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi