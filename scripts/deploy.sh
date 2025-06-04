#!/bin/bash
# NAS Monitor Deployment Script
# Advanced deployment for multiple systems, environments, and configurations

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOY_LOG="/tmp/nas-monitor-deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Deployment configuration
DEPLOYMENT_MODE="local"
TARGET_HOSTS=()
CONFIG_TEMPLATE=""
PARALLEL_DEPLOYMENT=false
ROLLBACK_ON_FAILURE=true
BACKUP_BEFORE_DEPLOY=true
HEALTH_CHECK=true
DRY_RUN=false
FORCE_DEPLOY=false

# Remote deployment settings
SSH_USER=""
SSH_KEY=""
SSH_PORT="22"
REMOTE_PATH="/tmp/nas-monitor-deploy"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEPLOY] $*" | tee -a "$DEPLOY_LOG"
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
NAS Monitor Deployment Script

Usage: $0 [OPTIONS]

DEPLOYMENT MODES:
  -l, --local             Local deployment (default)
  -r, --remote HOST[,HOST] Deploy to remote hosts via SSH
  -c, --config FILE       Use configuration template
  -p, --parallel          Deploy to multiple hosts in parallel

SSH OPTIONS:
  --ssh-user USER         SSH username (default: current user)
  --ssh-key PATH          SSH private key path
  --ssh-port PORT         SSH port (default: 22)
  --remote-path PATH      Remote deployment path

DEPLOYMENT OPTIONS:
  -f, --force             Force deployment (overwrite existing)
  -n, --dry-run          Show what would be deployed
  --no-backup            Skip backup of existing installation
  --no-rollback          Don't rollback on failure
  --no-health-check      Skip post-deployment health checks

GENERAL OPTIONS:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output

EXAMPLES:
  # Local deployment
  $0 --local

  # Remote deployment to single host
  $0 --remote user@server.example.com

  # Deploy to multiple hosts with custom config
  $0 --remote "user@host1,user@host2" --config ./my-config.conf

  # Parallel deployment with SSH key
  $0 --remote "host1,host2,host3" --parallel --ssh-key ~/.ssh/deploy_key

  # Dry run deployment
  $0 --remote host1 --dry-run

CONFIGURATION TEMPLATES:
  Configuration templates allow deploying with pre-configured settings.
  Templates use the same format as config.conf with variable substitution.

  Variables available:
    \${HOST_IP}     - Target host IP address
    \${HOSTNAME}    - Target hostname
    \${USERNAME}    - Deployment username

EOF
}

# Parse configuration template
parse_config_template() {
    local template_file="$1"
    local target_host="$2"
    local output_file="$3"
    
    if [ ! -f "$template_file" ]; then
        print_error "Configuration template not found: $template_file"
        return 1
    fi
    
    print_step "Processing configuration template for $target_host"
    
    # Extract host information
    local hostname target_ip username
    if [[ "$target_host" == *"@"* ]]; then
        username="${target_host%@*}"
        hostname="${target_host#*@}"
    else
        username="$(whoami)"
        hostname="$target_host"
    fi
    
    # Try to resolve IP
    target_ip=$(getent hosts "$hostname" 2>/dev/null | awk '{print $1}' | head -1 || echo "$hostname")
    
    # Process template with variable substitution
    sed -e "s/\${HOST_IP}/$target_ip/g" \
        -e "s/\${HOSTNAME}/$hostname/g" \
        -e "s/\${USERNAME}/$username/g" \
        "$template_file" > "$output_file"
    
    print_success "Configuration template processed"
    log "Template variables: HOST_IP=$target_ip, HOSTNAME=$hostname, USERNAME=$username"
}

# Check SSH connectivity
check_ssh_connection() {
    local target_host="$1"
    
    print_step "Testing SSH connection to $target_host"
    
    local ssh_opts=("-o" "ConnectTimeout=10" "-o" "BatchMode=yes")
    
    if [ -n "$SSH_KEY" ]; then
        ssh_opts+=("-i" "$SSH_KEY")
    fi
    
    if [ -n "$SSH_PORT" ] && [ "$SSH_PORT" != "22" ]; then
        ssh_opts+=("-p" "$SSH_PORT")
    fi
    
    if [ -n "$SSH_USER" ]; then
        target_host="$SSH_USER@$target_host"
    fi
    
    if ssh "${ssh_opts[@]}" "$target_host" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        print_success "SSH connection to $target_host successful"
        return 0
    else
        print_error "SSH connection to $target_host failed"
        return 1
    fi
}

