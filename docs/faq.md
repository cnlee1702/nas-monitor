# Frequently Asked Questions

## General Questions

### What is NAS Monitor?

NAS Monitor is a lightweight service for Linux laptops that automatically mounts your network-attached storage (NAS) devices when you're on your home network. It's power-aware, so it adjusts its behavior based on whether you're plugged in or running on battery.

### Why do I need this?

Without NAS Monitor, you have to manually mount NAS shares every time you connect to your home network. NAS Monitor automates this and makes your NAS storage seamlessly available, while being smart about battery usage when you're mobile.

### What NAS devices are supported?

Any NAS that supports SMB/CIFS shares:
- Synology DiskStation
- QNAP NAS devices
- TrueNAS/FreeNAS
- Windows shared folders
- Samba servers
- Most commercial NAS brands

### Does this work on desktop computers?

Yes, but it's designed for laptops. On desktops, the power management features just default to "AC power" behavior, and network detection becomes less relevant since desktops typically stay on one network.

## Installation Questions

### What Linux distributions are supported?

- Ubuntu 20.04 LTS and newer
- Linux Mint 20 and newer
- Debian 11 (Bullseye) and newer
- Fedora 35 and newer
- Arch Linux (current)
- openSUSE Leap 15.3 and newer

Most modern Linux distributions should work.

### Do I need root/sudo access to install?

You need sudo access to install system dependencies (like build tools and GTK libraries), but NAS Monitor itself installs to your home directory (`~/.local/`) and runs as your user.

### Can I install without the GUI?

The GUI is optional. You can skip it during installation or remove it afterward. You'll need to edit the configuration file manually with a text editor instead.

### Why does installation take so long?

The installer downloads and compiles the software from source, which can take a few minutes depending on your system. It also checks for and installs missing dependencies.

## Configuration Questions

### How do I find my NAS hostname?

Try these methods:

1. **Check your router's admin page** - look for connected devices
2. **Try common names**: `nas.local`, `synology.local`, `diskstation.local`
3. **Use your NAS's IP address** instead of hostname
4. **Check NAS documentation** - most NAS devices have default hostnames

### What if my network name has spaces or special characters?

Network names must match exactly, including spaces and case:
```ini
# Correct
home_networks=My Home WiFi

# Wrong  
home_networks=MyHomeWiFi
```

### Can I use multiple home networks?

Yes, separate them with commas:
```ini
home_networks=Home-WiFi,Home-5G,Office-WiFi,
```

The trailing comma includes wired/Ethernet connections.

### How do I handle credential authentication?

The easiest way is to connect manually first using your file manager:

1. Open file manager (Nautilus, Nemo, etc.)
2. Go to "Other Locations" or "Network"
3. Connect to `smb://your-nas.local/share`
4. Enter username/password and choose to save them
5. NAS Monitor will reuse these saved credentials

### Why does my NAS not mount even though the service is running?

Common causes:

1. **Network name mismatch** - Check that your WiFi name exactly matches the config
2. **Wrong NAS hostname** - Try `ping nas.local` to test connectivity
3. **No credentials saved** - Connect manually first to save login info
4. **Wrong share name** - Make sure the share name after the `/` is correct
5. **NAS is off or unreachable** - Check that your NAS is powered on and connected

## Power Management Questions

### How much battery does this use?

Very little. On battery, it typically checks every 1-10 minutes depending on your settings. Each check uses minimal CPU for a few milliseconds. Most users don't notice any battery impact.

### Can I make it more aggressive about saving battery?

Yes, increase the battery intervals in your config:
```ini
[intervals]
home_battery_interval=300    # 5 minutes instead of 1
away_battery_interval=1800   # 30 minutes instead of 10
```

### What happens when my battery gets very low?

By default, NAS Monitor stops all network activity when battery drops below 10%. You can adjust this:
```ini
[behavior]
min_battery_level=20  # Stop at 20% instead
```

### Does it detect when I plug/unplug power?

Yes, it automatically switches between AC and battery intervals when you plug/unplug your power adapter.

## Usage Questions

### Where do mounted NAS shares appear?

They appear in your file manager under:
- "Network" or "Other Locations" section
- The path `/run/user/$UID/gvfs/smb-share:server=nas.local,share=sharename`

### Can I create shortcuts to NAS folders?

