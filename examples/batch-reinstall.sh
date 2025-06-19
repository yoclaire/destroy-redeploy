#!/bin/bash
#
# Example: Batch Reinstallation with Logging
# This example shows how to reinstall multiple applications with detailed logging
#

echo "=== Batch Reinstallation Example ==="
echo

# Change to the destroy-redeploy directory
cd "$(dirname "$0")/.."

# Create a log file with timestamp
LOG_FILE="/tmp/destroy-redeploy-batch-$(date +%Y%m%d_%H%M%S).log"

echo "This example will:"
echo "1. Reinstall both Chrome and Zoom"
echo "2. Continue processing even if one fails"
echo "3. Generate detailed logs"
echo "4. Show summary at the end"
echo
echo "Log file: $LOG_FILE"
echo

read -p "Press Enter to continue or Ctrl+C to cancel..."
echo

# First, preview what would happen
echo "Step 1: Preview operations for both applications"
echo "Command: ./destroy-redeploy.sh chrome zoom --dry-run"
echo
./destroy-redeploy.sh chrome zoom --dry-run

echo
echo "========================================="
echo

# Ask if user wants to proceed
read -p "Proceed with batch reinstallation? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo
echo "Step 2: Batch reinstallation with logging"
echo "Command: ./destroy-redeploy.sh chrome zoom --continue-on-error --verbose --log-file \"$LOG_FILE\""
echo

# Perform batch reinstallation
./destroy-redeploy.sh chrome zoom --continue-on-error --verbose --log-file "$LOG_FILE"

echo
echo "=== Batch Example Completed ==="
echo
echo "Results:"
echo "• Log file saved to: $LOG_FILE"
echo "• Backups available in: ~/.destroy-redeploy-backups/"
echo
echo "To view the detailed log:"
echo "  cat \"$LOG_FILE\""
echo
echo "To list all backups:"
echo "  ./destroy-redeploy.sh --list-backups"
