# Documentation

Welcome to the NAS Monitor documentation! This directory contains comprehensive guides and references for installing, configuring, and using NAS Monitor.

## Getting Started

### New Users Start Here

1. **[Installation Guide](installation.md)** - Complete installation instructions
2. **[Configuration Guide](configuration.md)** - Set up your NAS devices and networks
3. **[Usage Examples](examples/usage-examples.md)** - Real-world configuration examples

### Quick Reference

- **[FAQ](faq.md)** - Frequently asked questions and common solutions
- **[Troubleshooting Guide](troubleshooting.md)** - Diagnose and fix issues

## Documentation Overview

| Document | Purpose | Audience |
|----------|---------|----------|
| [Installation Guide](installation.md) | Complete installation instructions with troubleshooting | New users, system administrators |
| [Configuration Guide](configuration.md) | Detailed configuration reference and examples | All users |
| [Usage Examples](examples/usage-examples.md) | Real-world scenarios and configurations | All users |
| [Troubleshooting Guide](troubleshooting.md) | Problem diagnosis and solutions | Users experiencing issues |
| [FAQ](faq.md) | Common questions and quick answers | All users |

## Quick Links

### Installation
- [System Requirements](installation.md#system-requirements)
- [One-Command Install](installation.md#quick-installation)
- [Manual Installation](installation.md#method-2-manual-installation)
- [Post-Installation Setup](installation.md#post-installation-setup)

### Configuration
- [Configuration File Structure](configuration.md#configuration-file-structure)
- [Network Setup](configuration.md#network-configuration)
- [NAS Device Setup](configuration.md#nas-device-configuration)
- [Power Management](configuration.md#power-management-settings)

### Common Tasks
- [Adding a NAS Device](configuration.md#adding-nas-devices)
- [Multiple Networks](configuration.md#multiple-networks-and-nas-devices)
- [Battery Optimization](configuration.md#power-conscious-setup)
- [Troubleshooting Mounts](troubleshooting.md#nas-devices-wont-mount)

## Common Use Cases

### Home Users
- **Single NAS Setup**: [Simple configuration](examples/usage-examples.md#single-nas-single-network) for one NAS device
- **Family Network**: [Multi-device setup](examples/usage-examples.md#family-setup) for shared family resources
- **Power Optimization**: [Battery-conscious](examples/usage-examples.md#maximum-battery-life) configuration for mobile use

### Power Users
- **Multiple NAS Devices**: [Complex setup](examples/usage-examples.md#multiple-nas-devices) with several storage systems
- **Multi-Location**: [Home and office](examples/usage-examples.md#multiple-locations) configuration
- **Development Environment**: [Developer-focused](examples/usage-examples.md#development-environment) setup with code repositories

### Specific Hardware
- **Synology Users**: [Synology-specific](faq.md#i-have-a-synology-nas) configuration tips
- **Multiple Brands**: [Mixed environment](examples/usage-examples.md#multiple-nas-devices) with different NAS brands
- **Custom Networks**: [Advanced networking](examples/usage-examples.md#guest-network-access) scenarios

## Troubleshooting Quick Reference

### Service Issues
- **Won't Start**: [Service startup problems](troubleshooting.md#service-wont-start)
- **High CPU/Battery**: [Performance optimization](troubleshooting.md#high-battery-usage)
- **Frequent Restarts**: [Stability issues](troubleshooting.md#service-management-issues)

### Mount Issues
- **NAS Won't Mount**: [Connection problems](troubleshooting.md#nas-devices-wont-mount)
- **Credential Errors**: [Authentication issues](troubleshooting.md#credential-issues)
- **Network Detection**: [Network recognition problems](troubleshooting.md#network-detection-issues)

### Configuration Issues
- **GUI Won't Start**: [Interface problems](troubleshooting.md#gui-application-issues)
- **Config Errors**: [Syntax and validation issues](troubleshooting.md#configuration-validation)
- **Migration Problems**: [Version upgrade issues](../scripts/README.md#migration)

## Getting Help

### Self-Help Resources
1. **Search this documentation** for your specific issue
2. **Check the [FAQ](faq.md)** for common questions
3. **Review [troubleshooting steps](troubleshooting.md)** for your symptoms
4. **Try the examples** that match your setup

### Community Support
- **GitHub Issues**: Report bugs and request features
- **GitHub Discussions**: Ask questions and share configurations
- **Project Wiki**: Community-contributed guides and tips

### Contributing to Documentation
We welcome improvements to documentation:

1. **Fix errors** - Submit corrections for outdated or incorrect information
2. **Add examples** - Share your working configurations
3. **Improve clarity** - Make instructions easier to follow
4. **Translate** - Help make documentation accessible to more users

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## Documentation Conventions

### Code Blocks
```bash
# Commands to run in terminal
systemctl --user status nas-monitor.service
```

```ini
# Configuration file examples
[networks]
home_networks=YourWiFi,
```

### File Paths
- `~/.config/nas-monitor/config.conf` - Configuration file
- `~/.local/bin/nas-monitor.sh` - Main daemon script
- `/tmp/nas-monitor-*.log` - Log files

### Placeholders
- `your-nas.local` - Replace with your actual NAS hostname
- `YourWiFi` - Replace with your actual network name
- `username` - Replace with your actual username

### Symbols
- ✓ Success/working state
- ⚠ Warning/caution required  
- ✗ Error/failure state
- ℹ Information/note

## Version Information

This documentation is for NAS Monitor v1.0.0 and later. If you're using an older version, some features may not be available.

**Last Updated**: March 2025  
**Documentation Version**: 1.0  
**Covers NAS Monitor**: v1.0.0+

## Feedback

Help us improve this documentation:

- **Found an error?** Open an issue with the "documentation" label
- **Missing information?** Request additional documentation
- **Success story?** Share your configuration in Discussions
- **Suggestion?** Propose improvements or new sections

Good documentation makes software accessible to everyone. Your feedback helps us create better guides for all users.

---

**Next Steps**: Start with the [Installation Guide](installation.md) if you haven't installed NAS Monitor yet, or jump to the [Configuration Guide](configuration.md) if you're ready to set up your NAS devices.