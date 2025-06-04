# Usage Examples

This guide shows practical examples of how to use NAS Monitor in real-world scenarios.

## Basic Scenarios

### Single NAS, Single Network

**Scenario**: You have one Synology NAS on your home WiFi network.

**Configuration**:
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

**Usage**:
- When you connect to "Home-WiFi", your Synology's "home" share automatically mounts
- When on battery, checks every 2 minutes instead of 30 seconds
- When away from home, checks every 15 minutes to save battery
- Notifications tell you when NAS connects/disconnects

### Multiple NAS Devices

**Scenario**: You have a main NAS for documents and a media server for movies/music.

**Configuration**:
```ini
[networks]
home_networks=MainWiFi,MainWiFi-5G,

[nas_devices]
synology.local/documents
synology.local/photos
mediaserver.local/movies
mediaserver.local/music

[intervals]
home_ac_interval=15
home_battery_interval=60
away_ac_interval=180
away_battery_interval=600

[behavior]
max_failed_attempts=3
min_battery_level=10
enable_notifications=true
```

**Usage**:
- All four shares mount automatically when home
- Documents and photos from main NAS
- Movies and music from dedicated media server
- Fast response (15 seconds) when plugged in at home

### Home Office Setup

**Scenario**: You work from home with different networks for work and personal devices.

**Configuration**:
```ini
[networks]
home_networks=Office-WiFi,Personal-WiFi,Ethernet,

[nas_devices]
work-nas.local/projects
work-nas.local/shared
personal-nas.local/home
backup-server.local/backups

[intervals]
home_ac_interval=10
home_battery_interval=30
away_ac_interval=300
away_battery_interval=1200

[behavior]
max_failed_attempts=5
min_battery_level=20
enable_notifications=true
```

**Usage**:
- Works on both office WiFi and personal WiFi
- Includes wired connection (Ethernet entry)
- Very responsive (10 seconds) when working at desk
- Conservative battery saving when mobile

## Power Management Scenarios

### Maximum Battery Life

**Scenario**: You're frequently mobile and want maximum battery life.

**Configuration**:
```ini
[networks]
home_networks=HomeWiFi,

[nas_devices]
nas.local/essential

[intervals]
home_ac_interval=60
home_battery_interval=300
away_ac_interval=600
away_battery_interval=1800

[behavior]
max_failed_attempts=2
min_battery_level=25
enable_notifications=false
```

**Usage**:
- Only one essential NAS share to minimize activity
- Long intervals even when home (5 minutes on battery)
- Stops all activity below 25% battery
- No notifications to save power

### Performance-Focused

**Scenario**: You work primarily at a desk with AC power and want instant access.

**Configuration**:
```ini
[networks]
home_networks=DeskWiFi,DeskWiFi-5G,

[nas_devices]
fast-nas.local/work
fast-nas.local/cache
fast-nas.local/temp

[intervals]
home_ac_interval=5
home_battery_interval=30
away_ac_interval=60
away_battery_interval=300

[behavior]
max_failed_attempts=10
min_battery_level=5
enable_notifications=true
```

**Usage**:
- Very fast response (5 seconds) when at desk
- Multiple shares for different types of work
- Aggressive retry attempts for reliability
- Only battery-saves when critically low

## Network Scenarios

### Multiple Locations

**Scenario**: You work from home, office, and coffee shops with different NAS access.

**Configuration**:
```ini
[networks]
home_networks=Home-WiFi,Office-WiFi,

[nas_devices]
home-nas.local/personal
office-nas.local/work

[intervals]
home_ac_interval=20
home_battery_interval=60
away_ac_interval=300
away_battery_interval=1200

[behavior]
max_failed_attempts=3
min_battery_level=15
enable_notifications=true
```

**Usage**:
- Both home and office WiFi are "home" networks
- Different NAS devices at each location
- Conservative intervals when at coffee shops (away)
- Same power management at both locations

### Guest Network Access

**Scenario**: Your NAS is accessible from both main and guest networks.

**Configuration**:
```ini
[networks]
home_networks=MainNetwork,MainNetwork-5G,GuestNetwork,

[nas_devices]
nas.local/shared

[intervals]
home_ac_interval=30
home_battery_interval=90
away_ac_interval=300
away_battery_interval=900

[behavior]
max_failed_attempts=5
min_battery_level=10
enable_notifications=true
```

**Usage**:
- Works on both main and guest networks
- Useful when guests need NAS access too
- Same behavior regardless of which network you're on

## Special Use Cases

### Development Environment

**Scenario**: You're a developer with code repositories and build artifacts on NAS.

**Configuration**:
```ini
[networks]
home_networks=DevNetwork,

[nas_devices]
dev-nas.local/repos
dev-nas.local/builds
dev-nas.local/artifacts
backup-nas.local/backups

[intervals]
home_ac_interval=10
home_battery_interval=45
away_ac_interval=180
away_battery_interval=600

[behavior]
max_failed_attempts=5
min_battery_level=15
enable_notifications=true
```

**Usage**:
- Fast access to code repositories (10 seconds)
- Separate shares for different types of development data
- Quick response for build processes
- Backup NAS for redundancy

### Media Production

**Scenario**: You work with large video/audio files stored on high-capacity NAS.

