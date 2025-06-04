# GitHub Configuration

This directory contains GitHub-specific configuration files for the NAS Monitor project.

## Issue Templates

We use structured issue templates to help gather the right information for different types of issues:

### 🐛 [Bug Reports](.github/ISSUE_TEMPLATE/bug_report.yml)
Use this template when something isn't working as expected. The template collects:
- System information (OS, desktop environment)
- NAS Monitor version and configuration
- Steps to reproduce the issue
- Service logs and status
- Expected vs actual behavior

### ✨ [Feature Requests](.github/ISSUE_TEMPLATE/feature_request.yml)
Use this template to suggest new features or enhancements. It helps us understand:
- The problem or use case you're trying to solve
- Your proposed solution
- Priority and complexity estimates
- Examples of how the feature would be used

### ❓ [Questions](.github/ISSUE_TEMPLATE/question.yml)
Use this template for usage questions or configuration help. It includes:
- Question categorization
- Current setup context
- What you've already tried
- Relevant configuration and logs

### Configuration
The [config.yml](.github/ISSUE_TEMPLATE/config.yml) file:
- Disables blank issues to encourage using templates
- Provides quick links to documentation and discussions
- Helps users find existing answers before creating new issues

## Pull Request Template

The [pull request template](.github/pull_request_template.md) ensures contributors provide:
- Clear description of changes
- Type of change (bug fix, feature, etc.)
- Testing information
- Documentation updates
- Checklist for code quality

## GitHub Actions Workflows

### 🔍 [Continuous Integration](.github/workflows/ci.yml)
Runs on every push and pull request:
- **Testing**: Unit tests, integration tests, build verification
- **Quality**: ShellCheck linting, code analysis
- **Multi-platform**: Tests on Ubuntu 20.04/22.04, Fedora, Debian
- **Performance**: Basic performance regression testing
- **Security**: File permission checks, sensitive data scanning
- **Documentation**: Validates documentation completeness

### 🚀 [Release](.github/workflows/release.yml)
Automated release process triggered by version tags:
- Creates GitHub releases with changelog
- Builds and attaches source packages
- Tests installation on multiple distributions
- Updates version references in documentation
- Notifies of success/failure

### 🛡️ [CodeQL Security](.github/workflows/codeql.yml)
Security analysis using GitHub's CodeQL:
- Scans C code and shell scripts
- Runs weekly and on main branch changes
- Identifies potential security vulnerabilities
- Integrates with GitHub Security tab

### 📦 [Dependabot](.github/dependabot.yml)
Automated dependency updates:
- Monitors GitHub Actions for updates
- Creates PRs for security and feature updates
- Runs weekly on Mondays
- Helps keep CI/CD infrastructure current

## Workflow Status

| Workflow | Status | Purpose |
|----------|--------|---------|
| CI | ![CI](https://github.com/cnlee1702/nas-monitor/workflows/Continuous%20Integration/badge.svg) | Continuous testing and quality checks |
| CodeQL | ![CodeQL](https://github.com/cnlee1702/nas-monitor/workflows/CodeQL/badge.svg) | Security vulnerability scanning |
| Release | ![Release](https://github.com/cnlee1702/nas-monitor/workflows/Release/badge.svg) | Automated release creation |

## Branch Protection

The `master` branch is protected with the following rules:
- Require pull request reviews before merging
- Require status checks to pass (CI workflow)
- Require up-to-date branches before merging
- Restrict pushes to the master branch

## Contributing Workflow

### For Bug Reports
1. Check [existing issues](https://github.com/cnlee1702/nas-monitor/issues) first
2. Read the [troubleshooting guide](../docs/troubleshooting.md)
3. Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml)
4. Include all requested information

### For Feature Requests
1. Check [existing issues](https://github.com/cnlee1702/nas-monitor/issues) and [discussions](https://github.com/cnlee1702/nas-monitor/discussions)
2. Consider starting a discussion first for large features
3. Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.yml)
4. Provide clear use cases and examples

### For Code Contributions
1. Fork the repository
2. Create a feature branch from `master`
3. Make your changes with tests
4. Ensure CI passes locally: `make test`
5. Create a pull request using the template
6. Respond to review feedback

### For Documentation
1. Documentation lives in the `docs/` directory
2. Use clear, practical examples
3. Test installation/configuration steps
4. Update relevant cross-references

## Issue Labels

### Type Labels
- `bug` - Something isn't working
- `enhancement` - New feature or improvement
- `question` - Further information requested
- `documentation` - Documentation improvements
- `duplicate` - Duplicate of existing issue
- `wontfix` - Valid issue that won't be addressed

### Priority Labels
- `critical` - Blocks basic functionality
- `high` - Important for most users
- `medium` - Useful improvement
- `low` - Nice to have

### Status Labels
- `needs-triage` - Needs initial review
- `needs-info` - Waiting for more information
- `needs-testing` - Needs testing verification
- `ready-for-review` - Ready for maintainer review
- `in-progress` - Being actively worked on

### Component Labels
- `installation` - Installation and setup issues
- `configuration` - Configuration and setup
- `power-management` - Battery and power features
- `network-detection` - Network detection logic
- `gui` - Graphical user interface
- `service` - systemd service integration
- `testing` - Test suite and CI/CD

## Release Process

### Version Numbering
We follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH` format
- Increment MAJOR for breaking changes
- Increment MINOR for new features
- Increment PATCH for bug fixes

### Creating a Release
1. Update version in relevant files
2. Update CHANGELOG.md with release notes
3. Create and push a version tag: `git tag v1.2.3`
4. GitHub Actions will automatically:
   - Create the GitHub release
   - Build source packages
   - Test installation
   - Update documentation

### Pre-release Testing
Before major releases:
1. Test on multiple distributions
2. Run full test suite
3. Update documentation
4. Create release candidate if needed

## Security

### Reporting Security Issues
- **DO NOT** create public issues for security vulnerabilities
- Email security issues to: [security contact]
- Use GitHub's private vulnerability reporting
- Allow time for fix before public disclosure

### Security Scanning
- CodeQL scans run automatically
- Dependabot monitors for vulnerable dependencies
- Manual security reviews for sensitive changes
- File permission and credential checks in CI

## Support and Community

### Getting Help
1. **Documentation**: Start with the [docs](../docs/) directory
2. **FAQ**: Check the [frequently asked questions](../docs/faq.md)
3. **Issues**: Search [existing issues](https://github.com/cnlee1702/nas-monitor/issues)
4. **Discussions**: Join [community discussions](https://github.com/cnlee1702/nas-monitor/discussions)

### Community Guidelines
- Be respectful and inclusive
- Search before posting
- Provide context and details
- Help others when you can
- Follow the [Code of Conduct](../CODE_OF_CONDUCT.md)

This GitHub configuration ensures high-quality contributions, automated testing, and a smooth development workflow for the NAS Monitor project.