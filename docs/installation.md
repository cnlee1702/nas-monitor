# Installation Guide

This guide will walk you through installing NAS Monitor on your Linux system.

## Quick Installation

For most users, the one-command installation is the easiest:

```bash
./scripts/install.sh
```

This will automatically detect your system, install dependencies, and set everything up.

## System Requirements

### Supported Distributions

NAS Monitor works on most modern Linux distributions:

- **Ubuntu** 20.04 LTS or newer
- **Linux Mint** 20 or newer  
- **Debian** 11 (Bullseye) or newer
- **Fedora** 35 or newer
- **Arch Linux** (current)
- **openSUSE** Leap 15.3 or newer

### Hardware Requirements

- **RAM**: 50MB minimum, 100MB recommended
- **Storage**: 10MB for binaries, 1MB for configuration
- **CPU**: Any modern processor (very low usage)
- **Network**: WiFi or Ethernet connection

### Software Dependencies

The installer will automatically install these if missing:

#### Required
- `gcc` and build tools
- `make`
- `pkg-config`
- `systemd` (for service management)
- `gtk3-dev` (for GUI)
- `glib2` (for file operations)

#### Optional (improves functionality)
- `notify-send` (desktop notifications)
- `nmcli` (network detection)
- `upower` (battery monitoring)
- `secret-tool` (credential storage)

## Installation Methods

### Method 1: Automatic Installation (Recommended)

1. **Download or clone** the project:
   ```bash
   git clone https://github.com/yourusername/nas-monitor.git
   cd nas-monitor
   ```

2. **Run the installer**:
   ```bash
   ./scripts/install.sh
   ```

3. **Follow the prompts** to configure your system.

**What the installer does:**
- Checks your system and installs missing dependencies
- Builds the software from source
- Installs binaries to `~/.local/bin/`
- Creates a default configuration file
- Sets up the systemd user service
- Creates desktop menu entries

### Method 2: Manual Installation

If you prefer to install manually or the automatic installer doesn't work:

1. **Install dependencies** for your distribution:

   **Ubuntu/Debian:**
   ```bash
   sudo apt update
   sudo apt install build-essential libgtk-3-dev pkg-config libglib2.0-bin
   ```

   **Fedora:**
   ```bash
   sudo dnf install gcc make gtk3-devel pkgconfig glib2
   ```

   **Arch Linux:**
   ```bash
   sudo pacman -S base-devel gtk3 pkgconf glib2
   ```

2. **Build the project**:
   ```bash
   make clean
   make all
   ```

3. **Install the components**:
   ```bash
   make install
   ```

4. **Set up the service**:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable nas-monitor.service
   ```

### Method 3: Package Installation

Check if your distribution provides a package:

**Arch Linux (AUR):**
```bash
yay -S nas-monitor  # or your preferred AUR helper
```

**Other distributions:** Package submissions are in progress.

## Post-Installation Setup

### 1. Configure Your NAS Devices

After installation, you need to configure your NAS devices:

**Option A: Use the GUI (Recommended)**
```bash
nas-config-gui
```

**Option B: Edit the config file manually**
```bash
nano ~/.config/nas-monitor/config.conf
```

### 2. Set Up Network Names

Add your home WiFi network names to the configuration:

```ini
[networks]
home_networks=YourWiFi,YourWiFi-5G,
```

### 3. Add NAS Devices

Add your NAS devices in the format `hostname/share`:

```ini
[nas_devices]
synology.local/home
qnap-nas.local/multimedia
192.168.1.100/backup
```

### 4. Start the Service

Enable and start the monitoring service:

```bash
systemctl --user start nas-monitor.service
```

Check that it's running:
```bash
systemctl --user status nas-monitor.service
```

## Verification

### Check Installation

Verify that everything was installed correctly:

```bash
# Check if binaries exist
ls -la ~/.local/bin/nas-monitor.sh
ls -la ~/.local/bin/nas-config-gui

# Check service status
systemctl --user status nas-monitor.service

# Test GUI
nas-config-gui
```

### Test NAS Connection

Test that your NAS can be accessed:

```bash
# Try manual mount
gio mount smb://your-nas.local/share

# Check if it appears in file manager
# Look for network drives in your file manager
```

## Troubleshooting Installation

### Common Issues

**Build fails with "gtk+-3.0 not found":**
```bash
# Ubuntu/Debian
sudo apt install libgtk-3-dev

# Fedora  
sudo dnf install gtk3-devel

# Arch Linux
sudo pacman -S gtk3
```

**Build directory issues:**
```bash
# Clean build artifacts and rebuild
make clean
make all
```

**"systemctl --user" commands fail:**
```bash
# Enable user systemd session
sudo loginctl enable-linger $USER
# Log out and back in
```

**Permission denied errors:**
```bash
# Make sure scripts are executable
chmod +x scripts/install.sh
```

**Service fails to start:**
```bash
# Check detailed logs
journalctl --user -u nas-monitor.service -f

# Common cause: no NAS devices configured yet
# Solution: configure at least one NAS device
```

### Getting Help

If you encounter issues:

1. **Check the logs**:
   ```bash
   journalctl --user -u nas-monitor.service --since "1 hour ago"
   ```

2. **Try the test suite**:
   ```bash
   cd test/
   ./run-tests.sh --quick
   ```

3. **Reinstall cleanly**:
   ```bash
   ./scripts/uninstall.sh -y
   ./scripts/install.sh -y
   ```

4. **Ask for help**:
   - Open an issue on GitHub
   - Include your distribution, version, and error messages
   - Attach relevant log output

## Uninstallation

If you want to remove NAS Monitor:

```bash
# Remove everything including configuration
./scripts/uninstall.sh -y -c

# Or remove just the software (keep config)
./scripts/uninstall.sh -y
```

## Next Steps

After successful installation:

1. **Read the [Configuration Guide](configuration.md)** to set up your NAS devices
2. **Check the [Usage Examples](examples/)** for common scenarios
3. **Review the [Troubleshooting Guide](troubleshooting.md)** for solutions to common issues

The installation is complete! NAS Monitor will now automatically mount your NAS devices when you're on your home network and manage them intelligently based on your laptop's power status.