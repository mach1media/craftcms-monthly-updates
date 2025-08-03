#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helpers.sh"

# Parse config
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"
PRODUCTION_URL=$(get_config "production_url")
BACKUP_DIR=$(get_config "backup_dir" "storage/backups")
SSH_HOST=$(get_config "ssh_host")
SSH_USER=$(get_config "ssh_user")
SSH_PORT=$(get_config "ssh_port" "22")
REMOTE_PROJECT_DIR=$(get_config "remote_project_dir")

# SSH key detection function
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

# Test SSH connection function
test_ssh_connection() {
    local ssh_key="$1"
    local ssh_args=""
    
    if [ -n "$ssh_key" ]; then
        ssh_args="-i $ssh_key"
    fi
    
    # Test SSH connection with a simple command - shorter timeout
    gtimeout 10 ssh $ssh_args -p "$SSH_PORT" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "echo 'SSH connection successful'" 2>/dev/null
}

# Global variable to store SSH password to avoid multiple prompts
SSH_PASSWORD=""

# SSH with password function
ssh_with_password() {
    local command="$1"
    
    # Get password once and reuse it
    if [ -z "$SSH_PASSWORD" ]; then
        SSH_PASSWORD=$(get_password "ftp_password" "Enter SSH password for $SSH_USER@$SSH_HOST:")
    fi
    
    # Use sshpass if available
    if command -v sshpass &> /dev/null; then
        sshpass -p "$SSH_PASSWORD" ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "$command"
    else
        error "sshpass not installed. Install with: brew install sshpass"
    fi
}

# SCP with password function
scp_with_password() {
    local remote_file="$1"
    local local_file="$2"
    
    # Use the same password as SSH
    if [ -z "$SSH_PASSWORD" ]; then
        SSH_PASSWORD=$(get_password "ftp_password" "Enter SSH password for $SSH_USER@$SSH_HOST:")
    fi
    
    # Use sshpass if available
    if command -v sshpass &> /dev/null; then
        sshpass -p "$SSH_PASSWORD" scp -P "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST:$remote_file" "$local_file"
    else
        error "sshpass not installed. Install with: brew install sshpass"
    fi
}

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

# Main backup process
info "Attempting to create database backup on remote server..."

# Ensure local backup directory exists
mkdir -p "$BACKUP_DIR"

# Try SSH with key authentication first
SSH_KEY=$(find_ssh_key) || true
SSH_SUCCESS=false

