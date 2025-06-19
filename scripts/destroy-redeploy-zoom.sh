#!/bin/bash
#
# Enhanced Zoom Destroy-Redeploy Script v2.0
# Safely reinstalls Zoom with backup and error handling
#

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source required libraries
# shellcheck source=../lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
# shellcheck source=../lib/logging.sh
source "$PROJECT_ROOT/lib/logging.sh"
# shellcheck source=../lib/safety.sh
source "$PROJECT_ROOT/lib/safety.sh"

# Application configuration
APP_CONFIG="zoom"

# Main application destruction and redeployment function
destroy_and_redeploy_zoom() {
    local start_time
    start_time="$(date +%s)"
    local success=false
    
    log_function_enter "destroy_and_redeploy_zoom"
    
    # Load application configuration
    if ! load_app_config "$APP_CONFIG"; then
        log_fatal "Failed to load application configuration"
    fi
    
    # Log system and application info
    log_system_info
    log_app_info "/Applications/$APP_BUNDLE" "$APP_NAME"
    
    # Run safety checks
    if ! run_safety_checks "$APP_NAME" "/Applications/$APP_BUNDLE"; then
        log_error "Safety checks failed"
        return 1
    fi
    
    # Initialize backup system
    init_backup_system
    
    # Create backup if application exists and backup is enabled
    if [[ -d "/Applications/$APP_BUNDLE" ]] && [[ "$BACKUP_ENABLED" == "true" ]]; then
        if ! backup_application "/Applications/$APP_BUNDLE" "$APP_NAME" "${BACKUP_DIRS[@]}"; then
            if ! confirm_action "Backup failed. Continue anyway? (NOT RECOMMENDED)"; then
                log_error "Operation aborted due to backup failure"
                return 1
            fi
        fi
    fi
    
    # Quit the application
    if ! quit_application; then
        log_error "Failed to quit application"
        return 1
    fi
    
    # Remove existing installation
    if ! remove_application; then
        log_error "Failed to remove existing application"
        return 1
    fi
    
    # Download and install new version
    if ! download_and_install; then
        log_error "Failed to download and install application"
        
        # Offer rollback
        offer_rollback "$APP_NAME"
        return 1
    fi
    
    # Post-installation setup
    if ! post_install_setup; then
        log_warn "Post-installation setup encountered issues"
    fi
    
    success=true
    local end_time
    end_time="$(date +%s)"
    
    print_success "$APP_NAME has been successfully destroy-redeployed!"
    log_session_summary "Destroy-Redeploy" "$APP_NAME" "$success" "$start_time" "$end_time"
    
    log_function_exit "destroy_and_redeploy_zoom" 0
}

# Quit the application gracefully
quit_application() {
    log_function_enter "quit_application"
    
    print_step "Quitting $APP_NAME..."
    
    if ! is_app_running "$APP_PROCESS"; then
        print_info "$APP_NAME is not currently running"
        log_function_exit "quit_application" 0
        return 0
    fi
    
    # Check for active meetings
    if check_active_meeting; then
        print_warning "Active Zoom meeting detected!"
        if ! confirm_action "Force quit Zoom during an active meeting? This will disconnect you from the meeting."; then
            print_info "Operation cancelled to preserve meeting connection"
            return 1
        fi
    fi
    
    # Try graceful quit first
    log_debug "Attempting graceful quit using AppleScript"
    if execute_command "Quit $APP_NAME gracefully" osascript -e "quit app \"$APP_BUNDLE\""; then
        # Wait for graceful shutdown
        local countdown=15  # Zoom may take longer to quit
        while [[ $countdown -gt 0 ]] && is_app_running "$APP_PROCESS"; do
            sleep 1
            countdown=$((countdown - 1))
        done
        
        if ! is_app_running "$APP_PROCESS"; then
            print_success "$APP_NAME quit gracefully"
            log_function_exit "quit_application" 0
            return 0
        fi
    fi
    
    # Force quit if graceful quit failed
    print_warning "Graceful quit failed, force quitting..."
    log_debug "Force quitting $APP_PROCESS"
    
    if execute_command "Force quit $APP_NAME" killall "$APP_PROCESS"; then
        sleep 3  # Zoom may have multiple processes
        
        # Also kill any remaining Zoom processes
        killall "ZoomOpener" 2>/dev/null || true
        killall "zoom.us" 2>/dev/null || true
        killall "Zoom" 2>/dev/null || true
        
        if ! is_app_running "$APP_PROCESS"; then
            print_success "$APP_NAME force quit successful"
            log_function_exit "quit_application" 0
            return 0
        fi
    fi
    
    print_error "Failed to quit $APP_NAME"
    log_function_exit "quit_application" 1
    return 1
}

