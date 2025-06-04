#!/bin/bash
# NAS Monitor Update Script
# Handles updates, version management, and migration between versions

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UPDATE_LOG="/tmp/nas-monitor-update.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Update configuration
UPDATE_SOURCE="git"
GIT_REPO="https://github.com/yourusername/nas-monitor.git"
GIT_BRANCH="main"
TARGET_VERSION=""
BACKUP_BEFORE_UPDATE=true
PRESERVE_CONFIG=true
AUTO_RESTART_SERVICE=true
FORCE_UPDATE=false
CHECK_ONLY=false
ROLLBACK_VERSION=""

# Version information
CURRENT_VERSION=""
LATEST_VERSION=""
INSTALLED_VERSION=""

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [UPDATE] $*" | tee -a "$UPDATE_LOG"
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

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log "INFO: $1"
}

# Help function
show_help() {
    cat << EOF
NAS Monitor Update Script

Usage: $0 [OPTIONS]

UPDATE OPTIONS:
  -c, --check             Check for updates without installing
  -u, --update            Update to latest version
  -v, --version VERSION   Update to specific version
  -f, --force             Force update even if versions match
  -s, --source SOURCE     Update source: git, github, local (default: git)
  -b, --branch BRANCH     Git branch to use (default: main)

BACKUP AND SAFETY:
  --no-backup            Skip backup before update
  --no-preserve-config   Don't preserve configuration during update
  --no-restart           Don't restart service after update
  -r, --rollback VERSION Rollback to specified version

GENERAL OPTIONS:
  -h, --help              Show this help message
  --verbose               Enable verbose output

EXAMPLES:
  $0 --check                    # Check for available updates
  $0 --update                   # Update to latest version
  $0 --version v1.2.0           # Update to specific version
  $0 --force --update           # Force update even if same version
  $0 --rollback v1.1.0          # Rollback to version 1.1.0
  $0 --source local --update    # Update from local source

UPDATE SOURCES:
  git      - Clone/pull from Git repository
  github   - Download release from GitHub
  local    - Use current directory as source

EOF
}

# Get current installed version
get_installed_version() {
    print_step "Detecting installed version..."
    
    # Try to get version from binary
    local daemon_script="$HOME/.local/bin/nas-monitor.sh"
    if [ -f "$daemon_script" ]; then
        # Look for version string in script
        INSTALLED_VERSION=$(grep -o "VERSION=[\"']\?[^\"']*[\"']\?" "$daemon_script" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
        
        if [ -z "$INSTALLED_VERSION" ]; then
            # Try to get from git if we're in a git repo
            if [ -d "$PROJECT_ROOT/.git" ]; then
                INSTALLED_VERSION=$(git -C "$PROJECT_ROOT" describe --tags 2>/dev/null || echo "unknown")
            else
                INSTALLED_VERSION="unknown"
            fi
        fi
    else
        print_warning "NAS Monitor not found in standard location"
        INSTALLED_VERSION="not-installed"
    fi
    
    CURRENT_VERSION="$INSTALLED_VERSION"
    print_info "Current version: $CURRENT_VERSION"
}

# Get latest available version
get_latest_version() {
    print_step "Checking for latest version..."
    
    case "$UPDATE_SOURCE" in
        "git")
            if command -v git >/dev/null 2>&1; then
                # Get latest tag from git repository
                LATEST_VERSION=$(git ls-remote --tags --refs "$GIT_REPO" | \
                               grep -o 'refs/tags/v[0-9]*\.[0-9]*\.[0-9]*' | \
                               sed 's|refs/tags/||' | \
                               sort -V | tail -1 || echo "")
                
                if [ -z "$LATEST_VERSION" ]; then
                    # Fallback to branch HEAD
                    LATEST_VERSION=$(git ls-remote --heads "$GIT_REPO" "$GIT_BRANCH" | cut -f1 | head -c8)
                    LATEST_VERSION="$GIT_BRANCH-$LATEST_VERSION"
                fi
            else
                print_error "Git not available for version checking"
                return 1
            fi
            ;;
        "github")
            if command -v curl >/dev/null 2>&1; then
                # Get latest release from GitHub API
                local api_url="https://api.github.com/repos/${GIT_REPO#https://github.com/}/releases/latest"
                LATEST_VERSION=$(curl -s "$api_url" | grep '"tag_name"' | cut -d'"' -f4 || echo "")
            else
                print_error "curl not available for GitHub API access"
                return 1
            fi
            ;;
        "local")
            # Use current project version
            if [ -d "$PROJECT_ROOT/.git" ]; then
                LATEST_VERSION=$(git -C "$PROJECT_ROOT" describe --tags 2>/dev/null || echo "local-$(date +%Y%m%d)")
            else
                LATEST_VERSION="local-$(date +%Y%m%d)"
            fi
            ;;
        *)
            print_error "Unknown update source: $UPDATE_SOURCE"
            return 1
            ;;
    esac
    
    if [ -n "$LATEST_VERSION" ]; then
        print_info "Latest version: $LATEST_VERSION"
    else
        print_error "Could not determine latest version"
        return 1
    fi
}

