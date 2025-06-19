#!/bin/bash
#
# Setup script for Destroy-Redeploy v2.0
# Makes all scripts executable and validates installation
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Destroy-Redeploy v2.0 Setup${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Project directory: $SCRIPT_DIR"

# Make all shell scripts executable
echo -e "${YELLOW}Making scripts executable...${NC}"

chmod +x "$SCRIPT_DIR/destroy-redeploy.sh"
chmod +x "$SCRIPT_DIR/scripts/destroy-redeploy-chrome.sh"
chmod +x "$SCRIPT_DIR/scripts/destroy-redeploy-zoom.sh"
chmod +x "$SCRIPT_DIR/tests/test-runner.sh"

echo -e "${GREEN}✅ Scripts made executable${NC}"

# Create backup of old scripts if they exist
if [[ -f "$SCRIPT_DIR/destroyredeploy-chrome.sh" ]] || [[ -f "$SCRIPT_DIR/destroyredeploy-zoomUS.sh" ]]; then
    echo -e "${YELLOW}Backing up old scripts...${NC}"
    
    mkdir -p "$SCRIPT_DIR/old_scripts"
    
    if [[ -f "$SCRIPT_DIR/destroyredeploy-chrome.sh" ]]; then
        mv "$SCRIPT_DIR/destroyredeploy-chrome.sh" "$SCRIPT_DIR/old_scripts/"
        echo "  • Moved destroyredeploy-chrome.sh to old_scripts/"
    fi
    
    if [[ -f "$SCRIPT_DIR/destroyredeploy-zoomUS.sh" ]]; then
        mv "$SCRIPT_DIR/destroyredeploy-zoomUS.sh" "$SCRIPT_DIR/old_scripts/"
        echo "  • Moved destroyredeploy-zoomUS.sh to old_scripts/"
    fi
    
    echo -e "${GREEN}✅ Old scripts backed up${NC}"
fi

# Run tests to validate installation
echo -e "${YELLOW}Running validation tests...${NC}"
echo

if "$SCRIPT_DIR/tests/test-runner.sh"; then
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
    echo
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  Interactive mode:    ./destroy-redeploy.sh"
    echo "  Chrome only:         ./destroy-redeploy.sh chrome"
    echo "  Dry run:             ./destroy-redeploy.sh chrome --dry-run"
    echo "  Get help:            ./destroy-redeploy.sh --help"
    echo
    echo -e "${BLUE}Documentation:${NC}"
    echo "  README.md contains comprehensive usage instructions"
    echo "  Each script has built-in help: --help"
    echo
    echo -e "${YELLOW}⚠️  Important: Always backup important data before using!${NC}"
    exit 0
else
    echo -e "${RED}❌ Validation tests failed!${NC}"
    echo "Please check the error messages above and resolve any issues."
    exit 1
fi
