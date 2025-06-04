# Troubleshooting Guide

This guide helps you diagnose and fix common issues with NAS Monitor.

## Quick Diagnostics

Start here for any problem:

```bash
# Check service status
systemctl --user status nas-monitor.service

# View recent logs
journalctl --user -u nas-monitor.service --since "1 hour ago"

# Test configuration GUI
nas-config-gui

# Check if config file exists
ls -la ~/.config/nas-monitor/config.conf
```

## Common Issues

### Service Won't Start

**Symptoms:**
- `systemctl --user status nas-monitor.service` shows "failed" or "inactive"
- No mounts happen automatically

**Diagnosis:**
```bash
# Check detailed error messages
journalctl --user -u nas-monitor.service --since "10 minutes ago"

# Look for specific errors:
# - "Configuration file not found"
# - "No NAS devices configured"  
# - "Permission denied"
```

**Solutions:**

**No configuration file:**
```bash
# Create default configuration
mkdir -p ~/.config/nas-monitor
nas-config-gui  # Use GUI to create config
```

**No NAS devices configured:**
```bash
# Add at least one NAS device to config
nas-config-gui
# Or edit manually:
nano ~/.config/nas-monitor/config.conf
```

**Permission issues:**
```bash
# Fix config file permissions
chmod 600 ~/.config/nas-monitor/config.conf

# Reinstall if binaries have wrong permissions
./scripts/uninstall.sh -y
./scripts/install.sh -y
```

### NAS Devices Won't Mount

**Symptoms:**
- Service is running but no mounts appear
- File manager doesn't show network drives

**Diagnosis:**
```bash
# Test manual mounting
gio mount smb://your-nas.local/share

# Check network connectivity
ping your-nas.local

# Verify current network
nmcli -t -f active,ssid dev wifi | grep '^yes'

# Check mount attempts in logs
journalctl --user -u nas-monitor.service -f
```

**Solutions:**

**Network name mismatch:**
```bash
# Get exact network name
nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2

# Update config with exact name
nas-config-gui
```

**NAS not reachable:**
```bash
# Try different hostname formats
ping nas.local
ping synology.local
ping diskstation.local

# Use IP address instead
ping 192.168.1.100  # Replace with your NAS IP
```

**Credential issues:**
```bash
# Connect manually first to save credentials
# Open file manager and connect to smb://nas.local/share
# Enter credentials and choose to save them

# Or create credential file
echo "username=your-user" > ~/.smbcredentials
echo "password=your-pass" >> ~/.smbcredentials
chmod 600 ~/.smbcredentials
```

**Wrong share name:**
```bash
# List available shares
smbclient -L //nas.local -U your-username

# Update config with correct share names
nas-config-gui
```

### High Battery Usage

**Symptoms:**
- Laptop battery drains faster than expected
- High CPU usage from nas-monitor

**Diagnosis:**
```bash
# Check current intervals
grep "interval" ~/.config/nas-monitor/config.conf

# Monitor CPU usage
top -p $(pgrep -f nas-monitor)
```

**Solutions:**

**Increase battery intervals:**
```ini
# Edit config file
[intervals]
home_battery_interval=120      # Instead of 30
away_battery_interval=600      # Instead of 180
```

**Reduce failed attempts:**
```ini
[behavior]
max_failed_attempts=2          # Instead of 5
```

**Disable notifications:**
```ini
[behavior]
enable_notifications=false
```

### Network Detection Issues

**Symptoms:**
- Wrong power intervals used
- Mounts don't happen on home network
- Service thinks you're away when you're home

**Diagnosis:**
```bash
# Check current network detection
nmcli -t -f active,ssid dev wifi | grep '^yes'

# See what NAS Monitor detects in logs
journalctl --user -u nas-monitor.service | grep -i network
```

**Solutions:**

**Network name case sensitivity:**
```bash
# Network names must match exactly
# Wrong: home_networks=my-wifi
# Right: home_networks=My-WiFi
```

**Missing ethernet detection:**
```bash
# Add empty entry for wired connections
home_networks=My-WiFi,My-5G,
#                            ^ This comma is important
```

**NetworkManager issues:**
```bash
# Install nmcli if missing
sudo apt install network-manager  # Ubuntu/Debian
sudo dnf install NetworkManager   # Fedora

# Alternative: use different network detection
# (This is automatically handled by the script)
```

### Power Management Problems

**Symptoms:**
- Service uses wrong intervals
- No power source detection
- Service stops working on battery

**Diagnosis:**
```bash
# Check if power detection tools are available
which upower
which acpi

# Test power detection
upower -i $(upower -e | grep 'BAT')
acpi -a
```

**Solutions:**

**Install power management tools:**
```bash
# Ubuntu/Debian
sudo apt install upower acpi

# Fedora
sudo dnf install upower acpi

# Arch Linux
sudo pacman -S upower acpi
```

**Battery level too restrictive:**
```ini
[behavior]
min_battery_level=5    # Instead of 20
```

### GUI Application Issues

**Symptoms:**
- `nas-config-gui` won't start
- GUI crashes or shows errors
- Can't save configuration

**Diagnosis:**
```bash
# Try running GUI from terminal to see errors
nas-config-gui

# Check if GUI binary exists
ls -la ~/.local/bin/nas-config-gui

# Test GTK dependencies
pkg-config --exists gtk+-3.0 && echo "GTK OK" || echo "GTK missing"
```

**Solutions:**

**Missing GUI binary:**
```bash
# Reinstall
make -C /path/to/nas-monitor install
```