# Compare versions
compare_versions() {
    local current="$1"
    local latest="$2"
    
    # Handle special cases
    if [ "$current" = "not-installed" ]; then
        echo "install"
        return
    fi
    
    if [ "$current" = "unknown" ] || [ "$current" = "$latest" ]; then
        echo "same"
        return
    fi
    
    # Simple version comparison
    if printf '%s\n%s\n' "$current" "$latest" | sort -V | head -1 | grep -q "^$current$"; then
        echo "upgrade"
    else
        echo "downgrade"
    fi
}

# Create backup
create_backup() {
    if [ "$BACKUP_BEFORE_UPDATE" != "true" ]; then
        return 0
    fi
    
    print_step "Creating backup of current installation..."
    
    local backup_dir="$HOME/.nas-monitor-update-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Files to backup
    local files_to_backup=(
        "$HOME/.local/bin/nas-monitor.sh"
        "$HOME/.local/bin/nas-config-gui"
        "$HOME/.config/systemd/user/nas-monitor.service"
        "$HOME/.config/nas-monitor/config.conf"
        "$HOME/.local/share/applications/nas-config-gui.desktop"
        "$HOME/.local/share/nas-monitor.log"
    )
    
    local backed_up_files=0
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            local backup_path="$backup_dir${file#$HOME}"
            mkdir -p "$(dirname "$backup_path")"
            cp "$file" "$backup_path"
            ((backed_up_files++))
            log "Backed up: $file"
        fi
    done
    
    if [ $backed_up_files -gt 0 ]; then
        echo "v$CURRENT_VERSION" > "$backup_dir/VERSION"
        echo "$(date)" > "$backup_dir/BACKUP_DATE"
        
        print_success "Backup created: $backup_dir ($backed_up_files files)"
        log "Backup location: $backup_dir"
        
        # Store backup location for potential rollback
        echo "$backup_dir" > "/tmp/nas-monitor-last-backup"
    else
        print_warning "No files found to backup"
        rmdir "$backup_dir" 2>/dev/null || true
    fi
}

# Download update source
download_update() {
    local download_dir="$1"
    local version="${2:-$LATEST_VERSION}"
    
    print_step "Downloading update source..."
    
    case "$UPDATE_SOURCE" in
        "git")
            if [ -d "$download_dir/.git" ]; then
                # Update existing repository
                git -C "$download_dir" fetch origin
                if [ -n "$version" ] && [ "$version" != "$GIT_BRANCH" ]; then
                    git -C "$download_dir" checkout "$version"
                else
                    git -C "$download_dir" checkout "$GIT_BRANCH"
                    git -C "$download_dir" pull origin "$GIT_BRANCH"
                fi
            else
                # Clone repository
                git clone "$GIT_REPO" "$download_dir"
                if [ -n "$version" ] && [ "$version" != "$GIT_BRANCH" ]; then
                    git -C "$download_dir" checkout "$version"
                fi
            fi
            ;;
        "github")
            local download_url
            if [ -n "$version" ]; then
                download_url="https://github.com/${GIT_REPO#https://github.com/}/archive/refs/tags/$version.tar.gz"
            else
                download_url="https://github.com/${GIT_REPO#https://github.com/}/archive/refs/heads/$GIT_BRANCH.tar.gz"
            fi
            
            local temp_archive="/tmp/nas-monitor-update.tar.gz"
            if curl -L -o "$temp_archive" "$download_url"; then
                mkdir -p "$download_dir"
                tar -xzf "$temp_archive" -C "$download_dir" --strip-components=1
                rm -f "$temp_archive"
            else
                print_error "Failed to download update from GitHub"
                return 1
            fi
            ;;
        "local")
            # Copy current project directory
            rsync -av --exclude='.git*' \
                      --exclude='dist' \
                      --exclude='*.o' \
                      --exclude='nas-config-gui' \
                      "$PROJECT_ROOT/" "$download_dir/"
            ;;
        *)
            print_error "Unknown update source: $UPDATE_SOURCE"
            return 1
            ;;
    esac
    
    print_success "Update source downloaded"
}

