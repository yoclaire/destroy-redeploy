#!/bin/bash
#
# Common functions for destroy-redeploy scripts
#

set -euo pipefail

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}
FORCE=${FORCE:-false}
BACKUP_ENABLED=${BACKUP_ENABLED:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Header
show_header() {
    cat << 'EOF'
   ---------------------------------------------------------
  |       eeeee eeee eeeee eeeee eeeee  eeeee e    e        |
  |       8   8 8    8   "   8   8   8  8  88 8    8        |
  |       8e  8 8eee 8eeee   8e  8eee8e 8   8 8eeee8        |
  |       88  8 88      88   88  88   8 8   8   88          |
  |       88ee8 88ee 8ee88   88  88   8 8eee8   88          |
  |                                                         |
  |    eeeee  eeee eeeee eeee eeeee e     eeeee e    e      |
  |    8   8  8    8   8 8    8   8 8     8  88 8    8      |
  |    8eee8e 8eee 8e  8 8eee 8eee8 8e    8   8 8eeee8      |
  |    88   8 88   88  8 88   88    88    8   8   88        |
  |    88   8 88ee 88ee8 88ee 88    88eee 8eee8   88  v2.0  |
  |                                                         |
  |                                                         |
  |  ~ update MacOS applications with extreme prejudice ~   |
  |                                                         |
  |                   github.com/0xclaire/destroy-redeploy  |
   ---------------------------------------------------------

EOF
}

# Print colored output
print_colored() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_error() {
    print_colored "$RED" "❌ ERROR: $*" >&2
}

print_warning() {
    print_colored "$YELLOW" "⚠️  WARNING: $*" >&2
}

print_success() {
    print_colored "$GREEN" "✅ $*"
}

print_info() {
    print_colored "$BLUE" "ℹ️  $*"
}

print_step() {
    print_colored "$PURPLE" "🔹 $*"
}

# Verbose logging
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_colored "$CYAN" "🔍 DEBUG: $*" >&2
    fi
}

# Check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Required command '$1' is not installed"
        return 1
    fi
    log_verbose "Command '$1' is available"
}

# Check required commands
check_requirements() {
    local required_commands=("curl" "hdiutil" "ditto" "xattr" "osascript")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    print_success "All required commands are available"
}

# Check internet connectivity
check_internet() {
    print_step "Checking internet connectivity..."
    
    if ! curl -s --head --max-time 10 "https://google.com" > /dev/null; then
        print_error "No internet connection available"
        return 1
    fi
    
    print_success "Internet connectivity confirmed"
}

# Detect Mac architecture
detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "arm64")
            print_info "Apple Silicon detected"
            echo "arm64"
            ;;
        "x86_64")
            print_info "Intel CPU detected"
            echo "intel"
            ;;
        *)
            print_error "Unknown architecture: $arch"
            return 1
            ;;
    esac
}

# Load application configuration
load_app_config() {
    local app_name="$1"
    local config_file="$PROJECT_ROOT/apps/${app_name}.conf"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    log_verbose "Loading configuration from: $config_file"
    # shellcheck source=/dev/null
    source "$config_file"
    
    # Validate required variables
    local required_vars=(
        "APP_NAME" "APP_BUNDLE" "APP_PROCESS" "INSTALLER_TYPE"
        "DOWNLOAD_URL_ARM64" "DOWNLOAD_URL_INTEL" "INSTALLER_FILE"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Required configuration variable '$var' is not set"
            return 1
        fi
    done
    
    print_success "Configuration loaded for $APP_NAME"
}

# Get download URL based on architecture
get_download_url() {
    local arch="$1"
    
    case "$arch" in
        "arm64")
            echo "$DOWNLOAD_URL_ARM64"
            ;;
        "intel")
            echo "$DOWNLOAD_URL_INTEL"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

# Check if application is running
is_app_running() {
    local app_process="$1"
    
    if pgrep -f "$app_process" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get application version
get_app_version() {
    local app_path="$1"
    
    if [[ -d "$app_path" ]]; then
        defaults read "$app_path/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown"
    else
        echo "Not installed"
    fi
}

# Cleanup function for trap
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        print_warning "Script exited with error code $exit_code"
    fi
    
    # Clean up any temporary files
    if [[ -n "${TEMP_DIR_PATH:-}" ]] && [[ -d "$TEMP_DIR_PATH" ]]; then
        log_verbose "Cleaning up temporary directory: $TEMP_DIR_PATH"
        rm -rf "$TEMP_DIR_PATH" 2>/dev/null || true
    fi
    
    log_verbose "Cleanup completed"
}

# Set up signal traps
setup_traps() {
    trap cleanup EXIT
    trap 'echo "Script interrupted by user"; exit 130' INT TERM
}

# Create temporary directory
create_temp_dir() {
    local temp_name="$1"
    TEMP_DIR_PATH="/tmp/destroy-redeploy-${temp_name}-$$"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$TEMP_DIR_PATH"
        log_verbose "Created temporary directory: $TEMP_DIR_PATH"
    else
        print_info "DRY RUN: Would create temporary directory: $TEMP_DIR_PATH"
    fi
    
    echo "$TEMP_DIR_PATH"
}

# Execute command with dry-run support
execute_command() {
    local description="$1"
    shift
    local cmd=("$@")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: $description"
        print_info "Would execute: ${cmd[*]}"
        return 0
    else
        log_verbose "Executing: ${cmd[*]}"
        "${cmd[@]}"
    fi
}

# Progress spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    local temp
    
    # Hide cursor
    tput civis 2>/dev/null || true
    
    while kill -0 "$pid" 2>/dev/null; do
        temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    
    # Show cursor
    tput cnorm 2>/dev/null || true
    printf "    \b\b\b\b"
}

# Download with progress
download_with_progress() {
    local url="$1"
    local output_path="$2"
    local description="$3"
    
    print_step "$description"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would download from $url to $output_path"
        return 0
    fi
    
    # Download in background and show progress
    curl -L --progress-bar -o "$output_path" "$url" &
    local curl_pid=$!
    
    show_spinner $curl_pid
    wait $curl_pid
    
    if [[ $? -eq 0 ]]; then
        print_success "Download completed successfully"
    else
        print_error "Download failed"
        return 1
    fi
}

# Verify file exists and is not empty
verify_file() {
    local file_path="$1"
    local description="$2"
    
    if [[ ! -f "$file_path" ]]; then
        print_error "$description not found: $file_path"
        return 1
    fi
    
    if [[ ! -s "$file_path" ]]; then
        print_error "$description is empty: $file_path"
        return 1
    fi
    
    log_verbose "$description verified: $file_path ($(du -h "$file_path" | cut -f1))"
    return 0
}

# Confirmation prompt
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$FORCE" == "true" ]]; then
        print_info "FORCE mode enabled, skipping confirmation"
        return 0
    fi
    
    local prompt="$message"
    if [[ "$default" == "y" ]]; then
        prompt="$prompt (Y/n): "
    else
        prompt="$prompt (y/N): "
    fi
    
    while true; do
        read -p "$prompt" -r response
        
        # Use default if empty response
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "$response" in
            [Yy]*)
                return 0
                ;;
            [Nn]*)
                return 1
                ;;
            *)
                print_warning "Please answer yes or no"
                ;;
        esac
    done
}

# Export functions for use in other scripts
export -f print_colored print_error print_warning print_success print_info print_step log_verbose
export -f check_command check_requirements check_internet detect_architecture
export -f load_app_config get_download_url is_app_running get_app_version
export -f cleanup setup_traps create_temp_dir execute_command show_spinner
export -f download_with_progress verify_file confirm_action
