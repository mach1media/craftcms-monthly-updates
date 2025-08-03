#!/bin/bash

# Craft CMS Update Orchestrator
# Run from project root: .update/update.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$SCRIPT_DIR/logs/update-$(date +%Y%m%d-%H%M%S).log"

# Load configuration
if [ ! -f "$SCRIPT_DIR/config.yml" ]; then
    echo -e "${RED}[ERROR]${NC} config.yml not found. Please create it from config.yml.example" >&2
    exit 1
fi

# Export CONFIG_FILE for helper functions
export CONFIG_FILE="$SCRIPT_DIR/config.yml"

# Source helper functions
source "$SCRIPT_DIR/scripts/helpers.sh"

# Parse config using helper function
PRODUCTION_URL=$(get_config "production_url")
DEPLOYMENT_METHOD=$(get_config "deployment_method")
REPO_BRANCH=$(get_config "branch" "main")
RUN_NPM_BUILD=$(get_config "run_npm_build" "false")
NPM_BUILD_COMMAND=$(get_config "npm_build_command" "npm run build")

# Create log directory
mkdir -p "$SCRIPT_DIR/logs"

# Start logging
exec > >(tee -a "$LOG_FILE")
exec 2>&1

info "Starting Craft CMS update process"
info "Project: $PROJECT_ROOT"
info "Log file: $LOG_FILE"

# Step 1: Navigate to project root
cd "$PROJECT_ROOT" || error "Failed to navigate to project root"
success "✓ In project root"

# Step 2: Pull from git
info "Pulling latest changes from git..."
git pull origin "$REPO_BRANCH" || pause_on_error "Git pull failed"
success "✓ Git pull complete"

# Step 3 & 4: Database sync
info "Syncing database from production..."
"$SCRIPT_DIR/scripts/sync-db.sh" || pause_on_error "Database sync failed"
success "✓ Database synced"

# Step 5: Asset sync
info "Syncing assets from production..."
"$SCRIPT_DIR/scripts/sync-assets.sh" || pause_on_error "Asset sync failed"
success "✓ Assets synced"

# Create update branch
UPDATE_BRANCH="update/$(date +%Y-%m-%d)"
info "Creating update branch: $UPDATE_BRANCH"
git checkout -b "$UPDATE_BRANCH" || error "Failed to create update branch"
success "✓ Update branch created"

# Step 6: Composer update
info "Running composer update..."

# Get Craft CMS version before update
CRAFT_VERSION_BEFORE=$(ddev craft --version 2>/dev/null | grep -o 'Craft CMS [0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/Craft CMS //' || echo "")

ddev composer update || pause_on_error "Composer update failed"

# Get Craft CMS version after update
CRAFT_VERSION_AFTER=$(ddev craft --version 2>/dev/null | grep -o 'Craft CMS [0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/Craft CMS //' || echo "")

# Create commit message with Craft version if updated
COMMIT_MESSAGE="Update: Composer dependencies"
if [ -n "$CRAFT_VERSION_BEFORE" ] && [ -n "$CRAFT_VERSION_AFTER" ] && [ "$CRAFT_VERSION_BEFORE" != "$CRAFT_VERSION_AFTER" ]; then
    COMMIT_MESSAGE="$COMMIT_MESSAGE - updates craft to $CRAFT_VERSION_AFTER"
    info "Craft CMS updated from $CRAFT_VERSION_BEFORE to $CRAFT_VERSION_AFTER"
fi

git add composer.lock
git commit -m "$COMMIT_MESSAGE" || true
success "✓ Composer dependencies updated"

# Step 7: Craft migrations
info "Running Craft migrations..."
ddev craft up || pause_on_error "Craft migrations failed"

# Optional: NPM build
if [ "$RUN_NPM_BUILD" = "true" ]; then
    info "Running npm build..."
    $NPM_BUILD_COMMAND || pause_on_error "NPM build failed"
    success "✓ NPM build complete"
fi

# Commit any remaining changes
info "Committing remaining changes..."
git add -A
git commit -m "Update: Post-migration changes" || true

# Verification prompt
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Update steps completed!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}Please check your local DDEV site to verify the updates were successful.${NC}"
echo -e "${YELLOW}Current branch: $UPDATE_BRANCH${NC}"
echo ""
echo "What would you like to do?"
echo "1) Start over (delete branch and restart)"
echo "2) Merge to $REPO_BRANCH and deploy"
echo "3) Merge to $REPO_BRANCH without deploying"
echo "4) Exit (stay on update branch)"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        info "Starting over..."
        git checkout "$REPO_BRANCH"
        git branch -D "$UPDATE_BRANCH"
        exec "$0"  # Restart script
        ;;
    2)
        info "Merging to $REPO_BRANCH and deploying..."
        git checkout "$REPO_BRANCH"
        git merge "$UPDATE_BRANCH" --no-ff -m "Merge $UPDATE_BRANCH"
        git branch -d "$UPDATE_BRANCH"
        
        # Step 8: Push to git
        info "Pushing changes to git..."
        git push origin "$REPO_BRANCH" || pause_on_error "Git push failed"
        success "✓ Changes pushed to git"
        
        # Step 9: Deploy
        info "Deploying to production..."
        "$SCRIPT_DIR/scripts/deploy.sh" || pause_on_error "Deployment failed"
        success "✓ Deployed to production"
        ;;
    3)
        info "Merging to $REPO_BRANCH without deploying..."
        git checkout "$REPO_BRANCH"
        git merge "$UPDATE_BRANCH" --no-ff -m "Merge $UPDATE_BRANCH"
        git branch -d "$UPDATE_BRANCH"
        
        # Step 8: Push to git
        info "Pushing changes to git..."
        git push origin "$REPO_BRANCH" || pause_on_error "Git push failed"
        success "✓ Changes pushed to git"
        info "Skipping deployment. Run '.update/scripts/deploy.sh' manually when ready."
        ;;
    4)
        info "Exiting. You are still on branch: $UPDATE_BRANCH"
        info "To resume, manually merge to $REPO_BRANCH when ready."
        ;;
    *)
        error "Invalid choice"
        ;;
esac

info "========================================="
success "Update process completed!"
info "Log saved to: $LOG_FILE"