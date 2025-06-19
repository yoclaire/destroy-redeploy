#!/bin/bash
#
# Example: Basic Chrome Reinstallation
# This example shows the most common usage pattern
#

echo "=== Basic Chrome Reinstallation Example ==="
echo

# Change to the destroy-redeploy directory
cd "$(dirname "$0")/.."

echo "This example will:"
echo "1. Show you what would happen (dry-run mode)"
echo "2. Ask for confirmation before proceeding"
echo "3. Reinstall Chrome with all safety features enabled"
echo

read -p "Press Enter to continue or Ctrl+C to cancel..."
echo

# First, show what would happen
echo "Step 1: Preview the operation (dry-run mode)"
echo "Command: ./destroy-redeploy.sh chrome --dry-run"
echo
./destroy-redeploy.sh chrome --dry-run

echo
echo "========================================="
echo

# Ask if user wants to proceed
read -p "Do you want to proceed with the actual reinstallation? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo
echo "Step 2: Perform the actual reinstallation"
echo "Command: ./destroy-redeploy.sh chrome --verbose"
echo

# Perform the actual reinstallation with verbose output
./destroy-redeploy.sh chrome --verbose

echo
echo "=== Example completed ==="
echo "Chrome has been reinstalled with a fresh copy."
echo "Your backup is available in ~/.destroy-redeploy-backups/"