# Check for active Zoom meeting
check_active_meeting() {
    # Check if Zoom is in a meeting by looking for meeting-related processes
    if pgrep -f "ZoomOpener" > /dev/null 2>&1 || \
       pgrep -f "zoom.*meeting" > /dev/null 2>&1; then
        return 0
    fi
    
    # Check for network connections that might indicate an active meeting
    if command -v lsof &> /dev/null; then
        if lsof -i -P | grep -q "zoom.*:443.*ESTABLISHED"; then
            return 0
        fi
    fi
    
    return 1
}

# Remove existing application and associated files
remove_application() {
    log_function_enter "remove_application"
    
    local app_path="/Applications/$APP_BUNDLE"
    
    if [[ ! -d "$app_path" ]]; then
        print_info "$APP_NAME is not currently installed"
        log_function_exit "remove_application" 0
        return 0
    fi
    
    print_step "Removing existing $APP_NAME installation..."
    log_info "Removing application from: $app_path"
    
    # Remove main application
    if execute_command "Remove $APP_NAME" rm -rf "$app_path"; then
        print_success "Main application removed successfully"
    else
        print_error "Failed to remove main application"
        return 1
    fi
    
    # Remove additional Zoom components that may be installed
    local additional_paths=(
        "/Applications/ZoomOutlookPlugin"
        "/Library/Audio/Plug-Ins/HAL/ZoomAudioDevice.driver"
        "/Library/Frameworks/ZoomUnit.framework"
        "/System/Library/Extensions/ZoomAudioDevice.kext"
    )
    
    for path in "${additional_paths[@]}"; do
        if [[ -e "$path" ]]; then
            log_debug "Removing additional component: $path"
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo rm -rf "$path" 2>/dev/null || log_warn "Could not remove: $path"
            else
                print_info "DRY RUN: Would remove: $path"
            fi
        fi
    done
    
    log_function_exit "remove_application" 0
    return 0
}

# Download and install the application
download_and_install() {
    log_function_enter "download_and_install"
    
    # Detect architecture and get download URL
    local arch
    arch="$(detect_architecture)" || return 1
    
    local download_url
    download_url="$(get_download_url "$arch")" || return 1
    
    log_info "Download URL: $download_url"
    
    # Create temporary directory
    local temp_dir
    temp_dir="$(create_temp_dir "$TEMP_DIR")" || return 1
    
    local installer_path="$temp_dir/$INSTALLER_FILE"
    
    # Download the installer
    if ! download_with_progress "$download_url" "$installer_path" "Downloading $APP_NAME installer"; then
        log_error "Failed to download installer"
        return 1
    fi
    
    # Verify download
    if ! verify_file "$installer_path" "$APP_NAME installer"; then
        log_error "Downloaded file verification failed"
        return 1
    fi
    
    # Install based on installer type
    case "$INSTALLER_TYPE" in
        "dmg")
            install_from_dmg "$installer_path" || return 1
            ;;
        "pkg")
            install_from_pkg "$installer_path" || return 1
            ;;
        *)
            print_error "Unsupported installer type: $INSTALLER_TYPE"
            return 1
            ;;
    esac
    
    log_function_exit "download_and_install" 0
    return 0
}

