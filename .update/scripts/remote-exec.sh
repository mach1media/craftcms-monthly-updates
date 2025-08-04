#!/bin/bash

# Remote Execution Helper
# Provides abstracted SSH connection and command execution

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Export CONFIG_FILE for helper functions
export CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config.yml}"

# Source helper functions
source "$SCRIPT_DIR/helpers.sh"

# Parse SSH configuration
SSH_HOST=$(get_config "ssh_host")
SSH_USER=$(get_config "ssh_user")
SSH_PORT=$(get_config "ssh_port" "22")
FTP_PASSWORD=$(get_config "ftp_password")
REMOTE_PROJECT_DIR=$(get_config "remote_project_dir")

# Function to find SSH key
find_ssh_key() {
    local keys=(
        "$HOME/.ssh/serverpilot"
        "$HOME/.ssh/id_rsa"
        "$HOME/.ssh/id_ed25519"
        "$HOME/.ssh/id_ecdsa"
    )
    
    for key in "${keys[@]}"; do
        if [ -f "$key" ]; then
            echo "$key"
            return 0
        fi
    done
    
    return 1
}

# Function to test SSH connection
test_ssh_connection() {
    local method=$1
    local ssh_key=$2
    local test_cmd="echo 'SSH connection successful'"
    
    case $method in
        "key")
            ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no \
                -i "$ssh_key" -p "$SSH_PORT" \
                "$SSH_USER@$SSH_HOST" "$test_cmd" >/dev/null 2>&1
            ;;
        "password")
            if command -v sshpass >/dev/null 2>&1 && [ -n "$FTP_PASSWORD" ]; then
                sshpass -p "$FTP_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
                    -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$test_cmd" >/dev/null 2>&1
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to execute remote command
execute_remote_command() {
    local command=$1
    local use_project_dir=${2:-true}
    
    # Prepare the full command
    local full_command="$command"
    if [ "$use_project_dir" = "true" ] && [ -n "$REMOTE_PROJECT_DIR" ]; then
        full_command="cd '$REMOTE_PROJECT_DIR' && $command"
    fi
    
    # Try SSH key authentication first
    if SSH_KEY=$(find_ssh_key); then
        if test_ssh_connection "key" "$SSH_KEY"; then
            ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
                -i "$SSH_KEY" -p "$SSH_PORT" \
                "$SSH_USER@$SSH_HOST" "$full_command"
            return $?
        fi
    fi
    
    # Try password authentication
    if command -v sshpass >/dev/null 2>&1 && [ -n "$FTP_PASSWORD" ]; then
        if test_ssh_connection "password"; then
            sshpass -p "$FTP_PASSWORD" ssh -o StrictHostKeyChecking=no \
                -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$full_command"
            return $?
        fi
    fi
    
    # If no authentication works, return error
    error "No working SSH authentication method found"
    return 1
}

# Function to download file via SCP
download_file() {
    local remote_path=$1
    local local_path=$2
    
    # Try SSH key authentication first
    if SSH_KEY=$(find_ssh_key); then
        if test_ssh_connection "key" "$SSH_KEY"; then
            scp -o BatchMode=yes -o StrictHostKeyChecking=no \
                -i "$SSH_KEY" -P "$SSH_PORT" \
                "$SSH_USER@$SSH_HOST:$remote_path" "$local_path"
            return $?
        fi
    fi
    
    # Try password authentication
    if command -v sshpass >/dev/null 2>&1 && [ -n "$FTP_PASSWORD" ]; then
        if test_ssh_connection "password"; then
            sshpass -p "$FTP_PASSWORD" scp -o StrictHostKeyChecking=no \
                -P "$SSH_PORT" "$SSH_USER@$SSH_HOST:$remote_path" "$local_path"
            return $?
        fi
    fi
    
    # If no authentication works, return error
    error "No working SSH authentication method found for file download"
    return 1
}

# Function to sync directory via rsync
sync_directory() {
    local remote_path=$1
    local local_path=$2
    local exclude_patterns=${3:-""}
    
    # Build rsync exclude options
    local exclude_opts=""
    if [ -n "$exclude_patterns" ]; then
        IFS=',' read -ra EXCLUDES <<< "$exclude_patterns"
        for pattern in "${EXCLUDES[@]}"; do
            exclude_opts="$exclude_opts --exclude='$pattern'"
        done
    fi
    
    # Try SSH key authentication first
    if SSH_KEY=$(find_ssh_key); then
        if test_ssh_connection "key" "$SSH_KEY"; then
            eval rsync -avz --delete $exclude_opts \
                -e "ssh -i '$SSH_KEY' -p $SSH_PORT -o StrictHostKeyChecking=no" \
                "$SSH_USER@$SSH_HOST:$remote_path/" "$local_path/"
            return $?
        fi
    fi
    
    # Try password authentication with sshpass
    if command -v sshpass >/dev/null 2>&1 && [ -n "$FTP_PASSWORD" ]; then
        if test_ssh_connection "password"; then
            eval sshpass -p "$FTP_PASSWORD" rsync -avz --delete $exclude_opts \
                -e "ssh -p $SSH_PORT -o StrictHostKeyChecking=no" \
                "$SSH_USER@$SSH_HOST:$remote_path/" "$local_path/"
            return $?
        fi
    fi
    
    # If no authentication works, return error
    error "No working SSH authentication method found for directory sync"
    return 1
}

# Export functions for use by other scripts
export -f find_ssh_key
export -f test_ssh_connection
export -f execute_remote_command
export -f download_file
export -f sync_directory

# If called directly with arguments, execute the command
if [ $# -gt 0 ]; then
    execute_remote_command "$@"
fi