if [ -n "$SSH_KEY" ]; then
    info "Found SSH key: $SSH_KEY"
    
    info "Testing SSH connection with key authentication (10s timeout)..."
    if test_ssh_connection "$SSH_KEY"; then
        info "SSH key authentication successful"
        info "About to run backup command on remote server..."
        
        # Run backup command on remote server
        info "Creating database backup on remote server..."
        
        # Get timestamp before backup for file detection
        BACKUP_TIME=$(date +%s)
        info "About to execute SSH backup command..."
        
        # Temporarily disable exit on error for SSH command (deprecation warnings cause non-zero exit)
        set +e
        info "Executing: ssh -i \"$SSH_KEY\" -p \"$SSH_PORT\" \"$SSH_USER@$SSH_HOST\" \"cd $REMOTE_PROJECT_DIR && php craft db/backup --interactive=0\""
        BACKUP_OUTPUT=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cd $REMOTE_PROJECT_DIR && php craft db/backup --interactive=0" 2>&1)
        backup_exit_code=$?
        set -e
        info "SSH backup command completed"
        
        # Debug output
        info "Backup exit code: $backup_exit_code"
        info "Backup output: $BACKUP_OUTPUT"
        
        # Check if backup succeeded - look for "Backup file:" in output even if there are warnings
        if echo "$BACKUP_OUTPUT" | grep -q "Backup file:"; then
            info "Backup command completed successfully (found backup file in output)"
            
            # Try to extract filename from output first (more reliable)
            # Handle format: "Backup file: /path/to/file.sql (size)"
            BACKUP_FILENAME=$(echo "$BACKUP_OUTPUT" | grep -o "Backup file: [^[:space:]]*\.sql" | sed 's/Backup file: //' | xargs basename)
            
            # If that fails, try alternative extraction methods
            if [ -z "$BACKUP_FILENAME" ]; then
                # Try to find any .sql file mentioned in the output
                BACKUP_FILENAME=$(echo "$BACKUP_OUTPUT" | grep -o "[^[:space:]]*--[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9]*--[^[:space:]]*\.sql" | xargs basename | head -1)
            fi
            
            if [ -z "$BACKUP_FILENAME" ]; then
                # Fallback: Find newest .sql file in remote backup directory
                info "Extracting filename from output failed, searching for newest backup file..."
                BACKUP_FILENAME=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "ls -t $REMOTE_PROJECT_DIR/$BACKUP_DIR/*.sql 2>/dev/null | head -1 | xargs basename" 2>/dev/null)
                
                if [ -n "$BACKUP_FILENAME" ]; then
                    info "Found newest backup file: $BACKUP_FILENAME"
                fi
            fi
            
            if [ -n "$BACKUP_FILENAME" ]; then
                info "Backup created: $BACKUP_FILENAME"
                
                # Download the backup file
                info "Downloading backup file: $BACKUP_FILENAME"
                info "SCP command: scp -i \"$SSH_KEY\" -P \"$SSH_PORT\" \"$SSH_USER@$SSH_HOST:$REMOTE_PROJECT_DIR/$BACKUP_DIR/$BACKUP_FILENAME\" \"$BACKUP_DIR/\""
                
                set +e  # Don't exit on SCP error
                scp -i "$SSH_KEY" -P "$SSH_PORT" "$SSH_USER@$SSH_HOST:$REMOTE_PROJECT_DIR/$BACKUP_DIR/$BACKUP_FILENAME" "$BACKUP_DIR/" 2>&1
                scp_result=$?
                set -e
                
                info "SCP exit code: $scp_result"
                
                if [ $scp_result -eq 0 ]; then
                    SSH_SUCCESS=true
                    LOCAL_BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"
                    success "Successfully downloaded: $BACKUP_FILENAME"
                else
                    error "Failed to download backup file via SCP (exit code: $scp_result)"
                fi
            else
                info "Could not find backup filename. Trying password authentication..."
            fi
        else
            info "Backup command failed with key authentication. Output: $BACKUP_OUTPUT"
            info "Trying password authentication..."
        fi
    else
        info "SSH key authentication failed. Trying password authentication..."
    fi
fi

