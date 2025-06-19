#!/bin/bash
#
# Test Runner for Destroy-Redeploy Scripts
# Validates functionality without making destructive changes
#

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test output
print_test_header() {
    echo
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  Destroy-Redeploy Test Suite${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo
}

print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "✅ ${GREEN}PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "❌ ${RED}FAIL${NC}: $test_name"
        if [[ -n "$message" ]]; then
            echo -e "   ${YELLOW}$message${NC}"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_test_summary() {
    echo
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo "Tests Run: $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n🎉 ${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n💥 ${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Test functions
test_project_structure() {
    local test_name="Project Structure"
    
    local required_files=(
        "destroy-redeploy.sh"
        "lib/common.sh"
        "lib/logging.sh"
        "lib/safety.sh"
        "apps/chrome.conf"
        "apps/zoom.conf"
        "scripts/destroy-redeploy-chrome.sh"
        "scripts/destroy-redeploy-zoom.sh"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Missing files: ${missing_files[*]}"
    fi
}

test_script_executability() {
    local test_name="Script Executability"
    
    local scripts=(
        "destroy-redeploy.sh"
        "scripts/destroy-redeploy-chrome.sh"
        "scripts/destroy-redeploy-zoom.sh"
        "tests/test-runner.sh"
    )
    
    local non_executable=()
    
    for script in "${scripts[@]}"; do
        if [[ ! -x "$PROJECT_ROOT/$script" ]]; then
            # Try to make it executable
            chmod +x "$PROJECT_ROOT/$script" 2>/dev/null || non_executable+=("$script")
        fi
    done
    
    if [[ ${#non_executable[@]} -eq 0 ]]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Non-executable scripts: ${non_executable[*]}"
    fi
}

test_library_sourcing() {
    local test_name="Library Sourcing"
    
    # Test sourcing libraries in isolation
    local temp_script="/tmp/test_sourcing_$$"
    
    cat > "$temp_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Try to source libraries
source "lib/common.sh" || exit 1
source "lib/logging.sh" || exit 2
source "lib/safety.sh" || exit 3

# Test basic function availability
type print_info >/dev/null 2>&1 || exit 4
type log_info >/dev/null 2>&1 || exit 5
type backup_application >/dev/null 2>&1 || exit 6

echo "All libraries sourced successfully"
EOF
    
    chmod +x "$temp_script"
    
    if (cd "$PROJECT_ROOT" && "$temp_script") >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        local exit_code=$?
        local error_msg
        case $exit_code in
            1) error_msg="Failed to source common.sh" ;;
            2) error_msg="Failed to source logging.sh" ;;
            3) error_msg="Failed to source safety.sh" ;;
            4) error_msg="common.sh functions not available" ;;
            5) error_msg="logging.sh functions not available" ;;
            6) error_msg="safety.sh functions not available" ;;
            *) error_msg="Unknown error (exit code: $exit_code)" ;;
        esac
        print_test_result "$test_name" "FAIL" "$error_msg"
    fi
    
    rm -f "$temp_script"
}

test_configuration_loading() {
    local test_name="Configuration Loading"
    
    # Test loading Chrome configuration
    local temp_script="/tmp/test_config_$$"
    
    cat > "$temp_script" << 'EOF'
#!/bin/bash
set -euo pipefail

source "lib/common.sh"

# Test Chrome config
if load_app_config "chrome"; then
    # Check required variables are set
    [[ -n "${APP_NAME:-}" ]] || exit 1
    [[ -n "${APP_BUNDLE:-}" ]] || exit 2
    [[ -n "${DOWNLOAD_URL_ARM64:-}" ]] || exit 3
    [[ -n "${DOWNLOAD_URL_INTEL:-}" ]] || exit 4
    echo "Chrome config loaded successfully"
else
    exit 10
fi

# Test Zoom config
if load_app_config "zoom"; then
    [[ -n "${APP_NAME:-}" ]] || exit 5
    [[ -n "${APP_BUNDLE:-}" ]] || exit 6
    [[ -n "${DOWNLOAD_URL_ARM64:-}" ]] || exit 7
    [[ -n "${DOWNLOAD_URL_INTEL:-}" ]] || exit 8
    echo "Zoom config loaded successfully"
else
    exit 11
fi
EOF
    
    chmod +x "$temp_script"
    
    if (cd "$PROJECT_ROOT" && "$temp_script") >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        local exit_code=$?
        local error_msg
        case $exit_code in
            1-4) error_msg="Chrome config validation failed" ;;
            5-8) error_msg="Zoom config validation failed" ;;
            10) error_msg="Failed to load Chrome config" ;;
            11) error_msg="Failed to load Zoom config" ;;
            *) error_msg="Unknown error (exit code: $exit_code)" ;;
        esac
        print_test_result "$test_name" "FAIL" "$error_msg"
    fi
    
    rm -f "$temp_script"
}

test_dry_run_mode() {
    local test_name="Dry Run Mode"
    
    # Test dry run mode doesn't make changes
    local output
    output=$(cd "$PROJECT_ROOT" && ./destroy-redeploy.sh chrome --dry-run --force 2>&1) || true
    
    if echo "$output" | grep -q "DRY RUN"; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Dry run mode not working properly"
    fi
}

