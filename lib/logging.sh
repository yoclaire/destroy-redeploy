#!/bin/bash
#
# Logging functions for destroy-redeploy scripts
#

# Initialize logging
init_logging() {
    local log_level="${LOG_LEVEL:-INFO}"
    local log_file="${LOG_FILE:-}"
    
    # Create log directory if log file is specified
    if [[ -n "$log_file" ]]; then
        local log_dir
        log_dir="$(dirname "$log_file")"
        mkdir -p "$log_dir"
        
        # Initialize log file with header
        {
            echo "========================================="
            echo "Destroy-Redeploy Log Session Started"
            echo "Date: $(date)"
            echo "User: $(whoami)"
            echo "Host: $(hostname)"
            echo "Script: ${0##*/}"
            echo "Args: $*"
            echo "========================================="
        } >> "$log_file"
        
        LOG_FILE_PATH="$log_file"
        export LOG_FILE_PATH
    fi
    
    LOG_LEVEL="$log_level"
    export LOG_LEVEL
}

# Log levels (numeric for comparison)
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["FATAL"]=4
)

# Check if message should be logged based on level
should_log() {
    local message_level="$1"
    local current_level_num="${LOG_LEVELS[$LOG_LEVEL]:-1}"
    local message_level_num="${LOG_LEVELS[$message_level]:-1}"
    
    [[ $message_level_num -ge $current_level_num ]]
}

# Core logging function
write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    if should_log "$level"; then
        local log_entry="[$timestamp] [$level] $message"
        
        # Write to stdout/stderr
        if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
            echo "$log_entry" >&2
        else
            echo "$log_entry"
        fi
        
        # Write to log file if configured
        if [[ -n "${LOG_FILE_PATH:-}" ]]; then
            echo "$log_entry" >> "$LOG_FILE_PATH"
        fi
    fi
}

# Specific log level functions
log_debug() {
    write_log "DEBUG" "$*"
}

log_info() {
    write_log "INFO" "$*"
}

log_warn() {
    write_log "WARN" "$*"
}

log_error() {
    write_log "ERROR" "$*"
}

log_fatal() {
    write_log "FATAL" "$*"
    exit 1
}

# Log command execution
log_command() {
    local description="$1"
    shift
    local cmd=("$@")
    
    log_debug "Executing command: $description"
    log_debug "Command: ${cmd[*]}"
    
    local start_time
    start_time="$(date +%s)"
    
    if "${cmd[@]}"; then
        local end_time
        end_time="$(date +%s)"
        local duration=$((end_time - start_time))
        log_debug "Command completed successfully in ${duration}s: $description"
        return 0
    else
        local exit_code=$?
        local end_time
        end_time="$(date +%s)"
        local duration=$((end_time - start_time))
        log_error "Command failed with exit code $exit_code after ${duration}s: $description"
        return $exit_code
    fi
}

# Log function entry/exit for debugging
log_function_enter() {
    local func_name="$1"
    shift
    log_debug "Entering function: $func_name($*)"
}

log_function_exit() {
    local func_name="$1"
    local exit_code="${2:-0}"
    log_debug "Exiting function: $func_name (exit code: $exit_code)"
}

# Log system information
log_system_info() {
    log_info "System Information:"
    log_info "  OS: $(sw_vers -productName) $(sw_vers -productVersion)"
    log_info "  Architecture: $(uname -m)"
    log_info "  Kernel: $(uname -r)"
    log_info "  Uptime: $(uptime | awk -F'load average:' '{print $1}' | sed 's/^.*up //')"
    log_info "  Memory: $(vm_stat | grep 'Pages free' | awk '{print $3}' | sed 's/\.//')KB free"
    log_info "  Disk space: $(df -h / | awk 'NR==2 {print $4}') available on root volume"
}

# Log application information
log_app_info() {
    local app_path="$1"
    local app_name="$2"
    
    if [[ -d "$app_path" ]]; then
        local version
        version="$(get_app_version "$app_path" 2>/dev/null || echo "Unknown")"
        local bundle_id
        bundle_id="$(defaults read "$app_path/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "Unknown")"
        local size
        size="$(du -sh "$app_path" 2>/dev/null | cut -f1 || echo "Unknown")"
        
        log_info "$app_name Information:"
        log_info "  Path: $app_path"
        log_info "  Version: $version"
        log_info "  Bundle ID: $bundle_id"
        log_info "  Size: $size"
    else
        log_info "$app_name is not currently installed"
    fi
}

# Create a session summary
log_session_summary() {
    local operation="$1"
    local app_name="$2"
    local success="${3:-false}"
    local start_time="$4"
    local end_time="${5:-$(date +%s)}"
    
    local duration=$((end_time - start_time))
    local status
    
    if [[ "$success" == "true" ]]; then
        status="SUCCESS"
    else
        status="FAILED"
    fi
    
    log_info "========================================="
    log_info "Session Summary"
    log_info "Operation: $operation"
    log_info "Application: $app_name"
    log_info "Status: $status"
    log_info "Duration: ${duration}s"
    log_info "Completed: $(date)"
    log_info "========================================="
    
    # Write to log file if configured
    if [[ -n "${LOG_FILE_PATH:-}" ]]; then
        echo "" >> "$LOG_FILE_PATH"
        echo "Session ended: $(date)" >> "$LOG_FILE_PATH"
        echo "=========================================" >> "$LOG_FILE_PATH"
    fi
}

# Export logging functions
export -f init_logging should_log write_log
export -f log_debug log_info log_warn log_error log_fatal
export -f log_command log_function_enter log_function_exit
export -f log_system_info log_app_info log_session_summary
