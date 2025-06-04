#!/bin/bash
# NAS Monitor Migration Script
# Handles data migration between versions and configuration format changes

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MIGRATION_LOG="/tmp/nas-monitor-migration.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Migration configuration
SOURCE_VERSION=""
TARGET_VERSION=""
CONFIG_PATH="$HOME/.config/nas-monitor/config.conf"
BACKUP_CONFIG=true
DRY_RUN=false
FORCE_MIGRATION=false

# Version migration definitions
declare -A MIGRATION_FUNCTIONS

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MIGRATE] $*" | tee -a "$MIGRATION_LOG"
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
NAS Monitor Migration Script

Usage: $0 [OPTIONS]

MIGRATION OPTIONS:
  -f, --from VERSION      Source version to migrate from
  -t, --to VERSION        Target version to migrate to
  -c, --config PATH       Configuration file path (default: ~/.config/nas-monitor/config.conf)
  -a, --auto              Auto-detect versions and migrate
  -n, --dry-run          Show what would be migrated without making changes

SAFETY OPTIONS:
  --no-backup            Don't backup configuration before migration
  --force                Force migration even if risky
  -v, --verbose          Enable verbose output

GENERAL OPTIONS:
  -h, --help              Show this help message

EXAMPLES:
  $0 --auto                           # Auto-detect and migrate
  $0 --from 0.9.0 --to 1.0.0         # Migrate from specific version
  $0 --dry-run --auto                 # Preview migration changes
  $0 --config /path/to/config.conf    # Migrate specific config file

SUPPORTED MIGRATIONS:
  0.9.x → 1.0.0    Configuration format changes
  1.0.x → 1.1.0    New power management options
  1.1.x → 1.2.0    Enhanced network detection settings

EOF
}