# Install from PKG file (Zoom uses PKG)
install_from_pkg() {
    local pkg_path="$1"
    
    log_function_enter "install_from_pkg" "$pkg_path"
    
    print_step "Installing $APP_NAME from PKG..."
    
    local install_cmd=(installer -pkg "$pkg_path" -target /)
    
    if [[ "$NEEDS_SUDO" == "true" ]] && [[ $EUID -ne 0 ]]; then
        install_cmd=(sudo "${install_cmd[@]}")
        print_info "Administrator privileges required for Zoom installation"
    fi
    
    log_debug "Installing package: $pkg_path"
    if ! execute_command "Install package" "${install_cmd[@]}"; then
        print_error "Failed to install package"
        return 1
    fi
    
    print_success "$APP_NAME installed successfully from PKG"
    log_function_exit "install_from_pkg" 0
    return 0
}

# Install from DMG file (fallback, though Zoom typically uses PKG)
install_from_dmg() {
    local dmg_path="$1"
    
    log_function_enter "install_from_dmg" "$dmg_path"
    
    print_step "Installing $APP_NAME from DMG..."
    
    # Mount the DMG
    log_debug "Mounting DMG: $dmg_path"
    if ! execute_command "Mount DMG" hdiutil attach "$dmg_path" -quiet; then
        print_error "Failed to mount DMG"
        return 1
    fi
    
    # Verify mount point exists
    if [[ ! -d "$MOUNT_PATH" ]]; then
        print_error "Mount point not found: $MOUNT_PATH"
        return 1
    fi
    
    # Find the app bundle in the mounted volume
    local source_app="$MOUNT_PATH/$APP_BUNDLE"
    if [[ ! -d "$source_app" ]]; then
        print_error "Application bundle not found in DMG: $source_app"
        hdiutil detach "$MOUNT_PATH" -quiet 2>/dev/null || true
        return 1
    fi
    
    # Copy application to Applications folder
    log_debug "Copying application: $source_app -> /Applications/"
    if ! execute_command "Install application" ditto -rsrc "$source_app" "/Applications/$APP_BUNDLE"; then
        print_error "Failed to copy application"
        hdiutil detach "$MOUNT_PATH" -quiet 2>/dev/null || true
        return 1
    fi
    
    # Unmount the DMG
    log_debug "Unmounting DMG"
    if ! execute_command "Unmount DMG" hdiutil detach "$MOUNT_PATH" -quiet; then
        log_warn "Failed to unmount DMG cleanly"
    fi
    
    print_success "$APP_NAME installed successfully from DMG"
    log_function_exit "install_from_dmg" 0
    return 0
}

# Post-installation setup
post_install_setup() {
    log_function_enter "post_install_setup"
    
    print_step "Performing post-installation setup..."
    
    local app_path="/Applications/$APP_BUNDLE"
    
    # Verify installation
    if [[ ! -d "$app_path" ]]; then
        print_error "Installation verification failed: $app_path not found"
        return 1
    fi
    
    # Remove quarantine attributes
    log_debug "Removing quarantine attributes"
    if ! execute_command "Remove quarantine attributes" xattr -rc "$app_path"; then
        log_warn "Failed to remove quarantine attributes"
    fi
    
    # Zoom-specific: Check for audio driver installation
    check_zoom_audio_driver
    
    # Log new installation info
    log_app_info "$app_path" "$APP_NAME"
    
    # Verify the application can launch (optional)
    if [[ "$VERIFY_LAUNCH" == "true" ]]; then
        print_step "Verifying application launch..."
        
        if execute_command "Test launch" open -a "$app_path" --args --version; then
            print_success "Application launch verification successful"
            sleep 3
            
            # Quit the test launch
            osascript -e "quit app \"$APP_BUNDLE\"" 2>/dev/null || true
        else
            log_warn "Application launch verification failed"
        fi
    fi
    
    print_success "Post-installation setup completed"
    log_function_exit "post_install_setup" 0
    return 0
}

