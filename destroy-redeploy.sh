#!/bin/bash
#
# Unified Destroy-Redeploy Script v2.0
# Multi-application reinstaller with safety features
#

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Source required libraries
# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
# shellcheck source=lib/logging.sh
source "$PROJECT_ROOT/lib/logging.sh"
# shellcheck source=lib/safety.sh
source "$PROJECT_ROOT/lib/safety.sh"

# Supported applications
declare -A SUPPORTED_APPS=(
    ["chrome"]="Google Chrome"
    ["zoom"]="Zoom"
)

# Show main application menu
show_app_menu() {
    echo
    print_info "Supported Applications:"
    echo
    
    local count=1
    for app_key in "${!SUPPORTED_APPS[@]}"; do
        printf "%2d. %s (%s)\n" "$count" "${SUPPORTED_APPS[$app_key]}" "$app_key"
        count=$((count + 1))
    done
    
    echo
    printf "%2d. All applications\n" "$count"
    echo
}

# Select application interactively
select_application() {
    while true; do
        show_app_menu
        
        local app_keys=($(printf '%s\n' "${!SUPPORTED_APPS[@]}" | sort))
        local max_option=$((${#app_keys[@]} + 1))
        
        read -p "Select application (1-$max_option) or 'q' to quit: " -r selection
        
        if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
            print_info "Operation cancelled by user"
            exit 0
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $max_option ]]; then
            if [[ $selection -eq $max_option ]]; then
                echo "all"
                return 0
            else
                local selected_app="${app_keys[$((selection - 1))]}"
                echo "$selected_app"
                return 0
            fi
        else
            print_warning "Invalid selection. Please enter a number between 1 and $max_option"
        fi
    done
}

# Validate application name
validate_app() {
    local app="$1"
    
    if [[ "$app" == "all" ]]; then
        return 0
    fi
    
    if [[ -n "${SUPPORTED_APPS[$app]:-}" ]]; then
        return 0
    else
        print_error "Unsupported application: $app"
        print_info "Supported applications: ${!SUPPORTED_APPS[*]}"
        return 1
    fi
}

# Execute application-specific script
execute_app_script() {
    local app="$1"
    shift
    local args=("$@")
    
    local app_script="$PROJECT_ROOT/scripts/destroy-redeploy-${app}.sh"
    
    if [[ ! -f "$app_script" ]]; then
        print_error "Application script not found: $app_script"
        return 1
    fi
    
    if [[ ! -x "$app_script" ]]; then
        print_warning "Making script executable: $app_script"
        chmod +x "$app_script"
    fi
    
    print_info "Executing ${SUPPORTED_APPS[$app]} destroy-redeploy..."
    log_info "Running script: $app_script ${args[*]}"
    
    # Execute the application-specific script
    if "$app_script" "${args[@]}"; then
        print_success "${SUPPORTED_APPS[$app]} destroy-redeploy completed successfully"
        return 0
    else
        local exit_code=$?
        print_error "${SUPPORTED_APPS[$app]} destroy-redeploy failed (exit code: $exit_code)"
        return $exit_code
    fi
}

# Process multiple applications
process_multiple_apps() {
    local apps=("$@")
    local failed_apps=()
    local successful_apps=()
    local total_apps=${#apps[@]}
    local current_app=0
    
    print_info "Processing $total_apps applications: ${apps[*]}"
    
    for app in "${apps[@]}"; do
        current_app=$((current_app + 1))
        
        echo
        print_step "[$current_app/$total_apps] Processing ${SUPPORTED_APPS[$app]}..."
        
        if execute_app_script "$app" "${SCRIPT_ARGS[@]}"; then
            successful_apps+=("$app")
        else
            failed_apps+=("$app")
            
            if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
                print_error "Stopping due to failure in ${SUPPORTED_APPS[$app]}"
                break
            else
                print_warning "Continuing despite failure in ${SUPPORTED_APPS[$app]}"
            fi
        fi
    done
    
    # Summary
    echo
    print_info "=== SUMMARY ==="
    
    if [[ ${#successful_apps[@]} -gt 0 ]]; then
        print_success "Successful applications:"
        for app in "${successful_apps[@]}"; do
            echo "  ✅ ${SUPPORTED_APPS[$app]}"
        done
    fi
    
    if [[ ${#failed_apps[@]} -gt 0 ]]; then
        print_error "Failed applications:"
        for app in "${failed_apps[@]}"; do
            echo "  ❌ ${SUPPORTED_APPS[$app]}"
        done
        return 1
    fi
    
    return 0
}

# List available backups for all applications
list_all_backups() {
    print_info "Available backups for all applications:"
    echo
    
    local found_backups=false
    
    for app_key in "${!SUPPORTED_APPS[@]}"; do
        local app_name="${SUPPORTED_APPS[$app_key]}"
        
        print_step "$app_name backups:"
        
        if list_backups "$app_name" 2>/dev/null; then
            found_backups=true
        else
            print_info "  No backups found"
        fi
        
        echo
    done
    
    if [[ "$found_backups" == "false" ]]; then
        print_warning "No backups found for any application"
        return 1
    fi
    
    return 0
}

# Interactive restore mode
interactive_restore() {
    print_info "Interactive Restore Mode"
    echo
    
    # Select application
    print_step "Select application to restore:"
    show_app_menu
    
    local app_keys=($(printf '%s\n' "${!SUPPORTED_APPS[@]}" | sort))
    local max_option=${#app_keys[@]}
    
    while true; do
        read -p "Select application (1-$max_option) or 'q' to quit: " -r selection
        
        if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
            print_info "Restore cancelled by user"
            return 0
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $max_option ]]; then
            local selected_app="${app_keys[$((selection - 1))]}"
            break
        else
            print_warning "Invalid selection. Please enter a number between 1 and $max_option"
        fi
    done
    
    # Execute restore for selected application
    execute_app_script "$selected_app" --restore
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $(basename "$0") [APP...] [OPTIONS]

Unified Destroy-Redeploy Script v2.0

Safely reinstalls macOS applications with backup and error handling.
Supports multiple applications and batch operations.

APPLICATIONS:
$(for app_key in "${!SUPPORTED_APPS[@]}"; do
    printf "    %-12s %s\n" "$app_key" "${SUPPORTED_APPS[$app_key]}"
done | sort)
    all             Process all supported applications

OPTIONS:
    --dry-run           Show what would be done without making changes
    --force             Skip confirmation prompts
    --no-backup         Disable automatic backup creation
    --verbose           Enable verbose logging
    --log-file FILE     Write logs to specified file
    --allow-root        Allow running as root user
    --verify-launch     Test application launch after installation
    --continue-on-error Continue processing other apps if one fails
    --interactive       Interactive application selection mode
    --restore           Interactive restore mode
    --list-backups      List all available backups
    --help              Show this help message

EXAMPLES:
    $(basename "$0")                      # Interactive mode
    $(basename "$0") chrome               # Reinstall Chrome only
    $(basename "$0") chrome zoom          # Reinstall Chrome and Zoom
    $(basename "$0") all                  # Reinstall all applications
    $(basename "$0") --dry-run chrome     # Preview Chrome reinstall
    $(basename "$0") --list-backups       # Show all backups
    $(basename "$0") --restore            # Interactive restore mode

INDIVIDUAL APP SCRIPTS:
    scripts/destroy-redeploy-chrome.sh    # Chrome-specific script
    scripts/destroy-redeploy-zoom.sh      # Zoom-specific script

BACKUP AND RESTORE:
    Backups are automatically created in ~/.destroy-redeploy-backups/
    Each application script supports individual restore operations
    Use --restore for interactive restoration

SAFETY FEATURES:
    • Automatic backup before removal
    • Application-specific safety checks
    • Graceful application shutdown
    • Download verification
    • Rollback on installation failure
    • Comprehensive error handling
    • Batch operation support

For more information, visit: https://github.com/0xclaire/destroy-redeploy
EOF
}

# Main function
main() {
    # Set up signal traps
    setup_traps
    
    # Initialize variables
    local apps_to_process=()
    local script_args=()
    local interactive_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|--force|--no-backup|--verbose|--allow-root|--verify-launch)
                script_args+=("$1")
                ;;
            --log-file)
                script_args+=("$1" "$2")
                LOG_FILE="$2"
                shift
                ;;
            --continue-on-error)
                CONTINUE_ON_ERROR=true
                ;;
            --interactive)
                interactive_mode=true
                ;;
            --restore)
                RESTORE_MODE=true
                ;;
            --list-backups)
                LIST_BACKUPS=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Application name
                if validate_app "$1"; then
                    apps_to_process+=("$1")
                else
                    exit 1
                fi
                ;;
        esac
        shift
    done
    
    # Store script args for passing to individual scripts
    SCRIPT_ARGS=("${script_args[@]}")
    
    # Initialize logging
    init_logging "$@"
    
    # Show header unless in special modes
    if [[ "${LIST_BACKUPS:-false}" != "true" ]] && [[ "${RESTORE_MODE:-false}" != "true" ]]; then
        show_header
    fi
    
    # Check requirements
    if ! check_requirements; then
        exit 1
    fi
    
    # Handle special modes
    if [[ "${LIST_BACKUPS:-false}" == "true" ]]; then
        list_all_backups
        exit $?
    fi
    
    if [[ "${RESTORE_MODE:-false}" == "true" ]]; then
        interactive_restore
        exit $?
    fi
    
    # Determine applications to process
    if [[ ${#apps_to_process[@]} -eq 0 ]] || [[ "$interactive_mode" == "true" ]]; then
        # Interactive mode
        local selected_app
        selected_app="$(select_application)"
        
        if [[ "$selected_app" == "all" ]]; then
            apps_to_process=($(printf '%s\n' "${!SUPPORTED_APPS[@]}" | sort))
        else
            apps_to_process=("$selected_app")
        fi
    elif [[ ${#apps_to_process[@]} -eq 1 ]] && [[ "${apps_to_process[0]}" == "all" ]]; then
        # Process all applications
        apps_to_process=($(printf '%s\n' "${!SUPPORTED_APPS[@]}" | sort))
    fi
    
    # Check internet connectivity
    if ! check_internet; then
        exit 1
    fi
    
    # Process applications
    if [[ ${#apps_to_process[@]} -eq 1 ]]; then
        # Single application
        execute_app_script "${apps_to_process[0]}" "${SCRIPT_ARGS[@]}"
    else
        # Multiple applications
        process_multiple_apps "${apps_to_process[@]}"
    fi
}

# Run main function with all arguments
main "$@"
