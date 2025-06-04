# Configuration Guide

This guide explains how to configure NAS Monitor for your specific setup.

## Configuration Overview

NAS Monitor uses a simple configuration file located at:
```
~/.config/nas-monitor/config.conf
```

You can edit this file either:
- **Using the GUI**: `nas-config-gui` (recommended for beginners)
- **Text editor**: `nano ~/.config/nas-monitor/config.conf`

## Configuration File Structure

The configuration file is organized into sections:

```ini
[networks]
# Your home network names

[nas_devices] 
# Your NAS devices

[intervals]
# How often to check for mounts

[behavior]
# General behavior settings
```

## Network Configuration

### Home Networks

Tell NAS Monitor which networks are your "home" networks where NAS devices are available:

```ini
[networks]
home_networks=MyWiFi,MyWiFi-5G,
```

**Tips:**
- Use **exact** network names (SSIDs) as they appear in your WiFi settings
- Separate multiple networks with commas
- Include an **empty entry** (trailing comma) for wired/Ethernet connections
- Network names are case-sensitive

**Examples:**
```ini
# Single network
home_networks=Home-WiFi

# Multiple networks  
home_networks=Kitchen-WiFi,Bedroom-WiFi,Office-5G

# Include ethernet (note the trailing comma)
home_networks=My-Network,My-Network-5G,

# Guest network that also has NAS access
home_networks=Main-WiFi,Guest-WiFi
```

### Finding Your Network Name

Not sure of your exact network name?

```bash
# See current WiFi network
nmcli -t -f active,ssid dev wifi | grep '^yes'

# List all available networks
nmcli dev wifi list
```

## NAS Device Configuration

### Adding NAS Devices

List your NAS devices in the format `hostname/share`:

```ini
[nas_devices]
synology.local/home
qnap-nas.local/multimedia  
backup-server.local/documents
192.168.1.100/public
```

### NAS Device Formats

**Hostname-based (recommended):**
```ini
my-nas.local/share-name
synology-ds920.local/home
```

**IP address-based:**
```ini
192.168.1.50/media
10.0.0.100/backup
```

**Custom hostnames:**
```ini
fileserver/documents
mediaserver/movies
```

### Common NAS Brands

**Synology:**
```ini
# Default hostname format: DiskStation.local or [model].local  
DiskStation.local/home
DS920Plus.local/multimedia
```

**QNAP:**
```ini
# Default hostname format: [model].local
TS-464.local/share
QNAP-NAS.local/backup
```

**TrueNAS/FreeNAS:**
```ini
truenas.local/dataset
freenas.local/media
```

**Windows/Samba shares:**
```ini
windows-pc.local/SharedFolder
server.local/public
```

### Finding Your NAS

Not sure of your NAS hostname or IP?

**Check your router's admin page** - look for connected devices

**Use network scanning:**
```bash
# Scan local network (replace with your subnet)
nmap -sn 192.168.1.0/24

# Look for SMB services
nmap -p 445 192.168.1.0/24
```

**Try common hostnames:**
```bash
ping nas.local
ping synology.local  
ping diskstation.local
ping qnap.local
```

## Power Management Settings

### Check Intervals

Configure how often NAS Monitor checks for mounts based on power and location:

```ini
[intervals]
# At home on AC power (responsive)
home_ac_interval=15

# At home on battery (balanced)  
home_battery_interval=60

# Away from home on AC power (conservative)
away_ac_interval=180

# Away from home on battery (power saving)
away_battery_interval=600
```

**Guidelines:**
- **Lower values** = more responsive, higher battery usage
- **Higher values** = better battery life, less responsive
- **Typical ranges**: 5-3600 seconds (5 seconds to 1 hour)

### Power-Aware Behavior

```ini
[behavior]
# Stop trying after this many failures
max_failed_attempts=3

# Don't try network operations below this battery level
min_battery_level=10

# Show desktop notifications
enable_notifications=true
```

## Example Configurations

### Simple Home Setup

Perfect for most users with one NAS:

```ini
[networks]
home_networks=Home-WiFi,

[nas_devices]
synology.local/home

[intervals]
home_ac_interval=30
home_battery_interval=120
away_ac_interval=300
away_battery_interval=900

[behavior]
max_failed_attempts=3
min_battery_level=15
enable_notifications=true
```

