# Destroy-Redeploy v2.0

> **⚠️ WARNING: This tool completely removes and reinstalls macOS applications. Use with caution.**

A comprehensive collection of shell scripts to forcefully reinstall macOS applications when they become corrupted, unresponsive, or need a completely fresh installation. Now with enhanced safety features, automatic backups, and error handling.

## 🎯 What It Does

**Destroy-Redeploy** safely performs the nuclear option for problematic macOS applications:

1. **🛑 Quit** the target application completely (with active process detection)
2. **💾 Backup** the application and user data automatically
3. **🔥 Remove** the app bundle entirely from `/Applications`
4. **⬇️ Download** the latest version from official sources
5. **📦 Install** the fresh copy with proper permissions
6. **🧹 Clean up** temporary files and remove quarantine attributes
7. **🔄 Rollback** automatically if installation fails

## 🚀 New in v2.0

- **🛡️ Comprehensive Safety System**: Automatic backups, confirmation prompts, and rollback capabilities
- **📊 Advanced Logging**: Structured logging with configurable levels and file output
- **🏗️ Modular Architecture**: Reusable libraries and configuration-driven approach
- **🧪 Dry-Run Mode**: Preview operations without making any changes
- **🔧 Multi-App Support**: Process multiple applications in batch operations
- **📱 Interactive Mode**: User-friendly menus and guided workflows
- **🏥 Health Checks**: System requirements and safety validation
- **📈 Progress Indicators**: Real-time feedback during operations

## 📋 Supported Applications

| Application | Key | Architecture Support | Special Features |
|-------------|-----|---------------------|------------------|
| **Google Chrome** | `chrome` | Intel + Apple Silicon | Profile backup, extension preservation |
| **Zoom** | `zoom` | Intel + Apple Silicon | Meeting detection, audio driver handling |

*More applications coming soon! Easy to extend with configuration files.*

## 🔧 Requirements

- **macOS 10.15+** (tested on Big Sur, Monterey, Ventura, Sonoma)
- **Administrator privileges** (for installation and system-level cleanup)
- **Internet connection** (for downloading latest versions)
- **Built-in tools**: `curl`, `hdiutil`, `ditto`, `xattr` (included with macOS)

## 📥 Installation

### Quick Install
```bash
# Clone the repository
git clone https://github.com/0xclaire/destroy-redeploy.git
cd destroy-redeploy

# Make scripts executable
chmod +x destroy-redeploy.sh
chmod +x scripts/*.sh
chmod +x tests/test-runner.sh

# Run tests to verify installation
./tests/test-runner.sh
```

### Manual Install
1. Download and extract the project
2. Make all shell scripts executable: `find . -name "*.sh" -exec chmod +x {} \;`
3. Verify installation: `./tests/test-runner.sh`

## 🎮 Usage

### Interactive Mode (Recommended for beginners)
```bash
./destroy-redeploy.sh
```
- Presents a friendly menu to select applications
- Guides you through safety confirmations
- Shows progress and provides helpful feedback

### Command Line Mode (Power users)
```bash
# Single application
./destroy-redeploy.sh chrome

# Multiple applications
./destroy-redeploy.sh chrome zoom

# All supported applications
./destroy-redeploy.sh all

# With options
./destroy-redeploy.sh chrome --force --verbose --log-file /tmp/chrome-reinstall.log
```

### Dry Run (Preview mode)
```bash
# See what would happen without making changes
./destroy-redeploy.sh chrome --dry-run
```

### Individual App Scripts
```bash
# Use application-specific scripts directly
./scripts/destroy-redeploy-chrome.sh --help
./scripts/destroy-redeploy-zoom.sh --verify-launch
```

## 🛡️ Safety Features

### Automatic Backups
- **Application Bundle**: Complete copy of the `.app` package
- **User Data**: Preferences, caches, and application support files
- **Metadata**: Backup info with timestamps and system details
- **Retention**: Automatic cleanup of backups older than 30 days

**Backup Location**: `~/.destroy-redeploy-backups/`