**Configuration**:
```ini
[networks]
home_networks=StudioWiFi,Studio-Wired,

[nas_devices]
storage-nas.local/raw-footage
storage-nas.local/projects
storage-nas.local/renders
archive-nas.local/completed

[intervals]
home_ac_interval=15
home_battery_interval=120
away_ac_interval=600
away_battery_interval=1800

[behavior]
max_failed_attempts=3
min_battery_level=20
enable_notifications=true
```

**Usage**:
- Multiple shares for different stages of production
- Archive NAS for completed projects
- Longer battery intervals due to large file operations
- Higher minimum battery level for intensive work

### Family Setup

**Scenario**: Multiple family members sharing NAS resources with different access patterns.

**Configuration**:
```ini
[networks]
home_networks=FamilyWiFi,FamilyWiFi-Kids,

[nas_devices]
family-nas.local/shared
family-nas.local/photos
family-nas.local/music
family-nas.local/documents

[intervals]
home_ac_interval=30
home_battery_interval=120
away_ac_interval=300
away_battery_interval=900

[behavior]
max_failed_attempts=3
min_battery_level=10
enable_notifications=true
```

**Usage**:
- Shared resources for all family members
- Kids can access from kids-specific WiFi network
- Balanced performance for mixed usage patterns
- Notifications help troubleshoot family tech issues

## Integration Examples

### Symlinks for Easy Access

Create symlinks to mounted NAS shares for easier access:

```bash
# After NAS Monitor mounts your shares, create symlinks
ln -s /run/user/$UID/gvfs/smb-share:server=nas.local,share=documents ~/Documents/NAS
ln -s /run/user/$UID/gvfs/smb-share:server=nas.local,share=photos ~/Pictures/NAS
ln -s /run/user/$UID/gvfs/smb-share:server=nas.local,share=music ~/Music/NAS
```

### Backup Scripts

Use NAS Monitor with backup scripts that depend on NAS availability:

```bash
#!/bin/bash
# backup-script.sh

# Wait for NAS to be available
timeout=60
while [ $timeout -gt 0 ]; do
    if [ -d "/run/user/$UID/gvfs/smb-share:server=nas.local,share=backup" ]; then
        echo "NAS available, starting backup..."
        rsync -av ~/Documents/ "/run/user/$UID/gvfs/smb-share:server=nas.local,share=backup/$(hostname)/"
        break
    fi
    sleep 1
    ((timeout--))
done
```

### Application Integration

Configure applications to use NAS storage when available:

**Music Player (Rhythmbox)**:
```bash
# Add NAS music folder when mounted
if [ -d "/run/user/$UID/gvfs/smb-share:server=nas.local,share=music" ]; then
    rhythmbox-client --add-uri "file:///run/user/$UID/gvfs/smb-share:server=nas.local,share=music"
fi
```

**Photo Manager**:
```bash
# Point photo manager to NAS photos
if [ -d "/run/user/$UID/gvfs/smb-share:server=nas.local,share=photos" ]; then
    shotwell --import-dir="/run/user/$UID/gvfs/smb-share:server=nas.local,share=photos"
fi
```

## Monitoring and Maintenance

### Check Mount Status

```bash
# See what's currently mounted
gio mount -l | grep nas

# Check specific NAS
gio mount -l | grep nas.local

# See all SMB mounts
gio mount -l | grep smb
```

### Log Monitoring

```bash
# Watch for mount/unmount events
journalctl --user -u nas-monitor.service -f | grep -E "(mount|unmount)"

# Check for errors
journalctl --user -u nas-monitor.service --since "1 hour ago" | grep -i error

# See power management decisions
journalctl --user -u nas-monitor.service -f | grep -E "(battery|power|interval)"
```

### Performance Monitoring

```bash
# Check resource usage
ps aux | grep nas-monitor

# Monitor network activity
iftop -i wlan0  # Replace wlan0 with your interface

# Check battery impact
upower -i $(upower -e | grep 'BAT') | grep percentage
```

## Best Practices

### Configuration Tips

1. **Start simple** - Begin with one NAS and one network, add complexity gradually
2. **Test manually first** - Always verify you can mount manually before configuring
3. **Use descriptive names** - Name your shares clearly (documents, photos, backup)
4. **Monitor logs initially** - Watch logs for the first few days to tune intervals
5. **Backup configs** - Keep a backup of working configurations

### Usage Tips

1. **Let it stabilize** - Give NAS Monitor a few minutes to detect network changes
2. **Use file manager** - Your regular file manager will show mounted NAS shares
3. **Create bookmarks** - Bookmark frequently used NAS locations in your file manager
4. **Set up symlinks** - Create convenient symlinks to mounted shares
5. **Monitor battery** - Adjust intervals if you notice battery drain

### Troubleshooting Tips

1. **Check network names** - Ensure network names match exactly (case-sensitive)
2. **Test connectivity** - Use `ping nas.local` to verify basic connectivity
3. **Manual mount first** - Always test manual mounting before troubleshooting
4. **Check credentials** - Ensure you've saved credentials in your desktop environment
5. **Review logs** - Most issues are logged and can be diagnosed from journal output

These examples should cover most common use cases. Adapt the configurations to match your specific NAS devices, network setup, and usage patterns.