test_help_output() {
    local test_name="Help Output"
    
    # Test main script help
    if "$PROJECT_ROOT/destroy-redeploy.sh" --help >/dev/null 2>&1; then
        local help_works=true
    else
        local help_works=false
    fi
    
    # Test individual script help
    if "$PROJECT_ROOT/scripts/destroy-redeploy-chrome.sh" --help >/dev/null 2>&1; then
        local chrome_help_works=true
    else
        local chrome_help_works=false
    fi
    
    if [[ "$help_works" == "true" ]] && [[ "$chrome_help_works" == "true" ]]; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Help output not working"
    fi
}

test_architecture_detection() {
    local test_name="Architecture Detection"
    
    local temp_script="/tmp/test_arch_$$"
    
    cat > "$temp_script" << 'EOF'
#!/bin/bash
set -euo pipefail

source "lib/common.sh"

arch=$(detect_architecture)
if [[ "$arch" == "arm64" ]] || [[ "$arch" == "intel" ]]; then
    echo "Architecture detected: $arch"
    exit 0
else
    echo "Invalid architecture: $arch"
    exit 1
fi
EOF
    
    chmod +x "$temp_script"
    
    if (cd "$PROJECT_ROOT" && "$temp_script") >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Architecture detection failed"
    fi
    
    rm -f "$temp_script"
}

test_url_validation() {
    local test_name="URL Validation"
    
    local temp_script="/tmp/test_urls_$$"
    
    cat > "$temp_script" << 'EOF'
#!/bin/bash
set -euo pipefail

source "lib/common.sh"

# Test Chrome URLs
load_app_config "chrome"
arch=$(detect_architecture)
url=$(get_download_url "$arch")

if [[ "$url" =~ ^https?:// ]]; then
    echo "Chrome URL valid: $url"
else
    echo "Invalid Chrome URL: $url"
    exit 1
fi

# Test Zoom URLs
load_app_config "zoom"
url=$(get_download_url "$arch")

if [[ "$url" =~ ^https?:// ]]; then
    echo "Zoom URL valid: $url"
else
    echo "Invalid Zoom URL: $url"
    exit 2
fi
EOF
    
    chmod +x "$temp_script"
    
    if (cd "$PROJECT_ROOT" && "$temp_script") >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "URL validation failed"
    fi
    
    rm -f "$temp_script"
}

test_backup_system() {
    local test_name="Backup System"
    
    local temp_script="/tmp/test_backup_$$"
    local test_dir="/tmp/test_app_$$"
    
    # Create a fake application for testing
    mkdir -p "$test_dir/Test.app/Contents"
    echo "Fake app" > "$test_dir/Test.app/Contents/Info.plist"
    
    cat > "$temp_script" << EOF
#!/bin/bash
set -euo pipefail

export BACKUP_ROOT="/tmp/test_backup_$$"
export BACKUP_ENABLED=true
export DRY_RUN=false

source "lib/common.sh"
source "lib/logging.sh"
source "lib/safety.sh"

init_backup_system

# Test backup creation
if backup_application "$test_dir/Test.app" "Test App"; then
    echo "Backup created successfully"
    
    # Check if backup exists
    if ls "\$BACKUP_ROOT"/Test_App-* >/dev/null 2>&1; then
        echo "Backup files found"
        exit 0
    else
        echo "Backup files not found"
        exit 1
    fi
else
    echo "Backup creation failed"
    exit 2
fi
EOF
    
    chmod +x "$temp_script"
    
    if (cd "$PROJECT_ROOT" && "$temp_script") >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Backup system test failed"
    fi
    
    # Cleanup
    rm -f "$temp_script"
    rm -rf "$test_dir"
    rm -rf "/tmp/test_backup_$$"
}

test_logging_system() {
    local test_name="Logging System"
    
    local temp_script="/tmp/test_logging_$$"
    local test_log="/tmp/test_log_$$"
    
    cat > "$temp_script" << EOF
#!/bin/bash
set -euo pipefail

export LOG_FILE="$test_log"
export LOG_LEVEL="DEBUG"

source "lib/logging.sh"

init_logging

# Test different log levels
log_debug "Debug message"
log_info "Info message"
log_warn "Warning message"
log_error "Error message" || true

# Check if log file was created and contains messages
if [[ -f "$test_log" ]] && grep -q "Info message" "$test_log"; then
    echo "Logging system working"
    exit 0
else
    echo "Logging system failed"
    exit 1
fi
EOF
    
    chmod +x "$temp_script"
    
    if (cd "$PROJECT_ROOT" && "$temp_script") >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
    else
        print_test_result "$test_name" "FAIL" "Logging system test failed"
    fi
    
    # Cleanup
    rm -f "$temp_script" "$test_log"
}

# Main test execution
main() {
    print_test_header
    
    echo "Running tests for destroy-redeploy project..."
    echo "Project root: $PROJECT_ROOT"
    echo
    
    # Run all tests
    test_project_structure
    test_script_executability
    test_library_sourcing
    test_configuration_loading
    test_dry_run_mode
    test_help_output
    test_architecture_detection
    test_url_validation
    test_backup_system
    test_logging_system
    
    # Print summary and exit with appropriate code
    if print_test_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run tests
main "$@"
