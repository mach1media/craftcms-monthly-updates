#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helpers.sh"

# Parse config
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"
FTP_HOST=$(get_config "ftp_host")
FTP_USER=$(get_config "ftp_user")
FTP_PATH=$(get_config "remote_uploads_dir")
LOCAL_UPLOADS=$(get_config "uploads_dir" "web/uploads")

info "Syncing assets from production..."
info "FTP Host: $FTP_HOST"
info "Remote path: $FTP_PATH"

# Using lftp for reliable sync
if ! command -v lftp &> /dev/null; then
    error "lftp not installed. Install with: brew install lftp"
fi

FTP_PASS=$(get_password "ftp_password" "Enter FTP password for $FTP_USER@$FTP_HOST:")

lftp -u "$FTP_USER,$FTP_PASS" "$FTP_HOST" <<EOF
mirror --verbose --parallel=5 --only-newer "$FTP_PATH" "$LOCAL_UPLOADS"
quit
EOF

success "Assets synced successfully"