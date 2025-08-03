#!/bin/bash

# SSH Connection Test Script

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helpers.sh"

# Parse config
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"

if [ ! -f "$CONFIG_FILE" ]; then
    error "Config file not found. Run 'npm run update:config' first."
fi

SSH_HOST=$(get_config "ssh_host")
SSH_USER=$(get_config "ssh_user")
SSH_PORT=$(get_config "ssh_port" "22")
REMOTE_PROJECT_DIR=$(get_config "remote_project_dir")

info "Testing SSH connection to $SSH_USER@$SSH_HOST:$SSH_PORT"
info "Remote project directory: $REMOTE_PROJECT_DIR"

# Test SSH key authentication
SSH_KEY_FOUND=false
ssh_keys=("serverpilot" "id_rsa" "id_ed25519")

for key in "${ssh_keys[@]}"; do
    key_path="$HOME/.ssh/$key"
    if [ -f "$key_path" ]; then
        info "Testing SSH key: $key_path"
        
        # Check if key has a passphrase
        if ssh-keygen -y -f "$key_path" >/dev/null 2>&1; then
            info "SSH key is readable (no passphrase or passphrase in agent)"
        else
            info "SSH key requires passphrase or has issues - this might be the problem"
        fi
        
        info "Command: ssh -i \"$key_path\" -p \"$SSH_PORT\" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \"$SSH_USER@$SSH_HOST\""
        
        # First test with verbose output to see what's happening
        info "Running SSH test with debug output..."
        set +e  # Don't exit on error
        
        ssh_output=$(gtimeout 15 ssh -i "$key_path" -p "$SSH_PORT" -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -o BatchMode=yes -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "echo 'SSH key authentication successful'" 2>&1)
        ssh_exit_code=$?
        set -e  # Re-enable exit on error
        
        info "SSH exit code: $ssh_exit_code"
        if [ -n "$ssh_output" ]; then
            info "SSH output: $ssh_output"
        fi
        
        if [ $ssh_exit_code -eq 0 ]; then
            success "✓ SSH key authentication works with $key"
            SSH_KEY_FOUND=true
            
            # Test remote Craft access
            info "Testing remote Craft CMS access..."
            if ssh -i "$key_path" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "cd $REMOTE_PROJECT_DIR && php craft --version" 2>/dev/null; then
                success "✓ Remote Craft CMS access works"
            else
                error "✗ Remote Craft CMS access failed"
            fi
            break
        else
            info "✗ SSH key $key did not work (exit code: $ssh_exit_code)"
        fi
    else
        info "SSH key not found: $key_path"
    fi
done

if [ "$SSH_KEY_FOUND" = false ]; then
    info "No working SSH keys found. Testing password authentication..."
    
    if command -v sshpass &> /dev/null; then
        SSH_PASSWORD=$(get_password "ftp_password" "Enter SSH password for $SSH_USER@$SSH_HOST:")
        
        if sshpass -p "$SSH_PASSWORD" ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "echo 'SSH password authentication successful'" 2>/dev/null; then
            success "✓ SSH password authentication works"
            
            # Test remote Craft access
            info "Testing remote Craft CMS access..."
            if sshpass -p "$SSH_PASSWORD" ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "cd $REMOTE_PROJECT_DIR && php craft --version" 2>/dev/null; then
                success "✓ Remote Craft CMS access works"
            else
                error "✗ Remote Craft CMS access failed"
            fi
        else
            error "✗ SSH password authentication failed"
        fi
    else
        info "sshpass not installed. Install with: brew install sshpass"
        info "Testing basic SSH connection (will prompt for password)..."
        if ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "echo 'SSH connection successful'"; then
            success "✓ SSH connection works (manual password entry)"
        else
            error "✗ SSH connection failed"
        fi
    fi
fi

success "SSH connection test completed"