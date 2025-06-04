# Contributing to NAS Monitor

Thank you for your interest in contributing to NAS Monitor! This document provides guidelines for contributing to this project.

## Code of Conduct

This project adheres to a code of conduct adapted from the [Contributor Covenant](https://www.contributor-covenant.org/). By participating, you are expected to uphold this code.

### Our Standards

- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers learn and contribute
- Prioritize the community's best interests

## How to Contribute

### Reporting Bugs

Before creating a bug report, please:

1. **Search existing issues** to avoid duplicates
2. **Use the latest version** to ensure the bug hasn't been fixed
3. **Gather system information**:
   - Linux distribution and version
   - Desktop environment
   - systemd version
   - Network configuration

**Good bug reports include:**

- Clear, descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- Log output (`journalctl --user -u nas-monitor.service`)
- System information
- Configuration file (sanitized)

### Suggesting Features

Feature requests should:

- **Check existing issues** for similar requests
- **Explain the use case** - why would this be useful?
- **Consider alternatives** - are there existing ways to achieve this?
- **Think about scope** - does this fit the project's goals?

### Pull Requests

#### Before You Start

1. **Open an issue** to discuss significant changes
2. **Check the roadmap** to avoid conflicting work
3. **Fork the repository** and create a feature branch

#### Development Process

1. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/descriptive-name
   ```

2. **Make focused commits** with clear messages:
   ```bash
   git commit -m "Add battery level threshold configuration
   
   - Adds min_battery_level setting to config
   - Updates GUI with battery threshold spinner
   - Documents new setting in README"
   ```

3. **Test thoroughly**:
   ```bash
   # Build and test
   make clean && make
   make test
   
   # Manual testing
   ./test/manual-test.sh
   ```

4. **Update documentation** as needed

5. **Push and create PR**:
   ```bash
   git push origin feature/descriptive-name
   ```

#### Pull Request Guidelines

**Title and Description:**
- Clear, descriptive title
- Reference related issues (`Fixes #123`)
- Explain what changes and why
- Include testing notes

**Code Quality:**
- Follow existing code style
- Add comments for complex logic
- Include error handling
- Update tests if applicable

**Documentation:**
- Update README.md for user-facing changes
- Add comments to configuration examples
- Update man pages if applicable

## Development Setup

### Prerequisites

**Development tools:**
```bash
# Ubuntu/Debian
sudo apt install build-essential libgtk-3-dev pkg-config git shellcheck

# Fedora
sudo dnf install gcc gtk3-devel pkgconfig git ShellCheck

# Arch Linux
sudo pacman -S base-devel gtk3 pkgconf git shellcheck
```

### Building

```bash
# Clone your fork
git clone https://github.com/yourusername/nas-monitor.git
cd nas-monitor

# Build everything
make all

# Run tests
make test

# Install locally for testing
make install
```

### Testing

#### Automated Tests

```bash
# Lint shell scripts
make lint

# Run unit tests
make test

# Check for common issues
make check
```

#### Manual Testing

1. **Configuration GUI**:
   - Test all input validation
   - Verify file I/O operations
   - Check error handling

2. **Monitor Daemon**:
   - Test power source detection
   - Verify network switching
   - Check mount/unmount logic

3. **Service Integration**:
   - systemd service lifecycle
   - Log output quality
   - Restart behavior

### Code Style

#### Shell Scripts

Follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html):

```bash
# Good
if [[ -f "$config_file" ]]; then
    echo "Found config: $config_file"
fi

# Bad
if [ -f $config_file ]; then
echo "Found config: $config_file"
fi
```

**Key points:**
- Use `[[ ]]` for tests
- Quote all variables
- Use `local` for function variables
- Prefer `printf` over `echo` for complex output

#### C Code

**Formatting:**
- 4-space indentation
- Opening braces on same line
- Clear variable names
- Consistent spacing

```c
// Good
static gboolean load_config(AppData *app) {
    FILE *file = fopen(app->config.config_path, "r");
    if (!file) {
        return FALSE;
    }
    
    // Process file...
    fclose(file);
    return TRUE;
}
```

**Memory management:**
- Free all allocated memory
- Check return values
- Use RAII patterns where possible

#### Configuration Files

- Use clear, descriptive keys
- Include comments explaining options
- Group related settings
- Provide examples

## Project Structure

```
nas-monitor/
├── src/                    # Source code
│   ├── nas-monitor.sh      # Main daemon
│   └── nas-config-gui.c    # GUI application
├── config/                 # Configuration examples
│   └── config.conf.example
├── systemd/               # Service files
│   └── nas-monitor.service
├── test/                  # Test scripts
│   ├── unit-tests.sh
│   └── manual-test.sh
├── docs/                  # Documentation
│   ├── man/               # Man pages
│   └── examples/          # Usage examples
├── Makefile              # Build system
├── README.md            # Main documentation
├── CONTRIBUTING.md      # This file
├── LICENSE             # MIT License
└── CHANGELOG.md       # Version history
```

## Release Process

### Version Numbers

We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality, backwards compatible
- **PATCH**: Bug fixes, backwards compatible

### Creating Releases

1. **Update version** in relevant files
2. **Update CHANGELOG.md** with changes
3. **Create release branch**: `release/v1.2.3`
4. **Final testing** on multiple distributions
5. **Tag and release** via GitHub

## Getting Help

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Request Reviews**: Code-specific discussions

### Documentation

- **README.md**: User documentation
- **Wiki**: Extended guides and tutorials
- **Code Comments**: Implementation details
- **Man Pages**: Command reference

## Recognition

Contributors are recognized in:
- **CHANGELOG.md**: Feature and fix credits
- **README.md**: Major contributor acknowledgments
- **GitHub Contributors**: Automatic recognition

### Types of Contributions

We value all types of contributions:
- **Code**: Features, bug fixes, optimizations
- **Documentation**: Guides, examples, improvements
- **Testing**: Bug reports, compatibility testing
- **Design**: UI/UX improvements, graphics
- **Community**: Helping users, moderating discussions

Thank you for contributing to NAS Monitor!