#!/bin/bash

# Cloudways Deployment Script
# Performs git pull, composer install, and Craft commands on Cloudways server

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Export CONFIG_FILE for helper functions
export CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config.yml}"

# Source helper functions
source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/remote-exec.sh"

# Parse configuration
SSH_HOST=$(get_config "ssh_host")
SSH_USER=$(get_config "ssh_user")
SSH_PORT=$(get_config "ssh_port" "22")
REMOTE_PROJECT_DIR=$(get_config "remote_project_dir")
BRANCH=$(get_config "branch" "main")

info "Starting Cloudways deployment..."
info "Server: $SSH_USER@$SSH_HOST:$SSH_PORT"
info "Project: $REMOTE_PROJECT_DIR"
info "Branch: $BRANCH"
echo ""

# Function to run remote command and stream output
run_remote() {
    local description="$1"
    local command="$2"

    info "$description"
    echo "----------------------------------------"

    # Execute command and stream output
    if ! execute_remote_command "$command" true; then
        warning "Command may have had issues, check output above"
    fi

    echo "----------------------------------------"
    echo ""
}

# Step 1: Git pull
run_remote "Pulling latest code from $BRANCH..." "git fetch origin && git reset --hard origin/$BRANCH"

# Step 2: Composer install
run_remote "Installing Composer dependencies..." "composer install --no-interaction --prefer-dist --optimize-autoloader"

# Step 3: Craft project-config apply
run_remote "Applying project config..." "php craft project-config/apply --force"

# Step 4: Craft migrate
run_remote "Running Craft migrations..." "php craft migrate/all --no-interaction"

# Step 5: Clear caches
run_remote "Clearing caches..." "php craft clear-caches/all"

success "Cloudways deployment complete!"
echo ""
info "Deployment summary:"
echo "- Git: Pulled latest from $BRANCH"
echo "- Composer: Dependencies installed"
echo "- Craft: Project config applied, migrations run, caches cleared"