### Safety Checks
- ✅ **Disk Space**: Ensures adequate free space (min. 1GB)
- ✅ **Running Processes**: Detects and handles active applications
- ✅ **Active Meetings**: Special handling for Zoom meetings
- ✅ **User Confirmation**: Multiple confirmation prompts
- ✅ **Network Connectivity**: Verifies internet before downloading
- ✅ **Architecture Detection**: Automatically selects correct installer

### Error Handling
- 🔄 **Automatic Rollback**: Restores from backup if installation fails
- 🔁 **Retry Logic**: Network operations retry with exponential backoff
- 📝 **Detailed Logging**: Comprehensive logs for troubleshooting
- 🚨 **Graceful Failures**: Clean exit with helpful error messages

## 📊 Command Line Options

### Global Options
| Option | Description |
|--------|-------------|
| `--dry-run` | Preview operations without making changes |
| `--force` | Skip confirmation prompts |
| `--no-backup` | Disable automatic backup creation |
| `--verbose` | Enable detailed logging output |
| `--log-file FILE` | Write logs to specified file |
| `--allow-root` | Allow running as root user |
| `--verify-launch` | Test application launch after installation |
| `--continue-on-error` | Continue batch operations despite failures |
| `--interactive` | Force interactive application selection |
| `--help` | Show detailed help information |

### Backup & Restore Options
| Option | Description |
|--------|-------------|
| `--restore` | Interactive restore mode |
| `--restore PATH` | Restore from specific backup |
| `--list-backups` | Show all available backups |

## 💾 Backup & Restore System

### Automatic Backups
Every destroy-redeploy operation automatically creates a timestamped backup:

```
~/.destroy-redeploy-backups/
├── Google_Chrome-2024-06-18_14-30-25/
│   ├── Google Chrome.app/          # Complete application bundle
│   ├── UserData/                   # User preferences and data
│   │   ├── Library/Application Support/Google/Chrome/
│   │   ├── Library/Caches/Google/Chrome/
│   │   └── Library/Preferences/com.google.Chrome.plist
│   └── backup_info.txt             # Backup metadata
└── Zoom-2024-06-18_13-15-42/
    ├── zoom.us.app/
    ├── UserData/
    └── backup_info.txt
```

### Manual Restore
```bash
# Interactive restore (shows available backups)
./destroy-redeploy.sh --restore

# Restore from specific backup
./destroy-redeploy.sh --restore ~/.destroy-redeploy-backups/Google_Chrome-2024-06-18_14-30-25

# List all available backups
./destroy-redeploy.sh --list-backups
```

### Restore Individual Apps
```bash
# Application-specific restore
./scripts/destroy-redeploy-chrome.sh --restore
./scripts/destroy-redeploy-zoom.sh --list-backups
```

## 🔍 When to Use Destroy-Redeploy

### ✅ Good Use Cases
- **Application crashes frequently** or won't start
- **Corrupted installation** or missing files
- **Performance issues** that persist after normal troubleshooting
- **Malware removal** (ensure clean installation)
- **Development/testing** environments requiring fresh installs
- **Extension/plugin issues** that can't be resolved normally
- **Update failures** leaving application in broken state

### ⚠️ Consider Alternatives First
- **Minor issues**: Try normal troubleshooting first
- **Data-critical applications**: Ensure you can restore important data
- **Production environments**: Schedule during maintenance windows
- **Network limitations**: Large downloads may impact other users

## 🏗️ Project Structure

```
destroy-redeploy/
├── destroy-redeploy.sh          # Main unified script
├── apps/                        # Application configurations
│   ├── chrome.conf             #   Chrome settings and URLs
│   └── zoom.conf               #   Zoom settings and URLs
├── lib/                         # Shared libraries
│   ├── common.sh               #   Core functions and utilities
│   ├── logging.sh              #   Logging and output management
│   └── safety.sh               #   Backup and safety features
├── scripts/                     # Individual application scripts
│   ├── destroy-redeploy-chrome.sh
│   └── destroy-redeploy-zoom.sh
├── tests/                       # Test suite
│   └── test-runner.sh          #   Comprehensive test validation
├── README.md                    # This documentation
├── LICENSE                      # MIT license
└── .gitignore                   # Git ignore rules
```