# Perform update installation
install_update() {
    local update_dir="$1"
    
    print_step "Installing update..."
    
    # Stop service if running
    if systemctl --user is-active nas-monitor.service >/dev/null 2>&1; then
        print_step "Stopping NAS Monitor service..."
        systemctl --user stop nas-monitor.service
    fi
    
    # Preserve configuration if requested
    local config_backup=""
    if [ "$PRESERVE_CONFIG" = "true" ] && [ -f "$HOME/.config/nas-monitor/config.conf" ]; then
        config_backup="/tmp/nas-monitor-config-preserve.conf"
        cp "$HOME/.config/nas-monitor/config.conf" "$config_backup"
        print_info "Configuration preserved"
    fi
    
    # Build and install update
    if make -C "$update_dir" clean && make -C "$update_dir" install; then
        print_success "Update installation completed"
    else
        print_error "Update installation failed"
        
        # Attempt to restore configuration
        if [ -n "$config_backup" ] && [ -f "$config_backup" ]; then
            cp "$config_backup" "$HOME/.config/nas-monitor/config.conf"
        fi
        
        return 1
    fi
    
    # Restore configuration
    if [ -n "$config_backup" ] && [ -f "$config_backup" ]; then
        cp "$config_backup" "$HOME/.config/nas-monitor/config.conf"
        rm -f "$config_backup"
    fi
    
    # Reload systemd
    systemctl --user daemon-reload
    
    # Restart service if requested
    if [ "$AUTO_RESTART_SERVICE" = "true" ]; then
        print_step "Restarting NAS Monitor service..."
        if systemctl --user start nas-monitor.service; then
            print_success "Service restarted successfully"
        else
            print_warning "Service failed to start after update"
        fi
    fi
}

# Perform version rollback
perform_rollback() {
    local target_version="$1"
    
    print_header "Rolling back to version $target_version"
    
    # Find backup for target version
    local backup_dir=""
    local backup_dirs=()
    
    # Look for backup directories
    mapfile -t backup_dirs < <(find "$HOME" -maxdepth 1 -name ".nas-monitor-*backup*" -type d 2>/dev/null || true)
    
    for dir in "${backup_dirs[@]}"; do
        if [ -f "$dir/VERSION" ]; then
            local backup_version
            backup_version=$(cat "$dir/VERSION" 2>/dev/null | sed 's/^v//')
            if [ "$backup_version" = "${target_version#v}" ]; then
                backup_dir="$dir"
                break
            fi
        fi
    done
    
    if [ -z "$backup_dir" ]; then
        print_error "No backup found for version $target_version"
        print_info "Available backups:"
        for dir in "${backup_dirs[@]}"; do
            if [ -f "$dir/VERSION" ]; then
                local ver
                ver=$(cat "$dir/VERSION" 2>/dev/null || echo "unknown")
                local date
                date=$(cat "$dir/BACKUP_DATE" 2>/dev/null || echo "unknown")
                echo "  Version $ver (backed up: $date) - $dir"
            fi
        done
        return 1
    fi
    
    print_info "Found backup: $backup_dir"
    
    # Stop current service
    systemctl --user stop nas-monitor.service 2>/dev/null || true
    
    # Restore files from backup
    print_step "Restoring files from backup..."
    
    # Restore binaries
    if [ -f "$backup_dir/.local/bin/nas-monitor.sh" ]; then
        cp "$backup_dir/.local/bin/nas-monitor.sh" "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/nas-monitor.sh"
    fi
    
    if [ -f "$backup_dir/.local/bin/nas-config-gui" ]; then
        cp "$backup_dir/.local/bin/nas-config-gui" "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/nas-config-gui"
    fi
    
    # Restore service file
    if [ -f "$backup_dir/.config/systemd/user/nas-monitor.service" ]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp "$backup_dir/.config/systemd/user/nas-monitor.service" "$HOME/.config/systemd/user/"
    fi
    
    # Restore configuration if requested
    if [ "$PRESERVE_CONFIG" != "true" ] && [ -f "$backup_dir/.config/nas-monitor/config.conf" ]; then
        mkdir -p "$HOME/.config/nas-monitor"
        cp "$backup_dir/.config/nas-monitor/config.conf" "$HOME/.config/nas-monitor/"
    fi
    
    # Restore desktop file
    if [ -f "$backup_dir/.local/share/applications/nas-config-gui.desktop" ]; then
        mkdir -p "$HOME/.local/share/applications"
        cp "$backup_dir/.local/share/applications/nas-config-gui.desktop" "$HOME/.local/share/applications/"
    fi
    
    print_success "Files restored from backup"
    
    # Reload and restart service
    systemctl --user daemon-reload
    
    if [ "$AUTO_RESTART_SERVICE" = "true" ]; then
        if systemctl --user start nas-monitor.service; then
            print_success "Service restarted successfully"
        else
            print_warning "Service failed to start after rollback"
        fi
    fi
    
    print_success "Rollback to version $target_version completed"
}