### Multiple Networks and NAS Devices

For users with complex home networks:

```ini
[networks]
home_networks=Main-WiFi,Main-5G,Office-WiFi,Guest-Network,

[nas_devices]
synology.local/home
synology.local/media
qnap.local/backup
fileserver.local/documents
192.168.1.200/public

[intervals]
home_ac_interval=15
home_battery_interval=45
away_ac_interval=120
away_battery_interval=600

[behavior]
max_failed_attempts=5
min_battery_level=10
enable_notifications=true
```

### Power-Conscious Setup

Optimized for maximum battery life:

```ini
[networks]
home_networks=Battery-Saver-WiFi,

[nas_devices]
efficient-nas.local/essential

[intervals]
home_ac_interval=60
home_battery_interval=300
away_ac_interval=600
away_battery_interval=1800

[behavior]
max_failed_attempts=2
min_battery_level=20
enable_notifications=false
```

## Advanced Configuration

### Credential Management

NAS Monitor uses your desktop's credential storage. To set up credentials:

1. **Connect manually first** using your file manager (Nautilus, Nemo, etc.)
2. **Enter credentials** when prompted
3. **Choose to save/remember** the credentials
4. **NAS Monitor will reuse** these saved credentials

Alternatively, create credential files:
```bash
# Create credential file
echo "username=myuser" > ~/.smbcredentials
echo "password=mypass" >> ~/.smbcredentials
chmod 600 ~/.smbcredentials
```

### Network-Specific Settings

You can create different configurations for different network environments by using multiple config files and switching between them.

### Testing Configuration

After making changes, test your configuration:

```bash
# Restart the service to pick up changes
systemctl --user restart nas-monitor.service

# Check service status
systemctl --user status nas-monitor.service

# Watch logs in real-time
journalctl --user -u nas-monitor.service -f

# Test manual connection
gio mount smb://your-nas.local/share
```

## Configuration Validation

### Common Mistakes

**Wrong network names:**
```ini
# Wrong (won't match)
home_networks=My WiFi

# Correct (exact match)
home_networks=My WiFi
```

**Missing shares:**
```ini  
# Wrong (no share specified)
nas_devices=synology.local

# Correct (includes share name)
nas_devices=synology.local/home
```

**Invalid intervals:**
```ini
# Wrong (too short, will drain battery)
home_battery_interval=1

# Correct (reasonable battery-friendly interval)
home_battery_interval=60
```

### Validation Commands

Check your configuration:

```bash
# Check syntax
nas-config-gui  # GUI will show any errors

# Test network detection
nmcli -t -f active,ssid dev wifi | grep '^yes'

# Test NAS connectivity
ping your-nas.local
gio mount smb://your-nas.local/share
```

## Updating Configuration

### Using the GUI

1. Run `nas-config-gui`
2. Make your changes
3. Click "Save Configuration"
4. Restart the service if prompted

### Using Text Editor

1. Edit the file: `nano ~/.config/nas-monitor/config.conf`
2. Save changes
3. Restart the service: `systemctl --user restart nas-monitor.service`

### Configuration Migration

When updating NAS Monitor versions, your configuration may need migration:

```bash
# Auto-migrate configuration format
./scripts/migrate.sh --auto

# Preview migration changes
./scripts/migrate.sh --dry-run --auto
```

## Troubleshooting Configuration

### Service Won't Start

```bash
# Check configuration syntax
journalctl --user -u nas-monitor.service --since "5 minutes ago"

# Common issues:
# - No NAS devices configured
# - Invalid configuration syntax
# - Network names don't match
```

### NAS Won't Mount

```bash
# Test manual connection first
gio mount smb://nas.local/share

# Check network name matches exactly
nmcli -t -f active,ssid dev wifi | grep '^yes'

# Verify NAS is reachable
ping nas.local
```

### High Battery Usage

```bash
# Increase battery intervals
# In config file:
home_battery_interval=120  # Instead of 30
away_battery_interval=600  # Instead of 180
```

## Next Steps

After configuring NAS Monitor:

1. **Test your setup** by moving between networks
2. **Monitor the logs** for the first few days
3. **Adjust intervals** based on your usage patterns
4. **Set up symlinks** to NAS folders for easy access

Your NAS devices will now be automatically available when you're on your home network!