## 🧪 Testing

Run the comprehensive test suite to verify functionality:

```bash
# Run all tests
./tests/test-runner.sh

# Test specific functionality
./destroy-redeploy.sh --dry-run chrome  # Test Chrome workflow
./destroy-redeploy.sh --help             # Test help system
```

**Test Coverage**:
- ✅ Project structure validation
- ✅ Script executability
- ✅ Library sourcing and function availability
- ✅ Configuration loading and validation
- ✅ Dry-run mode functionality
- ✅ Help output generation
- ✅ Architecture detection
- ✅ URL validation
- ✅ Backup system operation
- ✅ Logging system functionality

## 🔧 Adding New Applications

Adding support for new applications is straightforward:

1. **Create configuration file** in `apps/myapp.conf`:
```bash
APP_NAME="My Application"
APP_BUNDLE="MyApp.app"
APP_PROCESS="MyApp"
INSTALLER_TYPE="dmg"  # or "pkg"
DOWNLOAD_URL_ARM64="https://example.com/myapp-arm64.dmg"
DOWNLOAD_URL_INTEL="https://example.com/myapp-intel.dmg"
INSTALLER_FILE="myapp.dmg"
BACKUP_DIRS=("Library/Preferences/com.example.myapp.plist")
```

2. **Create application script** in `scripts/destroy-redeploy-myapp.sh`:
```bash
#!/bin/bash
# Copy and modify from existing script
APP_CONFIG="myapp"
# ... rest of script logic
```

3. **Update main script** to recognize new application:
```bash
# Add to SUPPORTED_APPS array in destroy-redeploy.sh
["myapp"]="My Application"
```

4. **Test thoroughly** with dry-run mode before using

## 🚨 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| **"Permission denied"** | Ensure scripts are executable: `chmod +x *.sh` |
| **"No internet connection"** | Check network and firewall settings |
| **"Download failed"** | Verify URLs in configuration files |
| **"Installation requires admin"** | Run with `sudo` or ensure user has admin rights |
| **"Application won't quit"** | Check for unsaved work, force quit manually if needed |
| **"Backup failed"** | Check disk space and permissions |

### Getting Help

1. **Enable verbose mode**: `--verbose` flag for detailed output
2. **Check logs**: Use `--log-file` to capture detailed information
3. **Run tests**: `./tests/test-runner.sh` to verify installation
4. **Try dry-run**: `--dry-run` to preview operations
5. **Check backups**: `--list-backups` to see restoration options

### Debug Mode
```bash
# Maximum verbosity for troubleshooting
export DEBUG=1
export LOG_LEVEL=DEBUG
./destroy-redeploy.sh chrome --verbose --log-file /tmp/debug.log
```

## 🤝 Contributing

We welcome contributions! Here's how to help:

### Adding Applications
1. Fork the repository
2. Create application configuration and script
3. Add comprehensive tests
4. Update documentation
5. Submit pull request

### Improving Features
1. Check existing issues for ideas
2. Follow the established code patterns
3. Add appropriate error handling
4. Include tests for new functionality
5. Update documentation

### Reporting Issues
- Use the issue tracker on GitHub
- Include system information (macOS version, architecture)
- Provide log files when possible
- Include steps to reproduce the problem

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

## ⚖️ Disclaimer

**Use at your own risk.** This tool is provided "as is" without warranty of any kind. The authors are not responsible for data loss, system damage, or any other issues that may arise from using this software.

### Important Notes
- 🔒 **Always backup important data** before running
- 🧪 **Test in non-production environments** first
- 📞 **Avoid during critical work** or active meetings
- 🌐 **Ensure stable internet** for downloads
- 💾 **Verify sufficient disk space** before starting

## 🎉 Acknowledgments

- Thanks to the macOS community for troubleshooting techniques
- Inspired by the need for reliable application management tools
- Built with love for fellow Mac users who've experienced app corruption

---

**"When applications misbehave, deploy the nuclear option with confidence."** 🚀

*For more information and updates, visit: [https://github.com/0xclaire/destroy-redeploy](https://github.com/0xclaire/destroy-redeploy)*
