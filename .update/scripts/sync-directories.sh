#!/bin/bash

# Sync Additional Directories Script
# Syncs specified directories from production to local

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Export CONFIG_FILE for helper functions
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"

# Source helper functions and remote execution
source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/remote-exec.sh"

# Parse configuration
ADDITIONAL_SYNC_DIRS=$(get_config "additional_sync_dirs")
REMOTE_PROJECT_DIR=$(get_config "remote_project_dir")
SSH_HOST=$(get_config "ssh_host")
SSH_USER=$(get_config "ssh_user")

# Check if additional directories are configured
if [ -z "$ADDITIONAL_SYNC_DIRS" ]; then
    info "No additional directories configured for sync"
    exit 0
fi

info "Starting additional directory sync"

# Split comma-separated directories and sync each
IFS=',' read -ra DIRS <<< "$ADDITIONAL_SYNC_DIRS"
for dir in "${DIRS[@]}"; do
    # Trim whitespace
    dir=$(echo "$dir" | xargs)
    
    if [ -z "$dir" ]; then
        continue
    fi
    
    REMOTE_PATH="$REMOTE_PROJECT_DIR/$dir"
    LOCAL_PATH="$PROJECT_ROOT/$dir"
    
    info "Syncing $dir..."
    echo "  Remote: $SSH_USER@$SSH_HOST:$REMOTE_PATH"
    echo "  Local: $LOCAL_PATH"
    
    # Create local directory if it doesn't exist
    mkdir -p "$LOCAL_PATH"
    
    # Check if remote directory exists
    if execute_remote_command "[ -d '$REMOTE_PATH' ]" true 2>/dev/null; then
        # Sync the directory
        if sync_directory "$REMOTE_PATH" "$LOCAL_PATH"; then
            success "✓ Synced $dir"
        else
            # Try with rsync if sync_directory fails
            warning "Primary sync failed, trying alternative method..."
            
            # Check if rsync is available
            if command -v rsync >/dev/null 2>&1; then
                info "Attempting rsync..."
                if sync_directory "$REMOTE_PATH" "$LOCAL_PATH"; then
                    success "✓ Synced $dir via rsync"
                else
                    error "Failed to sync $dir"
                fi
            else
                # Fallback to SCP for individual files
                warning "rsync not available, using SCP (slower)..."
                
                # Get list of files from remote directory
                REMOTE_FILES=$(execute_remote_command "find '$REMOTE_PATH' -type f -printf '%P\n'" true 2>/dev/null || echo "")
                
                if [ -n "$REMOTE_FILES" ]; then
                    echo "$REMOTE_FILES" | while IFS= read -r file; do
                        if [ -n "$file" ]; then
                            REMOTE_FILE="$REMOTE_PATH/$file"
                            LOCAL_FILE="$LOCAL_PATH/$file"
                            
                            # Create parent directory
                            mkdir -p "$(dirname "$LOCAL_FILE")"
                            
                            # Download file
                            if download_file "$REMOTE_FILE" "$LOCAL_FILE" 2>/dev/null; then
                                echo "  ✓ Downloaded $file"
                            else
                                echo "  ✗ Failed to download $file"
                            fi
                        fi
                    done
                    success "✓ Synced $dir via SCP"
                else
                    warning "No files found in $dir"
                fi
            fi
        fi
    else
        warning "Remote directory does not exist: $REMOTE_PATH"
    fi
    
    echo ""
done

success "Additional directory sync complete"

# Show summary
echo ""
echo "Synced directories:"
for dir in "${DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)
    if [ -n "$dir" ]; then
        LOCAL_PATH="$PROJECT_ROOT/$dir"
        if [ -d "$LOCAL_PATH" ]; then
            FILE_COUNT=$(find "$LOCAL_PATH" -type f 2>/dev/null | wc -l | xargs)
            echo "  ✓ $dir ($FILE_COUNT files)"
        else
            echo "  ✗ $dir (failed)"
        fi
    fi
done