# Main update process
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--check)
                CHECK_ONLY=true
                shift
                ;;
            -u|--update)
                CHECK_ONLY=false
                shift
                ;;
            -v|--version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            -s|--source)
                UPDATE_SOURCE="$2"
                shift 2
                ;;
            -b|--branch)
                GIT_BRANCH="$2"
                shift 2
                ;;
            --no-backup)
                BACKUP_BEFORE_UPDATE=false
                shift
                ;;
            --no-preserve-config)
                PRESERVE_CONFIG=false
                shift
                ;;
            --no-restart)
                AUTO_RESTART_SERVICE=false
                shift
                ;;
            -r|--rollback)
                ROLLBACK_VERSION="$2"
                shift 2
                ;;
            --verbose)
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
    echo "NAS Monitor Update - $(date)" > "$UPDATE_LOG"
    
    # Handle rollback request
    if [ -n "$ROLLBACK_VERSION" ]; then
        perform_rollback "$ROLLBACK_VERSION"
        exit 0
    fi
    
    # Show header
    print_header "NAS Monitor Update Manager"
    
    # Get version information
    get_installed_version
    get_latest_version
    
    # Use target version if specified
    local update_version="$LATEST_VERSION"
    if [ -n "$TARGET_VERSION" ]; then
        update_version="$TARGET_VERSION"
        print_info "Target version: $update_version"
    fi
    
    # Compare versions
    local version_comparison
    version_comparison=$(compare_versions "$CURRENT_VERSION" "$update_version")
    
    print_info "Version comparison: $version_comparison"
    
    # Check-only mode
    if [ "$CHECK_ONLY" = "true" ]; then
        print_header "Update Check Results"
        echo "Current version: $CURRENT_VERSION"
        echo "Latest version: $LATEST_VERSION"
        echo "Update needed: $([ "$version_comparison" != "same" ] && echo "Yes" || echo "No")"
        exit 0
    fi
    
    # Determine if update is needed
    local update_needed=false
    case "$version_comparison" in
        "install")
            print_info "NAS Monitor not installed - performing fresh installation"
            update_needed=true
            ;;
        "upgrade")
            print_info "Update available: $CURRENT_VERSION → $update_version"
            update_needed=true
            ;;
        "downgrade")
            if [ "$FORCE_UPDATE" = "true" ]; then
                print_warning "Downgrading: $CURRENT_VERSION → $update_version"
                update_needed=true
            else
                print_error "Target version $update_version is older than current $CURRENT_VERSION"
                print_info "Use --force to downgrade anyway"
                exit 1
            fi
            ;;
        "same")
            if [ "$FORCE_UPDATE" = "true" ]; then
                print_info "Reinstalling current version: $CURRENT_VERSION"
                update_needed=true
            else
                print_success "Already up to date (version $CURRENT_VERSION)"
                exit 0
            fi
            ;;
    esac
    
    if [ "$update_needed" = "false" ]; then
        print_success "No update needed"
        exit 0
    fi
    
    # Perform update
    print_header "Performing Update"
    
    local update_dir="/tmp/nas-monitor-update-$$"
    
    # Create backup
    create_backup
    
    # Download update
    if download_update "$update_dir" "$update_version"; then
        # Install update
        if install_update "$update_dir"; then
            print_success "Update completed successfully"
            print_info "Updated from $CURRENT_VERSION to $update_version"
        else
            print_error "Update installation failed"
            exit 1
        fi
    else
        print_error "Update download failed"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$update_dir"
    
    print_header "Update Complete"
    print_success "NAS Monitor has been updated to version $update_version"
    
    if [ "$AUTO_RESTART_SERVICE" = "true" ]; then
        print_info "Service has been restarted"
    else
        print_info "Remember to restart the service: systemctl --user restart nas-monitor.service"
    fi
    
    log "Update completed successfully"
    exit 0
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi