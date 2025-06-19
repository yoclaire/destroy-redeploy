# Examples Directory

This directory contains practical examples and templates for using the destroy-redeploy system effectively.

## 📁 Contents

### 🎯 Basic Usage Examples

#### `basic-chrome-reinstall.sh`
A simple, step-by-step example showing:
- How to preview operations with dry-run mode
- Safe Chrome reinstallation with user confirmation
- Basic workflow for new users

**Run it:**
```bash
cd examples
./basic-chrome-reinstall.sh
```

#### `batch-reinstall.sh`
Demonstrates batch processing features:
- Reinstalling multiple applications in sequence
- Using `--continue-on-error` for robust batch operations
- Detailed logging and progress tracking
- Summary reporting

**Run it:**
```bash
cd examples
./batch-reinstall.sh
```

#### `backup-restore-demo.sh`
Shows backup and restore capabilities:
- Listing available backups
- Understanding what gets backed up
- Interactive restore mode
- Manual backup management

**Run it:**
```bash
cd examples
./backup-restore-demo.sh
```

### 🔧 Configuration Templates

#### `firefox.conf.example`
Complete template for adding Firefox support:
- All required configuration variables
- Backup directory specifications
- Download URLs and installation settings
- Developer notes and best practices

**How to use:**
1. Copy to `../apps/firefox.conf`
2. Update URLs and validate settings
3. Create corresponding script in `../scripts/`
4. Add to main script's supported apps list

## 🚀 Quick Start Guide

### For New Users
1. **Start with basic example:**
   ```bash
   ./examples/basic-chrome-reinstall.sh
   ```

2. **Learn about backups:**
   ```bash
   ./examples/backup-restore-demo.sh
   ```

3. **Try batch operations:**
   ```bash
   ./examples/batch-reinstall.sh
   ```

### For Advanced Users
1. **Explore dry-run mode:**
   ```bash
   ../destroy-redeploy.sh all --dry-run --verbose
   ```

2. **Custom logging:**
   ```bash
   ../destroy-redeploy.sh chrome --log-file /tmp/custom.log --verbose
   ```

3. **Silent operation:**
   ```bash
   ../destroy-redeploy.sh zoom --force --no-backup
   ```

## 🎓 Learning Path

### Beginner → Intermediate
1. Run `basic-chrome-reinstall.sh` to understand the workflow
2. Try `backup-restore-demo.sh` to learn safety features
3. Experiment with dry-run mode: `../destroy-redeploy.sh chrome --dry-run`
4. Practice with individual scripts: `../scripts/destroy-redeploy-chrome.sh --help`

### Intermediate → Advanced
1. Use `batch-reinstall.sh` for multiple applications
2. Create custom logging setups
3. Study `firefox.conf.example` to understand configuration
4. Try force mode with backups: `--force --verbose`

### Advanced → Expert
1. Add new applications using configuration templates
2. Customize backup directories and retention policies
3. Integrate with automation systems (cron, CI/CD)
4. Contribute new features and applications

## 📚 Best Practices from Examples

### Safety First
- **Always start with dry-run mode** when learning
- **Understand what gets backed up** before proceeding
- **Test restore process** to ensure backup integrity
- **Use verbose mode** when troubleshooting

### Operational Excellence
- **Use logging** for audit trails and debugging
- **Batch operations** with `--continue-on-error` for reliability
- **Interactive mode** for guided workflows
- **Individual scripts** for application-specific needs

### Development Workflow
- **Configuration-driven** approach for new applications
- **Test thoroughly** with dry-run mode first
- **Document custom configurations** for team sharing
- **Version control** configuration changes

## 🔧 Customization Examples

### Custom Logging Setup
```bash
# Create dated log files
LOG_FILE="/var/log/destroy-redeploy-$(date +%Y%m%d).log"
../destroy-redeploy.sh chrome --log-file "$LOG_FILE" --verbose
```

### Automated Batch Processing
```bash
# Silent batch operation with logging
../destroy-redeploy.sh all \
  --force \
  --continue-on-error \
  --log-file "/tmp/batch-$(date +%s).log" \
  --verbose
```

### Application-Specific Operations
```bash
# Chrome with custom options
../scripts/destroy-redeploy-chrome.sh \
  --verify-launch \
  --verbose \
  --log-file "/tmp/chrome-specific.log"

# Zoom with meeting detection
../scripts/destroy-redeploy-zoom.sh \
  --verbose  # Will detect and warn about active meetings
```

## 🤝 Contributing Examples

Have a useful example or configuration? We'd love to include it!

### Example Submission Guidelines
1. **Clear naming** that describes the use case
2. **Comprehensive comments** explaining each step
3. **Error handling** for robust operation
4. **User-friendly output** with clear progress indication
5. **Documentation** in this README

### New Application Templates
1. **Complete configuration** with all required variables
2. **Realistic download URLs** (verify they work)
3. **Proper backup directories** for the application
4. **Developer notes** about special considerations
5. **Testing instructions** for validation

## 📞 Support

If you need help with examples:
1. **Read the main README.md** for comprehensive documentation
2. **Run examples with `--dry-run`** to understand without risk
3. **Use `--help`** on any script for detailed options
4. **Check logs** when operations fail
5. **Open an issue** for bugs or feature requests

---

**Remember:** These examples are designed to be educational. Always understand what each command does before running it, especially in production environments!
