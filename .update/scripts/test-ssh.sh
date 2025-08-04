#!/bin/bash

# SSH Connection Test Script
# Uses the same connection methods as the actual sync scripts

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Export CONFIG_FILE for helper functions
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"

source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/remote-exec.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    error "Config file not found. Run 'npm run update:config' first."
fi

SSH_HOST=$(get_config "ssh_host")
SSH_USER=$(get_config "ssh_user")
SSH_PORT=$(get_config "ssh_port" "22")
REMOTE_PROJECT_DIR=$(get_config "remote_project_dir")

info "Testing SSH connection to $SSH_USER@$SSH_HOST:$SSH_PORT"
info "Remote project directory: $REMOTE_PROJECT_DIR"
echo ""

# Test connection using the same method as sync scripts
info "Testing SSH connection methods..."

# Try to find SSH key
if SSH_KEY=$(find_ssh_key); then
    info "Found SSH key: $SSH_KEY"
    
    # Test SSH key authentication
    if test_ssh_connection "key" "$SSH_KEY"; then
        success "✓ SSH key authentication successful"
        METHOD="key"
    else
        warning "SSH key authentication failed"
    fi
else
    info "No SSH keys found in standard locations"
fi

# If key didn't work, try password
if [ -z "${METHOD:-}" ]; then
    FTP_PASSWORD=$(get_config "ftp_password")
    if [ -n "$FTP_PASSWORD" ] && command -v sshpass >/dev/null 2>&1; then
        info "Testing password authentication..."
        if test_ssh_connection "password"; then
            success "✓ SSH password authentication successful"
            METHOD="password"
        else
            warning "SSH password authentication failed"
        fi
    elif command -v sshpass >/dev/null 2>&1; then
        info "No password configured in config.yml"
    else
        info "sshpass not installed (required for password auth)"
        info "Install with: brew install sshpass"
    fi
fi

# If we have a working connection, test various operations
if [ -n "${METHOD:-}" ]; then
    echo ""
    info "Testing remote operations..."
    
    # Test basic command execution
    info "Testing command execution..."
    if execute_remote_command "echo 'Remote command execution works'" false >/dev/null 2>&1; then
        success "✓ Remote command execution works"
    else
        error "✗ Remote command execution failed"
    fi
    
    # Test project directory access
    info "Testing project directory access..."
    if execute_remote_command "[ -d '$REMOTE_PROJECT_DIR' ] && echo 'Directory exists'" false >/dev/null 2>&1; then
        success "✓ Project directory exists: $REMOTE_PROJECT_DIR"
    else
        error "✗ Project directory not found: $REMOTE_PROJECT_DIR"
    fi
    
    # Test Craft CMS access
    info "Testing Craft CMS installation..."
    if execute_remote_command "php craft --version 2>/dev/null || php craft about 2>/dev/null" true >/dev/null 2>&1; then
        CRAFT_VERSION=$(execute_remote_command "php craft --version 2>/dev/null || php craft about 2>/dev/null | grep Version" true 2>/dev/null || echo "Unknown")
        success "✓ Craft CMS found: $CRAFT_VERSION"
    else
        warning "✗ Could not verify Craft CMS installation"
        echo "  This might be normal if Craft is not in the expected location"
    fi
    
    # Test backup directory
    BACKUP_DIR=$(get_config "backup_dir" "storage/backups")
    info "Testing backup directory..."
    if execute_remote_command "[ -d '$BACKUP_DIR' ] && echo 'Backup directory exists'" true >/dev/null 2>&1; then
        success "✓ Backup directory exists: $BACKUP_DIR"
    else
        warning "✗ Backup directory not found: $BACKUP_DIR"
        echo "  It will be created during backup if needed"
    fi
    
    # Test asset storage type and directories
    ASSET_STORAGE_TYPE=$(get_config "asset_storage_type" "local")
    if [ "$ASSET_STORAGE_TYPE" = "local" ]; then
        UPLOADS_DIR=$(get_config "uploads_dir" "web/uploads")
        info "Testing uploads directory (local storage)..."
        if execute_remote_command "[ -d '$UPLOADS_DIR' ] && echo 'Uploads directory exists'" true >/dev/null 2>&1; then
            FILE_COUNT=$(execute_remote_command "find '$UPLOADS_DIR' -type f 2>/dev/null | wc -l" true 2>/dev/null || echo "0")
            success "✓ Uploads directory exists: $UPLOADS_DIR ($FILE_COUNT files)"
        else
            warning "✗ Uploads directory not found: $UPLOADS_DIR"
        fi
    else
        info "Asset storage type: $ASSET_STORAGE_TYPE (cloud storage - no local sync needed)"
    fi
    
    # Test additional sync directories if configured
    ADDITIONAL_DIRS=$(get_config "additional_sync_dirs")
    if [ -n "$ADDITIONAL_DIRS" ]; then
        info "Testing additional sync directories..."
        IFS=',' read -ra DIRS <<< "$ADDITIONAL_DIRS"
        for dir in "${DIRS[@]}"; do
            dir=$(echo "$dir" | xargs)
            if execute_remote_command "[ -d '$dir' ] && echo 'Directory exists'" true >/dev/null 2>&1; then
                success "  ✓ $dir"
            else
                warning "  ✗ $dir (not found)"
            fi
        done
    fi
    
    echo ""
    success "SSH connection test completed successfully!"
    echo "Connection method: $METHOD"
else
    echo ""
    error "No working SSH authentication method found"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check SSH credentials in config.yml"
    echo "2. Ensure SSH key is added to the server"
    echo "3. For password auth, install sshpass: brew install sshpass"
    echo "4. Test manual SSH: ssh -p $SSH_PORT $SSH_USER@$SSH_HOST"
    exit 1
fi