# Version comparison utilities
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Remove 'v' prefix if present
    version1="${version1#v}"
    version2="${version2#v}"
    
    # Convert to comparable format
    local ver1=$(echo "$version1" | sed 's/[^0-9.].*//' | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    local ver2=$(echo "$version2" | sed 's/[^0-9.].*//' | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    
    if [ "$ver1" -lt "$ver2" ]; then
        echo "lt"
    elif [ "$ver1" -gt "$ver2" ]; then
        echo "gt"
    else
        echo "eq"
    fi
}

# Get current configuration version
detect_config_version() {
    print_step "Detecting configuration version..."
    
    if [ ! -f "$CONFIG_PATH" ]; then
        print_warning "Configuration file not found: $CONFIG_PATH"
        echo "none"
        return
    fi
    
    # Look for version marker in config
    local config_version
    config_version=$(grep "^# Version:" "$CONFIG_PATH" 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo "")
    
    if [ -n "$config_version" ]; then
        echo "$config_version"
        return
    fi
    
    # Detect version based on config structure
    if grep -q "^\[intervals\]" "$CONFIG_PATH" && grep -q "home_ac_interval" "$CONFIG_PATH"; then
        if grep -q "min_battery_level" "$CONFIG_PATH"; then
            echo "1.0.0"
        else
            echo "0.9.0"
        fi
    elif grep -q "^\[networks\]" "$CONFIG_PATH"; then
        echo "0.8.0"
    else
        echo "unknown"
    fi
}

# Get target version from installation
detect_target_version() {
    print_step "Detecting target version..."
    
    local daemon_script="$HOME/.local/bin/nas-monitor.sh"
    if [ -f "$daemon_script" ]; then
        # Try to extract version from script
        local version
        version=$(grep -o "VERSION=[\"']\?[^\"']*[\"']\?" "$daemon_script" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
        
        if [ -n "$version" ]; then
            echo "$version"
        else
            echo "1.0.0"  # Default assumption
        fi
    else
        echo "1.0.0"  # Default
    fi
}

# Backup configuration
backup_configuration() {
    if [ "$BACKUP_CONFIG" != "true" ]; then
        return 0
    fi
    
    print_step "Creating configuration backup..."
    
    if [ ! -f "$CONFIG_PATH" ]; then
        print_warning "No configuration file to backup"
        return 0
    fi
    
    local backup_path="${CONFIG_PATH}.backup-$(date +%Y%m%d_%H%M%S)"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_dry_run "Would backup $CONFIG_PATH to $backup_path"
    else
        cp "$CONFIG_PATH" "$backup_path"
        print_success "Configuration backed up to $backup_path"
    fi
}

# Migration: 0.9.x → 1.0.0
migrate_0_9_to_1_0() {
    print_step "Migrating configuration from 0.9.x to 1.0.0..."
    
    local temp_config="/tmp/nas-monitor-migrate-$$"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_dry_run "Would add [behavior] section with default values"
        print_dry_run "Would add version marker to configuration"
        return 0
    fi
    
    # Read existing configuration
    cp "$CONFIG_PATH" "$temp_config"
    
    # Add behavior section if not present
    if ! grep -q "^\[behavior\]" "$temp_config"; then
        cat >> "$temp_config" << 'EOF'

[behavior]
# Maximum failed connection attempts before backing off
max_failed_attempts=3
# Minimum battery level (%) to attempt network operations
min_battery_level=10
# Enable desktop notifications for mount/unmount events
enable_notifications=true
EOF
        print_success "Added [behavior] section with default values"
    fi
    
    # Add version marker
    {
        echo "# NAS Monitor Configuration"
        echo "# Version: 1.0.0"
        echo "# Migrated on: $(date)"
        echo ""
        grep -v "^# NAS Monitor Configuration" "$temp_config" || cat "$temp_config"
    } > "${temp_config}.new"
    
    mv "${temp_config}.new" "$CONFIG_PATH"
    rm -f "$temp_config"
    
    print_success "Migration to 1.0.0 completed"
}

# Migration: 1.0.x → 1.1.0
migrate_1_0_to_1_1() {
    print_step "Migrating configuration from 1.0.x to 1.1.0..."
    
    local temp_config="/tmp/nas-monitor-migrate-$$"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_dry_run "Would add enhanced power management options"
        print_dry_run "Would update version marker to 1.1.0"
        return 0
    fi
    
    cp "$CONFIG_PATH" "$temp_config"
    
    # Update intervals section with new options
    if grep -q "^\[intervals\]" "$temp_config"; then
        # Add new power-aware intervals if not present
        if ! grep -q "power_check_interval" "$temp_config"; then
            sed -i '/^\[intervals\]/a\
# Power source check interval (seconds)\
power_check_interval=30\
# Battery level check interval (seconds)\
battery_check_interval=60' "$temp_config"
            print_success "Added enhanced power management intervals"
        fi
    fi
    
    # Update behavior section
    if grep -q "^\[behavior\]" "$temp_config"; then
        # Add suspend/resume handling
        if ! grep -q "handle_suspend_resume" "$temp_config"; then
            sed -i '/^\[behavior\]/a\
# Handle system suspend/resume events\
handle_suspend_resume=true\
# Delay after resume before checking mounts (seconds)\
resume_delay=30' "$temp_config"
            print_success "Added suspend/resume handling options"
        fi
    fi
    
    # Update version marker
    sed -i 's/^# Version:.*/# Version: 1.1.0/' "$temp_config"
    sed -i "s/^# Migrated on:.*/# Migrated on: $(date)/" "$temp_config"
    
    mv "$temp_config" "$CONFIG_PATH"
    
    print_success "Migration to 1.1.0 completed"
}

# Migration: 1.1.x → 1.2.0
migrate_1_1_to_1_2() {
    print_step "Migrating configuration from 1.1.x to 1.2.0..."
    
    local temp_config="/tmp/nas-monitor-migrate-$$"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_dry_run "Would add network detection enhancements"
        print_dry_run "Would add logging configuration options"
        print_dry_run "Would update version marker to 1.2.0"
        return 0
    fi
    
    cp "$CONFIG_PATH" "$temp_config"
    
    # Add network detection section
    if ! grep -q "^\[network_detection\]" "$temp_config"; then
        cat >> "$temp_config" << 'EOF'

[network_detection]
# Network detection method: auto, nmcli, iw, manual
detection_method=auto
# Network change detection interval (seconds)
network_check_interval=30
# VPN detection and handling
detect_vpn=true
# Trusted network patterns (regex)
trusted_network_patterns=.*
EOF
        print_success "Added [network_detection] section"
    fi
    
    # Add logging section
    if ! grep -q "^\[logging\]" "$temp_config"; then
        cat >> "$temp_config" << 'EOF'

[logging]
# Log level: debug, info, warning, error
log_level=info
# Maximum log file size (MB)
max_log_size=10
# Number of log files to keep
log_rotation_count=5
# Log to systemd journal
use_systemd_journal=true
EOF
        print_success "Added [logging] section"
    fi
    
    # Update version marker
    sed -i 's/^# Version:.*/# Version: 1.2.0/' "$temp_config"
    sed -i "s/^# Migrated on:.*/# Migrated on: $(date)/" "$temp_config"
    
    mv "$temp_config" "$CONFIG_PATH"
    
    print_success "Migration to 1.2.0 completed"
}

# Register migration functions
register_migrations() {
    MIGRATION_FUNCTIONS["0.9->1.0"]="migrate_0_9_to_1_0"
    MIGRATION_FUNCTIONS["1.0->1.1"]="migrate_1_0_to_1_1"
    MIGRATION_FUNCTIONS["1.1->1.2"]="migrate_1_1_to_1_2"
}

# Find migration path
find_migration_path() {
    local from_version="$1"
    local to_version="$2"
    
    # Remove 'v' prefix and extract major.minor
    from_version="${from_version#v}"
    to_version="${to_version#v}"
    
    local from_major_minor=$(echo "$from_version" | cut -d'.' -f1-2)
    local to_major_minor=$(echo "$to_version" | cut -d'.' -f1-2)
    
    local migration_path=()
    
    # Define migration sequence
    local migration_sequence=("0.9" "1.0" "1.1" "1.2")
    
    local start_idx=-1
    local end_idx=-1
    
    # Find start and end indices
    for i in "${!migration_sequence[@]}"; do
        if [ "${migration_sequence[$i]}" = "$from_major_minor" ]; then
            start_idx=$i
        fi
        if [ "${migration_sequence[$i]}" = "$to_major_minor" ]; then
            end_idx=$i
        fi
    done
    
    if [ $start_idx -eq -1 ]; then
        print_error "Unknown source version: $from_version"
        return 1
    fi
    
    if [ $end_idx -eq -1 ]; then
        print_error "Unknown target version: $to_version"
        return 1
    fi
    
    if [ $start_idx -ge $end_idx ]; then
        print_info "No migration needed (same or newer version)"
        return 0
    fi
    
    # Build migration path
    for ((i=start_idx; i<end_idx; i++)); do
        local from_ver="${migration_sequence[$i]}"
        local to_ver="${migration_sequence[$((i+1))]}"
        migration_path+=("$from_ver->$to_ver")
    done
    
    printf '%s\n' "${migration_path[@]}"
}

# Execute migration
execute_migration() {
    local from_version="$1"
    local to_version="$2"
    
    print_header "Executing Migration: $from_version → $to_version"
    
    # Find migration path
    local migration_steps
    mapfile -t migration_steps < <(find_migration_path "$from_version" "$to_version")
    
    if [ ${#migration_steps[@]} -eq 0 ]; then
        print_info "No migration steps required"
        return 0
    fi
    
    print_info "Migration path: ${migration_steps[*]}"
    
    # Create backup
    backup_configuration
    
    # Execute each migration step
    for step in "${migration_steps[@]}"; do
        if [ -n "${MIGRATION_FUNCTIONS[$step]:-}" ]; then
            print_step "Executing migration step: $step"
            if ${MIGRATION_FUNCTIONS[$step]}; then
                print_success "Migration step $step completed"
            else
                print_error "Migration step $step failed"
                return 1
            fi
        else
            print_error "No migration function found for step: $step"
            return 1
        fi
    done
    
    print_success "All migration steps completed"
}

# Validate configuration after migration
validate_configuration() {
    print_step "Validating migrated configuration..."
    
    if [ ! -f "$CONFIG_PATH" ]; then
        print_error "Configuration file missing after migration"
        return 1
    fi
    
    # Basic syntax validation
    local validation_errors=()
    
    # Check for required sections
    local required_sections=("networks" "nas_devices" "intervals" "behavior")
    for section in "${required_sections[@]}"; do
        if ! grep -q "^\[$section\]" "$CONFIG_PATH"; then
            validation_errors+=("Missing section: [$section]")
        fi
    done
    
    # Check for required settings in intervals
    local required_intervals=("home_ac_interval" "home_battery_interval" "away_ac_interval" "away_battery_interval")
    for interval in "${required_intervals[@]}"; do
        if ! grep -q "^$interval=" "$CONFIG_PATH"; then
            validation_errors+=("Missing interval setting: $interval")
        fi
    done
    
    # Report validation results
    if [ ${#validation_errors[@]} -eq 0 ]; then
        print_success "Configuration validation passed"
        return 0
    else
        print_error "Configuration validation failed:"
        for error in "${validation_errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# Main migration process
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--from)
                SOURCE_VERSION="$2"
                shift 2
                ;;
            -t|--to)
                TARGET_VERSION="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_PATH="$2"
                shift 2
                ;;
            -a|--auto)
                # Auto-detect will be handled later
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-backup)
                BACKUP_CONFIG=false
                shift
                ;;
            --force)
                FORCE_MIGRATION=true
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
    
    # Initialize
    echo "NAS Monitor Migration - $(date)" > "$MIGRATION_LOG"
    register_migrations
    
    # Auto-detect versions if not specified
    if [ -z "$SOURCE_VERSION" ]; then
        SOURCE_VERSION=$(detect_config_version)
        print_info "Auto-detected source version: $SOURCE_VERSION"
    fi
    
    if [ -z "$TARGET_VERSION" ]; then
        TARGET_VERSION=$(detect_target_version)
        print_info "Auto-detected target version: $TARGET_VERSION"
    fi
    
    # Show header
    print_header "NAS Monitor Configuration Migration"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}DRY RUN MODE - No changes will be made${NC}"
    fi
    
    echo -e "${CYAN}Configuration file: $CONFIG_PATH${NC}"
    echo -e "${CYAN}Source version: $SOURCE_VERSION${NC}"
    echo -e "${CYAN}Target version: $TARGET_VERSION${NC}"
    echo
    
    # Check if migration is needed
    if [ "$SOURCE_VERSION" = "none" ]; then
        print_error "No configuration file found to migrate"
        exit 1
    fi
    
    if [ "$SOURCE_VERSION" = "unknown" ]; then
        if [ "$FORCE_MIGRATION" != "true" ]; then
            print_error "Cannot determine source version"
            print_info "Use --force to attempt migration anyway"
            exit 1
        else
            print_warning "Proceeding with unknown source version"
        fi
    fi
    
    # Compare versions
    local comparison
    comparison=$(version_compare "$SOURCE_VERSION" "$TARGET_VERSION")
    
    case "$comparison" in
        "eq")
            print_success "Configuration is already at target version"
            exit 0
            ;;
        "gt")
            if [ "$FORCE_MIGRATION" != "true" ]; then
                print_error "Source version is newer than target version"
                print_info "Use --force to attempt downgrade (not recommended)"
                exit 1
            else
                print_warning "Attempting downgrade migration"
            fi
            ;;
        "lt")
            print_info "Migration needed: upgrade from $SOURCE_VERSION to $TARGET_VERSION"
            ;;
    esac
    
    # Execute migration
    if execute_migration "$SOURCE_VERSION" "$TARGET_VERSION"; then
        if [ "$DRY_RUN" != "true" ]; then
            # Validate result
            if validate_configuration; then
                print_header "Migration Completed Successfully"
                print_success "Configuration migrated from $SOURCE_VERSION to $TARGET_VERSION"
                
                if [ "$BACKUP_CONFIG" = "true" ]; then
                    print_info "Original configuration backed up"
                fi
                
                print_info "You may need to restart the NAS Monitor service:"
                print_info "  systemctl --user restart nas-monitor.service"
            else
                print_error "Migration completed but validation failed"
                exit 1
            fi
        else
            print_header "Dry Run Completed"
            print_info "Migration preview completed successfully"
            print_info "Run without --dry-run to perform actual migration"
        fi
    else
        print_error "Migration failed"
        exit 1
    fi
    
    log "Migration process completed"
    exit 0
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi