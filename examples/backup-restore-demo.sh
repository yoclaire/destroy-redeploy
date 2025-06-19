#!/bin/bash
#
# Example: Backup and Restore Operations
# This example demonstrates backup management and restoration
#

echo "=== Backup and Restore Example ==="
echo

# Change to the destroy-redeploy directory
cd "$(dirname "$0")/.."

echo "This example demonstrates:"
echo "1. Listing available backups"
echo "2. Creating a backup during reinstallation"
echo "3. Restoring from a backup"
echo

read -p "Press Enter to continue or Ctrl+C to cancel..."
echo

# Step 1: List current backups
echo "Step 1: List current backups"
echo "Command: ./destroy-redeploy.sh --list-backups"
echo
./destroy-redeploy.sh --list-backups

echo
echo "========================================="
echo

# Step 2: Show how backup is created during reinstallation
echo "Step 2: Demonstrate backup creation (dry-run)"
echo "During normal operation, backups are created automatically."
echo "Let's see what would be backed up for Chrome:"
echo
echo "Command: ./destroy-redeploy.sh chrome --dry-run --verbose"
echo
./destroy-redeploy.sh chrome --dry-run --verbose

echo
echo "========================================="
echo

# Step 3: Demonstrate restore functionality
echo "Step 3: Interactive restore mode"
echo "This will show you available backups and allow restoration."
echo "Command: ./destroy-redeploy.sh --restore"
echo

read -p "Do you want to try the interactive restore mode? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./destroy-redeploy.sh --restore
else
    echo "Skipping interactive restore mode."
fi

echo
echo "=== Additional Restore Examples ==="
echo
echo "Other useful restore commands:"
echo
echo "• List backups for specific app:"
echo "  ./scripts/destroy-redeploy-chrome.sh --list-backups"
echo
echo "• Restore from specific backup path:"
echo "  ./destroy-redeploy.sh --restore ~/.destroy-redeploy-backups/Google_Chrome-2024-06-18_14-30-25"
echo
echo "• Application-specific restore:"
echo "  ./scripts/destroy-redeploy-chrome.sh --restore"
echo
echo "=== Backup Management Tips ==="
echo
echo "• Backups are stored in: ~/.destroy-redeploy-backups/"
echo "• Old backups are automatically cleaned after 30 days"
echo "• Each backup includes:"
echo "  - Complete application bundle"
echo "  - User preferences and data"
echo "  - Backup metadata and timestamp"
echo
echo "• To manually backup without reinstalling:"
echo "  cp -R '/Applications/Google Chrome.app' ~/manual-backup/"
