# NAS Monitor Scripts

This directory contains utility scripts for installing, managing, and maintaining NAS Monitor across different environments and use cases.

## Scripts Overview

| Script | Purpose | Use Case |
|--------|---------|----------|
| **install.sh** | One-command installation | End users, fresh installations |
| **uninstall.sh** | Clean removal | System cleanup, troubleshooting |
| **deploy.sh** | Multi-system deployment | Administrators, multiple hosts |
| **update.sh** | Version management | Keeping installations current |
| **migrate.sh** | Configuration migration | Version upgrades, format changes |

## Quick Reference

### Basic Operations

```bash
# Install NAS Monitor
./scripts/install.sh

# Uninstall completely
./scripts/uninstall.sh -y -c

# Check for updates
./scripts/update.sh --check

# Update to latest version
./scripts/update.sh --update
```

### Advanced Operations

```bash
# Deploy to remote hosts
./scripts/deploy.sh --remote "user@host1,user@host2" --parallel

# Migrate configuration between versions
./scripts/migrate.sh --auto

# Force reinstall
./scripts/install.sh -y --force
```

## Script Details

### install.sh - Quick Installer

**Purpose**: Automated installation for end users with dependency management.

**Features**:
- Automatic dependency detection and installation
- System compatibility checking
- Configuration file creation
- Service setup and integration
- Desktop environment integration

**Usage Examples**:
```bash
# Interactive installation
./install.sh

# Automatic installation (no prompts)
./install.sh -y

# Install with testing
./install.sh -y -t

# Install without service auto-start
./install.sh --no-service
```

**What it does**:
1. Detects operating system and package manager
2. Checks and installs missing dependencies
3. Builds the project from source (to `build/` directory)
4. Installs binaries to `~/.local/bin/` and configuration
5. Sets up systemd user service
6. Creates desktop integration
7. Optionally runs post-installation tests

---

### uninstall.sh - Clean Removal

**Purpose**: Complete removal of NAS Monitor with safety options.

**Features**:
- Service shutdown and cleanup
- Selective file removal
- Configuration preservation options
- Process termination
- Mount cleanup assistance

**Usage Examples**:
```bash
# Interactive uninstall (preserve config)
./uninstall.sh

# Complete removal including config
./uninstall.sh -y -c

# Dry run (show what would be removed)
./uninstall.sh -n

# Force removal (skip confirmations)
./uninstall.sh -f -c
```

**Safety Features**:
- Configuration preservation by default
- Confirmation prompts for destructive operations
- Dry run mode for preview
- Backup suggestions before removal

---

### deploy.sh - Multi-System Deployment

**Purpose**: Advanced deployment for multiple systems and environments.

**Features**:
- Local and remote deployment
- SSH-based remote installation
- Configuration templating
- Parallel deployment
- Rollback capabilities
- Health checking

**Usage Examples**:
```bash
# Local deployment
./deploy.sh --local

# Deploy to single remote host
./deploy.sh --remote user@server.example.com

# Parallel deployment to multiple hosts
./deploy.sh --remote "host1,host2,host3" --parallel

# Deploy with configuration template
./deploy.sh --remote host1 --config template.conf

# Dry run deployment
./deploy.sh --remote host1 --dry-run
```

**Configuration Templates**:
Templates support variable substitution:
```ini
[networks]
home_networks=${HOSTNAME}-WiFi,${HOSTNAME}-5G

[nas_devices]
${HOST_IP}/share
```

Variables available:
- `${HOST_IP}` - Target host IP address
- `${HOSTNAME}` - Target hostname
- `${USERNAME}` - Deployment username

---

### update.sh - Version Management

**Purpose**: Handles updates, version management, and rollbacks.

**Features**:
- Multiple update sources (Git, GitHub, local)
- Version comparison and validation
- Automatic backup before updates
- Configuration preservation
- Rollback capabilities
- Health checking after updates

**Usage Examples**:
```bash
# Check for updates
./update.sh --check

# Update to latest version
./update.sh --update

# Update to specific version
./update.sh --version v1.2.0

# Force update/reinstall
./update.sh --force --update

# Rollback to previous version
./update.sh --rollback v1.1.0
```

**Update Sources**:
- **git**: Clone/pull from Git repository
- **github**: Download from GitHub releases
- **local**: Use current directory as source

---

### migrate.sh - Configuration Migration

**Purpose**: Handles configuration format changes between versions.

**Features**:
- Automatic version detection
- Multi-step migration paths
- Configuration validation
- Backup creation
- Dry run capability