# Check Zoom audio driver installation
check_zoom_audio_driver() {
    log_function_enter "check_zoom_audio_driver"
    
    local audio_driver_path="/Library/Audio/Plug-Ins/HAL/ZoomAudioDevice.driver"
    
    if [[ -d "$audio_driver_path" ]]; then
        print_success "Zoom audio driver installed successfully"
        log_info "Audio driver found at: $audio_driver_path"
    else
        print_warning "Zoom audio driver not found"
        log_warn "Audio driver not found at: $audio_driver_path"
        print_info "You may need to restart Zoom or your computer for full audio functionality"
    fi
    
    log_function_exit "check_zoom_audio_driver"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Enhanced Zoom Destroy-Redeploy Script v2.0

This script completely removes and reinstalls Zoom with safety features
including automatic backups, error handling, and rollback capabilities.

OPTIONS:
    --dry-run           Show what would be done without making changes
    --force             Skip confirmation prompts
    --no-backup         Disable automatic backup creation
    --verbose           Enable verbose logging
    --log-file FILE     Write logs to specified file
    --allow-root        Allow running as root user
    --verify-launch     Test application launch after installation
    --help              Show this help message

EXAMPLES:
    $(basename "$0")                    # Normal operation with prompts
    $(basename "$0") --dry-run          # Preview operations
    $(basename "$0") --force --verbose  # Force operation with detailed output
    $(basename "$0") --log-file /tmp/zoom-reinstall.log

BACKUP AND RESTORE:
    Backups are automatically created in ~/.destroy-redeploy-backups/
    To restore from a backup: $(basename "$0") --restore [backup-path]
    To list backups: $(basename "$0") --list-backups

SAFETY FEATURES:
    • Automatic backup before removal
    • Active meeting detection
    • Graceful application shutdown
    • Download verification
    • Rollback on installation failure
    • Comprehensive error handling

ZOOM-SPECIFIC FEATURES:
    • Detection of active meetings before quit
    • Removal of audio drivers and plugins
    • Verification of audio driver installation
    • Cleanup of system-level components

For more information, visit: https://github.com/0xclaire/destroy-redeploy
EOF
}

# Handle restore operation
handle_restore() {
    local backup_path="$1"
    
    if [[ -z "$backup_path" ]]; then
        # Interactive backup selection
        if backup_path="$(select_backup "Zoom")"; then
            restore_from_backup "$backup_path" "Zoom"
        else
            print_info "No backup selected"
            return 1
        fi
    else
        # Restore from specified path
        restore_from_backup "$backup_path" "Zoom"
    fi
}

# Main function
main() {
    # Set up signal traps
    setup_traps
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                ;;
            --force)
                FORCE=true
                ;;
            --no-backup)
                BACKUP_ENABLED=false
                ;;
            --verbose)
                VERBOSE=true
                LOG_LEVEL="DEBUG"
                ;;
            --log-file)
                LOG_FILE="$2"
                shift
                ;;
            --allow-root)
                ALLOW_ROOT=true
                ;;
            --verify-launch)
                VERIFY_LAUNCH=true
                ;;
            --restore)
                RESTORE_MODE=true
                RESTORE_PATH="${2:-}"
                if [[ -n "${2:-}" ]]; then
                    shift
                fi
                ;;
            --list-backups)
                LIST_BACKUPS=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    
    # Initialize logging
    init_logging "$@"
    
    # Show header
    if [[ "$DRY_RUN" != "true" ]]; then
        show_header
    fi
    
    # Check requirements
    if ! check_requirements; then
        exit 1
    fi
    
    # Check internet connectivity
    if ! check_internet; then
        exit 1
    fi
    
    # Handle special modes
    if [[ "${LIST_BACKUPS:-false}" == "true" ]]; then
        list_backups "Zoom"
        exit $?
    fi
    
    if [[ "${RESTORE_MODE:-false}" == "true" ]]; then
        handle_restore "${RESTORE_PATH:-}"
        exit $?
    fi
    
    # Run main operation
    if destroy_and_redeploy_zoom; then
        exit 0
    else
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