Yes, you can create symlinks:
```bash
ln -s "/run/user/$UID/gvfs/smb-share:server=nas.local,share=documents" ~/NAS-Documents
```

Or bookmark them in your file manager.

### What happens when I leave my home network?

NAS Monitor detects you're away and:
- Switches to longer check intervals to save battery
- Leaves existing mounts in place (they'll become unavailable but won't be unmounted)
- Stops trying to mount new shares

### What happens when I return home?

NAS Monitor detects your home network and:
- Switches back to home intervals
- Attempts to remount any configured NAS shares
- Sends a notification when shares become available

### Can I manually mount/unmount shares?

Yes, NAS Monitor doesn't interfere with manual operations:
```bash
# Manual mount
gio mount smb://nas.local/share

# Manual unmount  
gio mount -u smb://nas.local/share

# List current mounts
gio mount -l
```

## Troubleshooting Questions

### How do I check if NAS Monitor is working?

```bash
# Check service status
systemctl --user status nas-monitor.service

# Check recent activity
journalctl --user -u nas-monitor.service --since "1 hour ago"

# See current mounts
gio mount -l | grep nas
```

### Why do I get "Permission denied" errors?

This usually means credential issues:

1. **Try manual connection first** - Use your file manager to connect and save credentials
2. **Check username/password** - Make sure your NAS login info is correct
3. **Check share permissions** - Ensure your user has access to the share
4. **Try different auth methods** - Some NAS devices need domain names or special settings

### The service keeps restarting or failing

Check the logs for specific errors:
```bash
journalctl --user -u nas-monitor.service --since "10 minutes ago"
```

Common causes:
- Configuration file syntax errors
- No NAS devices configured
- Network connectivity issues
- Permission problems

### How do I reset everything?

```bash
# Complete clean removal and reinstall
./scripts/uninstall.sh -y -c
./scripts/install.sh -y

# Then reconfigure
nas-config-gui
```

## Technical Questions

### How does network detection work?

NAS Monitor uses NetworkManager (nmcli) to detect the current WiFi network name. For wired connections, it assumes you're on a "home" network if you include an empty entry in your network list.

### How does power detection work?

It checks multiple sources:
1. `upower` command for AC adapter status
2. `/sys/class/power_supply/` files for power state
3. `acpi` command as fallback

### Does this work with VPNs?

It depends on your VPN setup. If the VPN changes your apparent network name or blocks access to local NAS devices, it might interfere. Most home VPNs work fine.

### Can I run multiple instances?

No, only one instance should run per user. The service prevents multiple instances from starting.

### Does this work over the internet?

No, this is designed for local network NAS access. If you need remote access to your NAS, set up VPN or use your NAS's remote access features.

## Configuration Examples

### I have a Synology NAS

```ini
[networks]
home_networks=YourWiFi,YourWiFi-5G,

[nas_devices]
diskstation.local/home
# or try: synology.local/home
# or use IP: 192.168.1.100/home
```

### I have multiple NAS devices

```ini
[networks]
home_networks=HomeWiFi,

[nas_devices]
main-nas.local/documents
main-nas.local/photos  
media-nas.local/movies
backup-nas.local/backup
```

### I want maximum battery life

```ini
[intervals]
home_ac_interval=60
home_battery_interval=300
away_ac_interval=600
away_battery_interval=1800

[behavior]
min_battery_level=25
enable_notifications=false
```

### I work from multiple locations

```ini
[networks]
home_networks=Home-WiFi,Office-WiFi,

[nas_devices]
home-nas.local/personal
office-nas.local/work
```

## Getting Help

### Where can I get support?

1. **Check the documentation** in the `docs/` folder
2. **Search existing issues** on GitHub
3. **Create a new issue** with details about your problem
4. **Join discussions** on the project's GitHub page

### What information should I include in bug reports?

- Your Linux distribution and version
- NAS Monitor version
- Configuration file (remove sensitive info)
- Service status: `systemctl --user status nas-monitor.service`
- Recent logs: `journalctl --user -u nas-monitor.service --since "1 hour ago"`
- Steps to reproduce the problem

### Can I contribute to the project?

Yes! See the CONTRIBUTING.md file for guidelines on:
- Reporting bugs
- Suggesting features
- Contributing code
- Improving documentation

The project welcomes contributions from users of all skill levels.