# Create deployment package
create_deployment_package() {
    local package_dir="$1"
    
    print_step "Creating deployment package..."
    
    # Clean and create package directory
    rm -rf "$package_dir"
    mkdir -p "$package_dir"
    
    # Copy project files
    rsync -av --exclude='.git*' \
              --exclude='test/test-configs/*' \
              --exclude='dist' \
              --exclude='*.o' \
              --exclude='nas-config-gui' \
              "$PROJECT_ROOT/" "$package_dir/"
    
    # Create installation metadata
    cat > "$package_dir/deployment-info.txt" << EOF
NAS Monitor Deployment Package
==============================

Created: $(date)
Version: $(git -C "$PROJECT_ROOT" describe --tags 2>/dev/null || echo "unknown")
Commit: $(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")
Deployed by: $(whoami)@$(hostname)
Package path: $package_dir

Contents:
$(find "$package_dir" -type f | wc -l) files
$(du -sh "$package_dir" | cut -f1) total size
EOF
    
    print_success "Deployment package created: $package_dir"
}

# Deploy to local system
deploy_local() {
    print_header "Local Deployment"
    
    local package_dir="/tmp/nas-monitor-local-deploy"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}DRY RUN MODE - No actual deployment will occur${NC}"
    fi
    
    echo -e "${CYAN}Deployment mode: $DEPLOYMENT_MODE${NC}"
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        echo -e "${CYAN}Target hosts: ${TARGET_HOSTS[*]}${NC}"
        echo -e "${CYAN}Parallel deployment: $PARALLEL_DEPLOYMENT${NC}"
    fi
    
    if [ -n "$CONFIG_TEMPLATE" ]; then
        echo -e "${CYAN}Configuration template: $CONFIG_TEMPLATE${NC}"
    fi
    
    echo
    
    # Validate configuration template if provided
    if [ -n "$CONFIG_TEMPLATE" ] && [ ! -f "$CONFIG_TEMPLATE" ]; then
        print_error "Configuration template not found: $CONFIG_TEMPLATE"
        exit 1
    fi
    
    # Execute deployment based on mode
    case "$DEPLOYMENT_MODE" in
        "local")
            deploy_local
            ;;
        "remote")
            if [ ${#TARGET_HOSTS[@]} -eq 0 ]; then
                print_error "No target hosts specified for remote deployment"
                exit 1
            fi
            
            if [ "$PARALLEL_DEPLOYMENT" = "true" ] && [ ${#TARGET_HOSTS[@]} -gt 1 ]; then
                deploy_parallel "${TARGET_HOSTS[@]}"
            else
                local deployment_failed=false
                for host in "${TARGET_HOSTS[@]}"; do
                    if ! deploy_remote_host "$host"; then
                        deployment_failed=true
                        if [ "$ROLLBACK_ON_FAILURE" != "true" ]; then
                            break
                        fi
                    fi
                done
                
                if [ "$deployment_failed" = "true" ]; then
                    print_error "One or more deployments failed"
                    exit 1
                fi
            fi
            ;;
        *)
            print_error "Unknown deployment mode: $DEPLOYMENT_MODE"
            exit 1
            ;;
    esac
    
    # Success
    print_header "Deployment Complete"
    print_success "All deployments completed successfully"
    log "Deployment completed successfully"
    exit 0
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
        print_dry_run "Would create local deployment package"
        print_dry_run "Would run: make install"
        return 0
    fi
    
    # Create package
    create_deployment_package "$package_dir"
    
    # Deploy configuration if provided
    if [ -n "$CONFIG_TEMPLATE" ]; then
        local processed_config="/tmp/nas-monitor-config-processed.conf"
        parse_config_template "$CONFIG_TEMPLATE" "localhost" "$processed_config"
        
        # Deploy the processed configuration
        mkdir -p "$HOME/.config/nas-monitor"
        cp "$processed_config" "$HOME/.config/nas-monitor/config.conf"
        chmod 600 "$HOME/.config/nas-monitor/config.conf"
        print_success "Configuration deployed"
    fi
    
    # Run installation
    print_step "Running installation..."
    if make -C "$package_dir" install; then
        print_success "Local deployment completed"
    else
        print_error "Local deployment failed"
        return 1
    fi
    
    # Health check
    if [ "$HEALTH_CHECK" = "true" ]; then
        perform_health_check "local"
    fi
}

# Deploy to remote host
deploy_remote_host() {
    local target_host="$1"
    
    print_header "Remote Deployment to $target_host"
    
    # Check SSH connection
    if ! check_ssh_connection "$target_host"; then
        return 1
    fi
    
    local package_dir="/tmp/nas-monitor-remote-deploy-$$"
    local remote_package_dir="$REMOTE_PATH"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_dry_run "Would create deployment package"
        print_dry_run "Would transfer package to $target_host:$remote_package_dir"
        print_dry_run "Would execute remote installation"
        return 0
    fi
    
    # Create deployment package
    create_deployment_package "$package_dir"
    
    # Process configuration template if provided
    if [ -n "$CONFIG_TEMPLATE" ]; then
        local processed_config="$package_dir/config-processed.conf"
        parse_config_template "$CONFIG_TEMPLATE" "$target_host" "$processed_config"
    fi
    
    # Prepare SSH options
    local ssh_opts=()
    local scp_opts=()
    
    if [ -n "$SSH_KEY" ]; then
        ssh_opts+=("-i" "$SSH_KEY")
        scp_opts+=("-i" "$SSH_KEY")
    fi
    
    if [ -n "$SSH_PORT" ] && [ "$SSH_PORT" != "22" ]; then
        ssh_opts+=("-p" "$SSH_PORT")
        scp_opts+=("-P" "$SSH_PORT")
    fi
    
    local ssh_target="$target_host"
    if [ -n "$SSH_USER" ]; then
        ssh_target="$SSH_USER@$target_host"
    fi
    
    # Transfer deployment package
    print_step "Transferring deployment package to $target_host..."
    if scp "${scp_opts[@]}" -r "$package_dir" "$ssh_target:$remote_package_dir"; then
        print_success "Package transfer completed"
    else
        print_error "Package transfer failed"
        return 1
    fi
    
    # Execute remote installation
    print_step "Executing remote installation..."
    
    local remote_commands=""
    
    # Backup existing installation if requested
    if [ "$BACKUP_BEFORE_DEPLOY" = "true" ]; then
        remote_commands+="
        echo 'Creating backup...'
        backup_dir=\"\$HOME/.nas-monitor-backup-\$(date +%Y%m%d_%H%M%S)\"
        mkdir -p \"\$backup_dir\"
        [ -f \"\$HOME/.local/bin/nas-monitor.sh\" ] && cp \"\$HOME/.local/bin/nas-monitor.sh\" \"\$backup_dir/\" || true
        [ -f \"\$HOME/.config/nas-monitor/config.conf\" ] && cp \"\$HOME/.config/nas-monitor/config.conf\" \"\$backup_dir/\" || true
        "
    fi
    
    # Stop existing service
    remote_commands+="
    echo 'Stopping existing service...'
    systemctl --user stop nas-monitor.service 2>/dev/null || true
    "
    
    # Install new version
    remote_commands+="
    echo 'Installing NAS Monitor...'
    cd '$remote_package_dir'
    make install
    "
    
    # Deploy configuration if provided
    if [ -n "$CONFIG_TEMPLATE" ]; then
        remote_commands+="
        echo 'Deploying configuration...'
        mkdir -p \"\$HOME/.config/nas-monitor\"
        cp config-processed.conf \"\$HOME/.config/nas-monitor/config.conf\"
        chmod 600 \"\$HOME/.config/nas-monitor/config.conf\"
        "
    fi
    
    # Start service
    remote_commands+="
    echo 'Starting service...'
    systemctl --user daemon-reload
    systemctl --user enable nas-monitor.service
    systemctl --user start nas-monitor.service
    "
    
    # Execute commands
    if ssh "${ssh_opts[@]}" "$ssh_target" "$remote_commands"; then
        print_success "Remote installation completed"
    else
        print_error "Remote installation failed"
        
        if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
            print_step "Attempting rollback..."
            rollback_remote_deployment "$ssh_target" "${ssh_opts[@]}"
        fi
        
        return 1
    fi
    
    # Health check
    if [ "$HEALTH_CHECK" = "true" ]; then
        perform_health_check "$ssh_target" "${ssh_opts[@]}"
    fi
    
    # Cleanup remote package
    print_step "Cleaning up remote deployment files..."
    ssh "${ssh_opts[@]}" "$ssh_target" "rm -rf '$remote_package_dir'" || true
    
    # Cleanup local package
    rm -rf "$package_dir"
}

# Perform health check
perform_health_check() {
    local target="$1"
    shift
    local ssh_opts=("$@")
    
    print_step "Performing health check on $target..."
    
    local health_commands="
    # Check if binaries exist
    if [ ! -f \"\$HOME/.local/bin/nas-monitor.sh\" ]; then
        echo 'ERROR: nas-monitor.sh not found'
        exit 1
    fi
    
    if [ ! -f \"\$HOME/.local/bin/nas-config-gui\" ]; then
        echo 'ERROR: nas-config-gui not found'
        exit 1
    fi
    
    # Check service status
    if ! systemctl --user is-enabled nas-monitor.service >/dev/null 2>&1; then
        echo 'WARNING: Service not enabled'
    fi
    
    if ! systemctl --user is-active nas-monitor.service >/dev/null 2>&1; then
        echo 'WARNING: Service not running'
    else
        echo 'SUCCESS: Service is running'
    fi
    
    # Check configuration
    if [ -f \"\$HOME/.config/nas-monitor/config.conf\" ]; then
        echo 'SUCCESS: Configuration file exists'
    else
        echo 'WARNING: No configuration file found'
    fi
    
    echo 'Health check completed'
    "
    
    if [ "$target" = "local" ]; then
        eval "$health_commands"
    else
        if ssh "${ssh_opts[@]}" "$target" "$health_commands"; then
            print_success "Health check passed for $target"
        else
            print_warning "Health check issues detected for $target"
        fi
    fi
}

# Rollback remote deployment
rollback_remote_deployment() {
    local ssh_target="$1"
    shift
    local ssh_opts=("$@")
    
    print_step "Rolling back deployment on $ssh_target..."
    
    local rollback_commands="
    echo 'Rolling back deployment...'
    
    # Stop service
    systemctl --user stop nas-monitor.service 2>/dev/null || true
    systemctl --user disable nas-monitor.service 2>/dev/null || true
    
    # Find most recent backup
    backup_dir=\$(ls -1dt \$HOME/.nas-monitor-backup-* 2>/dev/null | head -1)
    
    if [ -n \"\$backup_dir\" ] && [ -d \"\$backup_dir\" ]; then
        echo \"Restoring from backup: \$backup_dir\"
        
        # Restore files
        [ -f \"\$backup_dir/nas-monitor.sh\" ] && cp \"\$backup_dir/nas-monitor.sh\" \"\$HOME/.local/bin/\" || true
        [ -f \"\$backup_dir/config.conf\" ] && cp \"\$backup_dir/config.conf\" \"\$HOME/.config/nas-monitor/\" || true
        
        # Try to restart service
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user start nas-monitor.service 2>/dev/null || true
        
        echo 'Rollback completed'
    else
        echo 'No backup found for rollback'
    fi
    "
    
    if ssh "${ssh_opts[@]}" "$ssh_target" "$rollback_commands"; then
        print_success "Rollback completed for $ssh_target"
    else
        print_error "Rollback failed for $ssh_target"
    fi
}

# Deploy to multiple hosts in parallel
deploy_parallel() {
    local hosts=("$@")
    
    print_header "Parallel Deployment to ${#hosts[@]} hosts"
    
    local pids=()
    local results=()
    
    # Start deployment jobs
    for host in "${hosts[@]}"; do
        print_step "Starting deployment to $host..."
        {
            if deploy_remote_host "$host"; then
                echo "SUCCESS:$host"
            else
                echo "FAILED:$host"
            fi
        } &
        pids+=($!)
    done
    
    # Wait for all jobs to complete
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local host=${hosts[$i]}
        
        if wait "$pid"; then
            results+=("SUCCESS:$host")
            print_success "Deployment to $host completed"
        else
            results+=("FAILED:$host")
            print_error "Deployment to $host failed"
        fi
    done
    
    # Report results
    print_header "Parallel Deployment Results"
    local success_count=0
    local failure_count=0
    
    for result in "${results[@]}"; do
        if [[ "$result" == SUCCESS:* ]]; then
            ((success_count++))
            echo -e "${GREEN}✓ ${result#SUCCESS:}${NC}"
        else
            ((failure_count++))
            echo -e "${RED}✗ ${result#FAILED:}${NC}"
        fi
    done
    
    echo
    echo "Summary: $success_count successful, $failure_count failed"
    
    return $([ $failure_count -eq 0 ] && echo 0 || echo 1)
}

# Main deployment process
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--local)
                DEPLOYMENT_MODE="local"
                shift
                ;;
            -r|--remote)
                DEPLOYMENT_MODE="remote"
                IFS=',' read -ra TARGET_HOSTS <<< "$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_TEMPLATE="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_DEPLOYMENT=true
                shift
                ;;
            --ssh-user)
                SSH_USER="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            --ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            --remote-path)
                REMOTE_PATH="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_DEPLOY=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-backup)
                BACKUP_BEFORE_DEPLOY=false
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
                shift
                ;;
            --no-health-check)
                HEALTH_CHECK=false
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
    echo "NAS Monitor Deployment - $(date)" > "$DEPLOY_LOG"
    
    # Show header
    print_header "NAS Monitor Deployment"
    
    if [ "$DRY_RUN" = "true" ]; then