# Try password authentication if key authentication failed
if [ "$SSH_SUCCESS" = false ]; then
    info "Attempting SSH with password authentication..."
    
    # Check if sshpass is available
    if ! command -v sshpass &> /dev/null; then
        info "sshpass not installed. Install with: brew install sshpass"
        info "Skipping password authentication attempt."
    else
        # Test password connection
        info "Testing SSH password authentication (10s timeout)..."
        if gtimeout 10 ssh_with_password "echo 'SSH password authentication successful'" &>/dev/null; then
            info "SSH password authentication successful"
            
            # Run backup command on remote server
            info "Creating database backup on remote server..."
            
            # Get timestamp before backup for file detection
            BACKUP_TIME=$(date +%s)
            
            # Temporarily disable exit on error for SSH command (deprecation warnings cause non-zero exit)
            set +e
            BACKUP_OUTPUT=$(ssh_with_password "cd $REMOTE_PROJECT_DIR && php craft db/backup --interactive=0" 2>&1)
            backup_exit_code=$?
            set -e
            
            # Debug output
            info "Backup exit code: $backup_exit_code"
            info "Backup output: $BACKUP_OUTPUT"
            
            # Check if backup succeeded - look for "Backup file:" in output even if there are warnings
            if echo "$BACKUP_OUTPUT" | grep -q "Backup file:"; then
                info "Backup command completed successfully (found backup file in output)"
                
                # Try to extract filename from output first (more reliable)
                # Handle format: "Backup file: /path/to/file.sql (size)"
                BACKUP_FILENAME=$(echo "$BACKUP_OUTPUT" | grep -o "Backup file: [^[:space:]]*\.sql" | sed 's/Backup file: //' | xargs basename)
                
                # If that fails, try alternative extraction methods
                if [ -z "$BACKUP_FILENAME" ]; then
                    # Try to find any .sql file mentioned in the output
                    BACKUP_FILENAME=$(echo "$BACKUP_OUTPUT" | grep -o "[^[:space:]]*--[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9]*--[^[:space:]]*\.sql" | xargs basename | head -1)
                fi
                
                if [ -z "$BACKUP_FILENAME" ]; then
                    # Fallback: Find newest .sql file in remote backup directory
                    info "Extracting filename from output failed, searching for newest backup file..."
                    BACKUP_FILENAME=$(ssh_with_password "ls -t $REMOTE_PROJECT_DIR/$BACKUP_DIR/*.sql 2>/dev/null | head -1 | xargs basename" 2>/dev/null)
                    
                    if [ -n "$BACKUP_FILENAME" ]; then
                        info "Found newest backup file: $BACKUP_FILENAME"
                    fi
                fi
                
                if [ -n "$BACKUP_FILENAME" ]; then
                    info "Backup created: $BACKUP_FILENAME"
                    
                    # Download the backup file
                    info "Downloading backup file: $BACKUP_FILENAME"
                    
                    set +e  # Don't exit on SCP error
                    scp_with_password "$REMOTE_PROJECT_DIR/$BACKUP_DIR/$BACKUP_FILENAME" "$BACKUP_DIR/"
                    scp_result=$?
                    set -e
                    
                    info "SCP exit code: $scp_result"
                    
                    if [ $scp_result -eq 0 ]; then
                        SSH_SUCCESS=true
                        LOCAL_BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"
                        success "Successfully downloaded: $BACKUP_FILENAME"
                    else
                        error "Failed to download backup file via SCP with password (exit code: $scp_result)"
                    fi
                else
                    info "Could not find backup filename."
                fi
            else
                info "Backup command failed with password authentication. Output: $BACKUP_OUTPUT"
            fi
        else
            info "SSH password authentication failed."
        fi
    fi
fi

# Fall back to manual process if SSH failed
if [ "$SSH_SUCCESS" = false ]; then
    info "Automated SSH backup failed. Falling back to manual process..."
    info ""
    info "Please download database backup manually:"
    info "1. Go to: $PRODUCTION_URL/admin/utilities/database-backup"
    info "2. Click 'Create backup'"
    info "3. Download the backup file"
    info "4. Save it to: $BACKUP_DIR/"
    info ""
    echo -e "${YELLOW}Press Enter when the backup file is in place...${NC}"
    read -r
    
    # Find the most recent SQL file
    LOCAL_BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.sql 2>/dev/null | head -1)
    
    if [ -z "$LOCAL_BACKUP_FILE" ]; then
        error "No SQL file found in $BACKUP_DIR/"
    fi
fi

info "Found backup: $LOCAL_BACKUP_FILE"

# Use craft db/restore instead of ddev import-db for better compatibility
info "Importing database to DDEV..."

# Temporarily disable exit on error for import command (deprecation warnings cause non-zero exit)
set +e
import_output=$(ddev craft db/restore "$LOCAL_BACKUP_FILE" --interactive=0 2>&1)
import_result=$?
set -e

info "Import exit code: $import_result"
info "Import output: $import_output"

# Check if import succeeded - look for success indicators in output even if there are warnings
if echo "$import_output" | grep -q -E "(successfully|restored|imported)" || [ $import_result -eq 0 ]; then
    success "Database imported successfully"
else
    error "Database import failed"
    info "Full import output: $import_output"
fi