**Usage Examples**:
```bash
# Auto-detect and migrate
./migrate.sh --auto

# Migrate between specific versions
./migrate.sh --from 0.9.0 --to 1.0.0

# Preview migration changes
./migrate.sh --dry-run --auto

# Migrate specific config file
./migrate.sh --config /path/to/config.conf --auto
```

**Supported Migrations**:
- **0.9.x → 1.0.0**: Configuration format changes
- **1.0.x → 1.1.0**: New power management options
- **1.1.x → 1.2.0**: Enhanced network detection settings

## Common Workflows

### Initial Installation

For new users:
```bash
# Simple installation
./scripts/install.sh -y

# Installation with immediate configuration
./scripts/install.sh -y
nas-config-gui  # Configure NAS devices
```

### System Administration

For managing multiple systems:
```bash
# Deploy to development environment
./scripts/deploy.sh --remote dev-server --config dev-template.conf

# Deploy to production (with backup)
./scripts/deploy.sh --remote "prod1,prod2,prod3" --parallel

# Update all systems
for host in host1 host2 host3; do
    ssh $host 'cd nas-monitor && ./scripts/update.sh --update'
done
```

### Version Management

For maintaining installations:
```bash
# Regular update check
./scripts/update.sh --check

# Planned upgrade
./scripts/update.sh --update
./scripts/migrate.sh --auto

# Emergency rollback
./scripts/update.sh --rollback v1.1.0
```

### Troubleshooting

For diagnosing issues:
```bash
# Clean reinstall
./scripts/uninstall.sh -y
./scripts/install.sh -y -t

# Configuration migration after manual changes
./scripts/migrate.sh --from 1.0.0 --to 1.1.0 --dry-run
./scripts/migrate.sh --from 1.0.0 --to 1.1.0
```

## Environment Variables

Scripts respect these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `NAS_MONITOR_CONFIG` | Configuration file path | `~/.config/nas-monitor/config.conf` |
| `NAS_MONITOR_LOG_LEVEL` | Script logging verbosity | `info` |
| `NAS_MONITOR_BACKUP_DIR` | Backup directory | `~/.nas-monitor-backup-*` |

## Exit Codes

All scripts use consistent exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Dependency missing |
| 4 | Network/connectivity error |
| 5 | Permission denied |

## Logging

Script operations are logged to `/tmp/nas-monitor-*.log`:

- `nas-monitor-install.log` - Installation activities
- `nas-monitor-uninstall.log` - Removal activities  
- `nas-monitor-deploy.log` - Deployment activities
- `nas-monitor-update.log` - Update activities
- `nas-monitor-migration.log` - Migration activities

## Security Considerations

### SSH Deployment

When using remote deployment:
- Use SSH key authentication rather than passwords
- Limit SSH access to deployment accounts
- Validate target hosts before deployment
- Use configuration templates to avoid exposing credentials

### File Permissions

Scripts maintain secure file permissions:
- Configuration files: `600` (user read/write only)
- Backup files: `600` (user read/write only)
- Log files: `644` (user read/write, group/other read)

### Network Access

Remote operations require:
- SSH access to target systems
- Git access for source updates (if using Git source)
- Package manager access for dependency installation

## Contributing

When modifying scripts:

1. **Maintain consistency** with existing patterns
2. **Add comprehensive logging** for troubleshooting
3. **Include help text** for all options
4. **Test on multiple distributions**
5. **Update this README** with changes

### Script Template

New scripts should follow this structure:
```bash
#!/bin/bash
# Script description
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors and logging functions
# ... (standard functions)

# Help function
show_help() { ... }

# Main functionality
main() {
    # Argument parsing
    # Validation
    # Operations
    # Cleanup
}

# Execute if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
```

## Support

For script-related issues:

1. **Check logs** in `/tmp/nas-monitor-*.log`
2. **Run with verbose** output (`-v` or `--verbose`)
3. **Try dry run** mode (`-n` or `--dry-run`) if available
4. **Verify permissions** and dependencies
5. **Review this documentation** for usage examples

## Integration with CI/CD

Scripts are designed for automation:

```yaml
# Example GitHub Actions workflow
- name: Deploy NAS Monitor
  run: |
    ./scripts/deploy.sh --remote "${{ secrets.DEPLOY_HOST }}" \
                        --ssh-key "${{ secrets.DEPLOY_KEY }}" \
                        --config production.conf
```

```bash
# Example deployment script
#!/bin/bash
set -e

# Deploy to staging
./scripts/deploy.sh --remote staging-server --config staging.conf

# Run health checks
sleep 30
ssh staging-server 'systemctl --user status nas-monitor.service'

# Deploy to production if staging succeeds
./scripts/deploy.sh --remote "prod1,prod2" --parallel --config production.conf
```