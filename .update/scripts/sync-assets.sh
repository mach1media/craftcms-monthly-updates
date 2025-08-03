#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helpers.sh"

# Cleanup function for proper signal handling
cleanup() {
    stop_progress
    echo ""
    echo "Script interrupted. Cleaning up..."
    exit 130
}

# Set up signal traps
trap cleanup SIGINT SIGTERM

# Progress indicator function - simplified and faster
show_progress() {
    local message="$1"
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while true; do
        local char=${spinner:$i:1}
        echo -ne "${YELLOW}[$char]${NC} $message\r"
        sleep 0.1
        i=$(( (i+1) % ${#spinner} ))
    done
}

# Start progress in background
progress_pid=""
start_progress() {
    local message="$1"
    show_progress "$message" &
    progress_pid=$!
}

# Stop progress
stop_progress() {
    if [ -n "$progress_pid" ]; then
        kill $progress_pid 2>/dev/null
        wait $progress_pid 2>/dev/null
        progress_pid=""
    fi
    echo -ne "\033[2K\r"  # Clear line
}

# Test SFTP connection with SSH key
test_sftp_key_connection() {
    local host="$1"
    local user="$2"
    local ssh_key="$3"
    local timeout=30
    
    # Test SFTP connection with SSH key using lftp
    gtimeout $timeout lftp -u "$user," "sftp://$host" -e "set sftp:connect-program 'ssh -i $ssh_key -o BatchMode=yes -o StrictHostKeyChecking=no'; ls; quit" >/dev/null 2>&1
    return $?
}

# Test SFTP connection with password (fallback)
test_sftp_password_connection() {
    local host="$1"
    local user="$2"
    local pass="$3"
    local timeout=30
    
    # Test SFTP connection with lftp
    gtimeout $timeout lftp -u "$user,$pass" "sftp://$host" -e "ls; quit" >/dev/null 2>&1
    return $?
}

# Test FTP connection with timeout (fallback)
test_ftp_connection() {
    local host="$1"
    local user="$2"
    local pass="$3"
    local timeout=30
    
    # Test connection with a simple ls command
    gtimeout $timeout lftp -u "$user,$pass" "$host" -e "ls; quit" >/dev/null 2>&1
    return $?
}

# SSH key detection function (same as sync-db.sh)
find_ssh_key() {
    local ssh_keys=("serverpilot" "id_rsa" "id_ed25519")
    
    for key in "${ssh_keys[@]}"; do
        local key_path="$HOME/.ssh/$key"
        if [ -f "$key_path" ]; then
            echo "$key_path"
            return 0
        fi
    done
    
    return 1
}

# Parse config
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"
FTP_HOST=$(get_config "ftp_host")
FTP_USER=$(get_config "ftp_user")
FTP_PATH=$(get_config "remote_uploads_dir")
LOCAL_UPLOADS=$(get_config "uploads_dir" "web/uploads")
SSH_HOST=$(get_config "ssh_host")
SSH_USER=$(get_config "ssh_user")
SSH_PORT=$(get_config "ssh_port" "22")

info "Syncing assets from production..."
info "FTP Host: $FTP_HOST"
info "Remote path: $FTP_PATH"
info "Local path: $LOCAL_UPLOADS"

# Check if lftp is installed
if ! command -v lftp &> /dev/null; then
    error "lftp not installed. Install with: brew install lftp"
fi

# Try SSH key authentication first
SSH_KEY=$(find_ssh_key) || true
SFTP_SUCCESS=false
AUTH_METHOD=""

if [ -n "$SSH_KEY" ]; then
    info "Found SSH key: $SSH_KEY"
    info "Testing SFTP connection with SSH key to $SSH_HOST (30s timeout)..."
    
    if test_sftp_key_connection "$SSH_HOST" "$SSH_USER" "$SSH_KEY"; then
        success "SFTP connection with SSH key successful"
        TRANSFER_PROTOCOL="sftp"
        AUTH_METHOD="key"
        SFTP_SUCCESS=true
        # Use SSH credentials for SFTP
        SFTP_HOST="$SSH_HOST"
        SFTP_USER="$SSH_USER"
    else
        info "SFTP with SSH key failed, trying password authentication..."
    fi
fi

# Try password authentication if SSH key failed
if [ "$SFTP_SUCCESS" = false ]; then
    FTP_PASS=$(get_password "ftp_password" "Enter FTP/SSH password for $FTP_USER@$FTP_HOST:")
    
    info "Testing SFTP connection with password to $FTP_HOST (30s timeout)..."
    if test_sftp_password_connection "$FTP_HOST" "$FTP_USER" "$FTP_PASS"; then
        success "SFTP connection with password successful"
        TRANSFER_PROTOCOL="sftp"
        AUTH_METHOD="password"
        SFTP_SUCCESS=true
        # Use FTP credentials for SFTP
        SFTP_HOST="$FTP_HOST"
        SFTP_USER="$FTP_USER"
    else
        info "SFTP with password failed, trying FTP..."
        info "Testing FTP connection to $FTP_HOST (30s timeout)..."
        if test_ftp_connection "$FTP_HOST" "$FTP_USER" "$FTP_PASS"; then
            success "FTP connection successful"
            TRANSFER_PROTOCOL="ftp"
            AUTH_METHOD="password"
        else
            error "SSH key, SFTP, and FTP connections all failed. Please check your credentials and network connection."
        fi
    fi
fi

# Ensure local directory exists
mkdir -p "$LOCAL_UPLOADS"

# Sync assets
info "Starting asset sync using $TRANSFER_PROTOCOL with $AUTH_METHOD authentication (excluding underscore directories)..."

# Run lftp with the appropriate protocol and authentication
if [ "$TRANSFER_PROTOCOL" = "sftp" ] && [ "$AUTH_METHOD" = "key" ]; then
    # SFTP with SSH key
    lftp -u "$SFTP_USER," "sftp://$SFTP_HOST" <<EOF
set sftp:connect-program 'ssh -i $SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=no'
set sftp:auto-confirm yes
mirror --verbose --parallel=5 --only-newer --exclude-glob "_*/" "$FTP_PATH" "$LOCAL_UPLOADS"
quit
EOF
elif [ "$TRANSFER_PROTOCOL" = "sftp" ] && [ "$AUTH_METHOD" = "password" ]; then
    # SFTP with password
    lftp -u "$SFTP_USER,$FTP_PASS" "sftp://$SFTP_HOST" <<EOF
set sftp:auto-confirm yes
mirror --verbose --parallel=5 --only-newer --exclude-glob "_*/" "$FTP_PATH" "$LOCAL_UPLOADS"
quit
EOF
else
    # FTP with password
    lftp -u "$FTP_USER,$FTP_PASS" "$FTP_HOST" <<EOF
set ftp:list-options -a
mirror --verbose --parallel=5 --only-newer --exclude-glob "_*/" "$FTP_PATH" "$LOCAL_UPLOADS"
quit
EOF
fi

sync_result=$?

if [ $sync_result -eq 0 ]; then
    success "Assets synced successfully"
else
    error "Asset sync failed"
fi