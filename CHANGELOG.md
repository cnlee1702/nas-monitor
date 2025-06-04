# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure for open source release
- Comprehensive documentation and contributing guidelines
- Desktop integration with .desktop files
- Automated testing framework

### Changed
- Improved error handling and logging
- Enhanced configuration validation
- Better systemd integration

## [1.0.0] - 2025-06-04

### Added
- **Power-aware NAS monitoring** with intelligent battery management
- **Network detection** for automatic home/away network switching
- **Multiple NAS support** with configurable SMB/CIFS shares
- **GTK3 configuration GUI** for easy setup and management
- **systemd user service** integration with proper logging
- **Desktop credential integration** using GNOME keyring
- **Laptop-optimized behavior** for suspend/resume and network transitions

### Features
- **Adaptive check intervals** based on power source and network location
- **Battery level awareness** with configurable thresholds
- **Desktop notifications** for mount/unmount events
- **Comprehensive logging** with rotation and filtering
- **Configuration validation** with helpful error messages
- **Service management** integration with systemd

### Power Management
- 15-second intervals on AC power at home
- 60-second intervals on battery at home
- 3-minute intervals on AC power when away
- 10-minute intervals on battery when away
- Extended intervals on low battery (<20%)
- Suspended operations on critical battery (<10%)

### Security
- Configuration files with restrictive permissions (600)
- Integration with system credential storage
- No plaintext password storage
- User-space operation with minimal privileges

### Compatibility
- **Linux distributions**: Ubuntu, Debian, Linux Mint, Fedora, Arch Linux
- **Desktop environments**: GNOME, Cinnamon, XFCE, KDE
- **Network managers**: NetworkManager, systemd-networkd
- **File systems**: SMB/CIFS, NFS (future)

### Installation
- Simple `make install` build system
- Automatic dependency checking
- Desktop integration with application menu
- Service auto-start configuration

## Development History

### Pre-release Development
- Concept development for laptop-friendly NAS monitoring
- Power management research and implementation
- GUI framework selection and development
- systemd integration and testing
- Multi-distribution compatibility testing

---

## Release Notes

### Version 1.0.0 Notes

This is the initial stable release of NAS Monitor. The project has been extensively tested on:

- **Ubuntu 22.04 LTS** with GNOME and Cinnamon
- **Linux Mint 21** with Cinnamon
- **Fedora 38** with GNOME
- **Arch Linux** with various desktop environments

### Known Issues
- GUI may not immediately reflect network changes on some systems
- Very slow networks may timeout during initial mount attempts
- Some older SMB servers may require additional configuration

### Migration from Beta
If you were using pre-release versions:
1. Stop the old service: `systemctl --user stop nas-monitor`
2. Remove old files: `rm ~/.local/bin/nas-monitor-old`
3. Install new version: `make install`
4. Update configuration if needed
5. Enable new service: `make enable-service`

### Upgrade Path
Future versions will include automatic configuration migration and in-place upgrades.