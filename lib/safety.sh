#!/bin/bash
#
# Safety functions for destroy-redeploy scripts
#

# Global backup settings
BACKUP_ROOT="$HOME/.destroy-redeploy-backups"
BACKUP_RETENTION_DAYS=30

# Initialize backup system
init_backup_system() {
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        mkdir -p "$BACKUP_ROOT"
        
        # Clean old backups
        clean_old_backups
        
        log_info "Backup system initialized: $BACKUP_ROOT"
    else
        log_info "Backup system disabled"
    fi
}

# Clean old backups based on retention policy
clean_old_backups() {
    log_function_enter "clean_old_backups"
    
    if [[ -d "$BACKUP_ROOT" ]]; then
        local old_backups
        old_backups=$(find "$BACKUP_ROOT" -type d -name "*-*-*_*-*-*" -mtime +$BACKUP_RETENTION_DAYS 2>/dev/null || true)
        
        if [[ -n "$old_backups" ]]; then
            log_info "Cleaning up backups older than $BACKUP_RETENTION_DAYS days"
            
            while IFS= read -r backup_dir; do
                if [[ -n "$backup_dir" ]]; then
                    log_debug "Removing old backup: $backup_dir"
                    rm -rf "$backup_dir"
                fi
            done <<< "$old_backups"
            
            log_info "Old backup cleanup completed"
        else
            log_debug "No old backups to clean"
        fi
    fi
    
    log_function_exit "clean_old_backups"
}