**GTK missing:**
```bash
# Ubuntu/Debian
sudo apt install libgtk-3-0 libgtk-3-dev

# Fedora
sudo dnf install gtk3 gtk3-devel

# Arch Linux  
sudo pacman -S gtk3
```

**Display issues:**
```bash
# Make sure DISPLAY is set
echo $DISPLAY

# Try running with explicit display
DISPLAY=:0 nas-config-gui
```

## Advanced Troubleshooting

### Debugging Network Issues

**Enable detailed network logging:**
```bash
# Add debug environment variable
systemctl --user edit nas-monitor.service

# Add these lines:
[Service]
Environment=DEBUG=1
Environment=VERBOSE=1

# Restart service
systemctl --user daemon-reload
systemctl --user restart nas-monitor.service
```

**Manual network testing:**
```bash
# Test specific network commands
nmcli dev wifi list
nmcli -t -f active,ssid dev wifi

# Test alternative detection methods
iwgetid -r  # Get current SSID
iw dev wlan0 link  # Low-level WiFi info
```

### Debugging Mount Issues

**Test mount commands manually:**
```bash
# Test gio mount (what NAS Monitor uses)
gio mount smb://nas.local/share

# Test traditional mount
sudo mount -t cifs //nas.local/share /mnt/test \
  -o username=user,password=pass

# List current mounts
gio mount -l
mount | grep cifs
```

**Check SMB/CIFS services:**
```bash
# Test SMB connectivity
smbclient -L //nas.local -U username

# Test port connectivity
nc -zv nas.local 445  # SMB port
nc -zv nas.local 139  # NetBIOS port
```

### Service Management Issues

**systemd user session problems:**
```bash
# Check if user systemd is enabled
systemctl --user status

# Enable user systemd
sudo loginctl enable-linger $USER

# Check user systemd files
ls -la ~/.config/systemd/user/
```

**Service file corruption:**
```bash
# Reinstall service file
make -C /path/to/nas-monitor install-service
systemctl --user daemon-reload
```

## Log Analysis

### Understanding Log Messages

**Normal operation:**
```
Starting power-aware NAS monitor
Status: Home network, AC Power, Check interval: 15s
Successfully mounted nas.local/home
```

**Warning signs:**
```
Cannot reach nas.local (attempt 3)
Network connectivity to NAS confirmed but mount failed
Service restart due to repeated failures
```

**Error conditions:**
```
Configuration file not found
No NAS devices configured
Permission denied accessing config
```

### Log Locations

**systemd journal:**
```bash
# All logs
journalctl --user -u nas-monitor.service

# Recent logs
journalctl --user -u nas-monitor.service --since "1 hour ago"

# Follow logs in real-time
journalctl --user -u nas-monitor.service -f
```

**Application logs:**
```bash
# Check if app creates its own logs
ls -la ~/.local/share/nas-monitor.log

# Installation logs
ls -la /tmp/nas-monitor-*.log
```

## Getting Help

### Before Asking for Help

Collect this information:

```bash
# System information
uname -a
cat /etc/os-release

# NAS Monitor version
grep VERSION ~/.local/bin/nas-monitor.sh || echo "unknown"

# Service status
systemctl --user status nas-monitor.service

# Recent logs (last 50 lines)
journalctl --user -u nas-monitor.service --since "1 hour ago" --no-pager

# Configuration (remove sensitive info)
cat ~/.config/nas-monitor/config.conf | sed 's/password=.*/password=REDACTED/'

# Network status
nmcli -t -f active,ssid dev wifi | grep '^yes'
ping -c 3 your-nas.local
```

### Where to Get Help

1. **GitHub Issues**: [Project Issues Page](https://github.com/yourusername/nas-monitor/issues)
2. **Discussions**: [GitHub Discussions](https://github.com/yourusername/nas-monitor/discussions)
3. **Documentation**: Check other guides in the `docs/` folder

### Creating Good Bug Reports

Include:
- **Clear description** of the problem
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **System information** (OS, version, desktop environment)
- **Log output** (last 20-50 lines)
- **Configuration file** (with sensitive info removed)

## Recovery Procedures

### Complete Reset

If everything is broken:

```bash
# Stop and remove everything
./scripts/uninstall.sh -y -c

# Clean reinstall
./scripts/install.sh -y

# Reconfigure from scratch
nas-config-gui
```

### Configuration Reset

If just configuration is broken:

```bash
# Backup broken config
cp ~/.config/nas-monitor/config.conf ~/.config/nas-monitor/config.conf.broken

# Create fresh config
rm ~/.config/nas-monitor/config.conf
nas-config-gui

# Restart service
systemctl --user restart nas-monitor.service
```

### Service Reset

If just the service is broken:

```bash
# Reinstall service files
make -C /path/to/nas-monitor install-service

# Reset service state
systemctl --user daemon-reload
systemctl --user reset-failed nas-monitor.service
systemctl --user restart nas-monitor.service
```

## Prevention

### Regular Maintenance

```bash
# Check service health weekly
systemctl --user status nas-monitor.service

# Update when new versions are available
./scripts/update.sh --check
./scripts/update.sh --update

# Review logs occasionally
journalctl --user -u nas-monitor.service --since "1 week ago" | grep -i error
```

### Best Practices

- **Test configuration changes** before relying on them
- **Keep backups** of working configurations
- **Monitor logs** after system updates
- **Update regularly** to get bug fixes
- **Use stable network names** that don't change

Most issues are configuration-related and can be fixed by carefully checking network names, NAS hostnames, and credential setup.