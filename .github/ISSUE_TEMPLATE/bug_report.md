---
name: Bug report
about: Create a report to help us improve NAS Monitor
title: "[BUG] "
labels: bug
assignees: ''

---

## Bug Description
A clear and concise description of what the bug is.

## Steps to Reproduce
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
A clear and concise description of what you expected to happen.

## Actual Behavior
A clear and concise description of what actually happened.

## System Information
- **OS**: [e.g. Ubuntu 22.04, Linux Mint 21, Fedora 38]
- **Desktop Environment**: [e.g. GNOME, Cinnamon, KDE]
- **NAS Monitor Version**: [e.g. 1.0.0]
- **systemd Version**: [e.g. 249]
- **Network Manager**: [e.g. NetworkManager, systemd-networkd]

## Configuration
```ini
# Paste your configuration file (sanitized - remove hostnames/passwords)
[networks]
home_networks=...

[nas_devices]
...
```

## Logs
```
# Paste relevant log output:
# journalctl --user -u nas-monitor.service --since "1 hour ago"
# tail -50 ~/.local/share/nas-monitor.log
```

## Network Setup
- **NAS Type**: [e.g. Synology, QNAP, TrueNAS, Windows Share]
- **Connection Method**: [e.g. WiFi, Ethernet]
- **Network Configuration**: [e.g. DHCP, Static IP]

## Additional Context
Add any other context about the problem here, such as:
- Recent system updates
- Changes to network configuration
- Other software that might interact with network mounts

## Attempted Solutions
What have you already tried to fix this issue?

## Screenshots
If applicable, add screenshots to help explain your problem.