# Create application backup
backup_application() {
    local app_path="$1"
    local app_name="$2"
    local backup_dirs=("${@:3}")
    
    log_function_enter "backup_application" "$app_path" "$app_name"
    
    if [[ "$BACKUP_ENABLED" != "true" ]]; then
        log_info "Backup disabled, skipping application backup"
        return 0
    fi
    
    if [[ ! -d "$app_path" ]]; then
        log_info "Application not found, no backup needed: $app_path"
        return 0
    fi
    
    local timestamp
    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    local backup_dir="$BACKUP_ROOT/${app_name// /_}-$timestamp"
    
    print_step "Creating backup of $app_name..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would create backup at $backup_dir"
        return 0
    fi
    
    mkdir -p "$backup_dir"
    
    # Backup application bundle
    log_info "Backing up application bundle: $app_path"
    if ! cp -R "$app_path" "$backup_dir/"; then
        log_error "Failed to backup application bundle"
        return 1
    fi
    
    # Backup user data directories
    if [[ ${#backup_dirs[@]} -gt 0 ]]; then
        log_info "Backing up user data directories"
        
        for data_dir in "${backup_dirs[@]}"; do
            local full_path="$HOME/$data_dir"
            
            if [[ -e "$full_path" ]]; then
                local target_dir="$backup_dir/UserData/$(dirname "$data_dir")"
                mkdir -p "$target_dir"
                
                log_debug "Backing up: $full_path"
                if ! cp -R "$full_path" "$target_dir/"; then
                    log_warn "Failed to backup user data: $full_path"
                else
                    log_debug "Successfully backed up: $full_path"
                fi
            else
                log_debug "User data directory not found: $full_path"
            fi
        done
    fi
    
    # Create backup metadata
    cat > "$backup_dir/backup_info.txt" << EOF
Backup Information
==================
Application: $app_name
Original Path: $app_path
Backup Date: $(date)
System: $(sw_vers -productName) $(sw_vers -productVersion)
Architecture: $(uname -m)
User: $(whoami)
Host: $(hostname)

Backup Contents:
$(find "$backup_dir" -type f | sed "s|$backup_dir/||" | sort)
EOF

    local backup_size
    backup_size="$(du -sh "$backup_dir" | cut -f1)"
    
    print_success "Backup created successfully: $backup_dir ($backup_size)"
    log_info "Application backup completed: $backup_dir ($backup_size)"
    
    # Store backup path for potential restoration
    echo "$backup_dir" > "/tmp/destroy-redeploy-last-backup-$$"
    
    log_function_exit "backup_application" 0
    return 0
}

# Restore application from backup
restore_from_backup() {
    local backup_path="$1"
    local app_name="$2"
    
    log_function_enter "restore_from_backup" "$backup_path" "$app_name"
    
    if [[ ! -d "$backup_path" ]]; then
        print_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    print_step "Restoring $app_name from backup..."
    
    if ! confirm_action "This will restore $app_name from the backup. Continue?"; then
        print_info "Restoration cancelled by user"
        return 1
    fi
    
    # Find the application bundle in backup
    local app_bundle
    app_bundle=$(find "$backup_path" -name "*.app" -type d -maxdepth 1 | head -1)
    
    if [[ -z "$app_bundle" ]]; then
        print_error "No application bundle found in backup"
        return 1
    fi
    
    local app_bundle_name
    app_bundle_name="$(basename "$app_bundle")"
    local target_path="/Applications/$app_bundle_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would restore $app_bundle to $target_path"
        return 0
    fi
    
    # Remove existing installation if present
    if [[ -d "$target_path" ]]; then
        log_info "Removing existing installation: $target_path"
        rm -rf "$target_path"
    fi
    
    # Restore application bundle
    log_info "Restoring application bundle: $app_bundle -> $target_path"
    if ! cp -R "$app_bundle" "/Applications/"; then
        print_error "Failed to restore application bundle"
        return 1
    fi
    
    # Remove quarantine attributes
    xattr -rc "$target_path" 2>/dev/null || log_warn "Could not remove quarantine attributes"
    
    # Restore user data if present
    local user_data_dir="$backup_path/UserData"
    if [[ -d "$user_data_dir" ]]; then
        print_step "Restoring user data..."
        
        if ! confirm_action "Restore user data and preferences? This will overwrite current settings."; then
            print_info "User data restoration skipped"
        else
            log_info "Restoring user data from: $user_data_dir"
            
            # Use rsync for better handling of permissions and conflicts
            if command -v rsync &> /dev/null; then
                rsync -av "$user_data_dir/" "$HOME/" || log_warn "Some user data may not have been restored"
            else
                cp -R "$user_data_dir/"* "$HOME/" 2>/dev/null || log_warn "Some user data may not have been restored"
            fi
            
            print_success "User data restoration completed"
        fi
    fi
    
    print_success "Application restoration completed: $target_path"
    log_info "Application restoration completed successfully"
    
    log_function_exit "restore_from_backup" 0
    return 0
}

# List available backups for an application
list_backups() {
    local app_name="$1"
    local app_pattern="${app_name// /_}"
    
    print_info "Available backups for $app_name:"
    
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        print_warning "No backup directory found"
        return 1
    fi
    
    local backups
    backups=$(find "$BACKUP_ROOT" -type d -name "${app_pattern}-*" | sort -r)
    
    if [[ -z "$backups" ]]; then
        print_warning "No backups found for $app_name"
        return 1
    fi
    
    local count=0
    while IFS= read -r backup_dir; do
        if [[ -n "$backup_dir" ]]; then
            count=$((count + 1))
            local backup_name
            backup_name="$(basename "$backup_dir")"
            local backup_date
            backup_date="$(echo "$backup_name" | sed 's/.*-//' | tr '_' ' ' | tr '-' ':')"
            local backup_size
            backup_size="$(du -sh "$backup_dir" 2>/dev/null | cut -f1 || echo "Unknown")"
            
            printf "%2d. %s (%s) - %s\n" "$count" "$backup_date" "$backup_size" "$backup_dir"
        fi
    done <<< "$backups"
    
    return 0
}

# Interactive backup selection
select_backup() {
    local app_name="$1"
    local app_pattern="${app_name// /_}"
    
    if ! list_backups "$app_name" >/dev/null 2>&1; then
        return 1
    fi
    
    local backups
    backups=$(find "$BACKUP_ROOT" -type d -name "${app_pattern}-*" | sort -r)
    
    local backup_array=()
    while IFS= read -r backup_dir; do
        if [[ -n "$backup_dir" ]]; then
            backup_array+=("$backup_dir")
        fi
    done <<< "$backups"
    
    if [[ ${#backup_array[@]} -eq 0 ]]; then
        return 1
    fi
    
    echo
    list_backups "$app_name"
    echo
    
    while true; do
        read -p "Select backup number (1-${#backup_array[@]}) or 'q' to quit: " -r selection
        
        if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
            return 1
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#backup_array[@]} ]]; then
            local selected_backup="${backup_array[$((selection - 1))]}"
            echo "$selected_backup"
            return 0
        else
            print_warning "Invalid selection. Please enter a number between 1 and ${#backup_array[@]}"
        fi
    done
}

# Check if rollback is possible
can_rollback() {
    local backup_marker="/tmp/destroy-redeploy-last-backup-$$"
    
    if [[ -f "$backup_marker" ]]; then
        local backup_path
        backup_path="$(cat "$backup_marker")"
        
        if [[ -d "$backup_path" ]]; then
            echo "$backup_path"
            return 0
        fi
    fi
    
    return 1
}

# Offer rollback option
offer_rollback() {
    local app_name="$1"
    local backup_path
    
    if backup_path="$(can_rollback)"; then
        echo
        print_warning "Installation failed! A backup was created before the operation."
        
        if confirm_action "Would you like to restore from the backup?"; then
            if restore_from_backup "$backup_path" "$app_name"; then
                print_success "Application restored from backup successfully"
                return 0
            else
                print_error "Failed to restore from backup"
                return 1
            fi
        else
            print_info "Backup available at: $backup_path"
            print_info "You can restore manually later using: $0 --restore \"$backup_path\""
        fi
    else
        print_warning "No recent backup found for automatic rollback"
    fi
    
    return 1
}

# Safety checks before proceeding
run_safety_checks() {
    local app_name="$1"
    local app_path="$2"
    
    log_function_enter "run_safety_checks" "$app_name" "$app_path"
    
    print_step "Running safety checks..."
    
    # Check if running as root (dangerous for user applications)
    if [[ $EUID -eq 0 ]] && [[ "$ALLOW_ROOT" != "true" ]]; then
        print_error "Running as root is not recommended for user applications"
        print_info "Use --allow-root flag if you really need to run as root"
        return 1
    fi
    
    # Check available disk space
    local available_space_kb
    available_space_kb=$(df / | awk 'NR==2 {print $4}')
    local required_space_kb=$((1024 * 1024))  # 1GB minimum
    
    if [[ $available_space_kb -lt $required_space_kb ]]; then
        print_error "Insufficient disk space. At least 1GB free space required"
        return 1
    fi
    
    # Check if application is critically running
    if is_app_running "$APP_PROCESS"; then
        print_warning "$app_name is currently running"
        
        # Check for unsaved work or important processes
        local running_processes
        running_processes=$(pgrep -l "$APP_PROCESS" | wc -l)
        
        if [[ $running_processes -gt 1 ]]; then
            print_warning "Multiple $app_name processes detected ($running_processes)"
            print_warning "You may have unsaved work or background tasks running"
        fi
        
        if ! confirm_action "Force quit $app_name and continue?"; then
            print_info "Operation cancelled by user"
            return 1
        fi
    fi
    
    # Warn about data loss
    print_warning "This operation will:"
    echo "  • Completely remove the current $app_name installation"
    echo "  • Download and install the latest version"
    echo "  • May reset some application preferences"
    
    if [[ "$PRESERVE_DATA" == "true" ]] && [[ "$BACKUP_ENABLED" == "true" ]]; then
        print_info "✅ Application data will be backed up before removal"
    else
        print_warning "⚠️  Application data will NOT be backed up"
    fi
    
    echo
    
    if ! confirm_action "Are you sure you want to continue with the destroy-redeploy operation?"; then
        print_info "Operation cancelled by user"
        return 1
    fi
    
    print_success "Safety checks completed"
    log_function_exit "run_safety_checks" 0
    return 0
}

# Export safety functions
export -f init_backup_system clean_old_backups backup_application restore_from_backup
export -f list_backups select_backup can_rollback offer_rollback run_safety_checks
