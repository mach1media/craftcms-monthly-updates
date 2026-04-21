#!/bin/bash

# Interactive setup script for Craft CMS update configuration
# Supports multi-environment configuration (staging, production)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UPDATE_DIR="$SCRIPT_DIR/.."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Craft CMS Update Configuration Setup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Function to prompt with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        value="${value:-$default}"
    else
        read -p "$prompt: " value
    fi

    eval "$var_name='$value'"
}

# Function to prompt for password (hidden input)
prompt_password() {
    local prompt="$1"
    local var_name="$2"

    read -s -p "$prompt (leave blank to prompt each time): " value
    echo ""
    eval "$var_name='$value'"
}

# Environment selection
echo -e "${YELLOW}Environment Selection${NC}"
echo ""
echo "Which environment(s) would you like to configure?"
echo "Each environment will have its own configuration file:"
echo "• config.staging.yml for staging environment"
echo "• config.production.yml for production environment"
echo ""
echo "1) Production only"
echo "2) Staging only"
echo "3) Both staging and production"
echo ""
read -p "Select option (1-3): " ENV_CHOICE

case "$ENV_CHOICE" in
    1) ENVIRONMENTS=("production") ;;
    2) ENVIRONMENTS=("staging") ;;
    3) ENVIRONMENTS=("staging" "production") ;;
    *) ENVIRONMENTS=("production") ;;
esac

echo ""
echo -e "${GREEN}Will configure: ${ENVIRONMENTS[*]}${NC}"
echo ""

# Function to configure a single environment
configure_environment() {
    local ENV="$1"
    local CONFIG_FILE="$UPDATE_DIR/config.$ENV.yml"

    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Configuring ${ENV^^} Environment${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Environment-specific defaults
    local DEFAULT_BRANCH="$ENV"
    if [ "$ENV" = "production" ]; then
        # Check if production branch exists, otherwise default to main
        if git rev-parse --verify production >/dev/null 2>&1; then
            DEFAULT_BRANCH="production"
        else
            DEFAULT_BRANCH="main"
        fi
    fi

    # Git branch for this environment
    echo -e "${YELLOW}Git Configuration${NC}"
    echo ""
    echo "What git branch is used for $ENV deployment?"
    echo "This branch will be:"
    echo "• Pulled from when syncing from $ENV"
    echo "• Used for deployment to $ENV"
    echo ""
    prompt_with_default "${ENV^} deployment branch" "$DEFAULT_BRANCH" "ENV_BRANCH"

    # Site URL
    echo ""
    echo "What is your $ENV website URL?"
    local URL_EXAMPLE=""
    if [ "$ENV" = "staging" ]; then
        URL_EXAMPLE="e.g., https://staging.example.com"
    else
        URL_EXAMPLE="e.g., https://example.com"
    fi
    prompt_with_default "${ENV^} site URL ($URL_EXAMPLE)" "" "SITE_URL"

    # Server provisioning tool
    echo ""
    echo -e "${YELLOW}Server Configuration${NC}"
    echo ""
    echo "Which tool was used to provision your $ENV server?"
    echo "(Staging and production may use the same or different servers)"
    echo ""
    echo "1) ServerPilot"
    echo "2) Ploi"
    echo "3) Laravel Forge"
    echo "4) fortrabbit"
    echo "5) Cloudways"
    echo "6) Other"
    echo ""
    read -p "Select option (1-6): " SERVER_TOOL

    case "$SERVER_TOOL" in
        1) # ServerPilot
            echo ""
            echo -e "${BLUE}ServerPilot Configuration for ${ENV}${NC}"
            prompt_with_default "ServerPilot app name" "" "APP_NAME"

            # Set default paths
            REMOTE_PROJECT_DIR="/srv/users/serverpilot/apps/$APP_NAME"

            # Confirm public directory
            echo ""
            echo "What is the public web directory name?"
            echo "1) public (default)"
            echo "2) web"
            echo "3) Other"
            read -p "Select option (1-3): " PUBLIC_DIR_OPTION

            case "$PUBLIC_DIR_OPTION" in
                1) PUBLIC_DIR="public" ;;
                2) PUBLIC_DIR="web" ;;
                3) prompt_with_default "Enter public directory name" "" "PUBLIC_DIR" ;;
                *) PUBLIC_DIR="public" ;;
            esac

            REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/$PUBLIC_DIR/uploads"
            SSH_USER="serverpilot"
            ;;

        2) # Ploi
            echo ""
            echo -e "${BLUE}Ploi Configuration for ${ENV}${NC}"
            local DOMAIN_EXAMPLE=""
            if [ "$ENV" = "staging" ]; then
                DOMAIN_EXAMPLE="e.g., staging.example.com"
            else
                DOMAIN_EXAMPLE="e.g., example.com"
            fi
            prompt_with_default "Domain name ($DOMAIN_EXAMPLE)" "" "DOMAIN"

            # Set default paths
            REMOTE_PROJECT_DIR="/home/ploi/$DOMAIN"

            # Confirm public directory
            echo ""
            echo "What is the public web directory name?"
            echo "1) public"
            echo "2) web"
            echo "3) Other"
            read -p "Select option (1-3): " PUBLIC_DIR_OPTION

            case "$PUBLIC_DIR_OPTION" in
                1) PUBLIC_DIR="public" ;;
                2) PUBLIC_DIR="web" ;;
                3) prompt_with_default "Enter public directory name" "" "PUBLIC_DIR" ;;
                *) PUBLIC_DIR="public" ;;
            esac

            REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/$PUBLIC_DIR/uploads"
            SSH_USER="ploi"
            ;;

        3) # Laravel Forge
            echo ""
            echo -e "${BLUE}Laravel Forge Configuration for ${ENV}${NC}"
            local DOMAIN_EXAMPLE=""
            if [ "$ENV" = "staging" ]; then
                DOMAIN_EXAMPLE="e.g., staging.example.com"
            else
                DOMAIN_EXAMPLE="e.g., example.com"
            fi
            prompt_with_default "Domain name ($DOMAIN_EXAMPLE)" "" "DOMAIN"

            # Set default paths
            REMOTE_PROJECT_DIR="/home/forge/$DOMAIN"
            REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/web/uploads"
            SSH_USER="forge"
            PUBLIC_DIR="web"
            ;;

        4) # fortrabbit
            echo ""
            echo -e "${BLUE}fortrabbit Configuration for ${ENV}${NC}"
            prompt_with_default "fortrabbit app name" "" "APP_NAME"

            # Set default paths
            REMOTE_PROJECT_DIR="/srv/app/$APP_NAME"
            REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/web/uploads"
            SSH_USER="$APP_NAME"
            PUBLIC_DIR="web"
            ;;

        5) # Cloudways
            echo ""
            echo -e "${BLUE}Cloudways Configuration for ${ENV}${NC}"
            prompt_with_default "Application folder name (e.g., myapp)" "" "APP_NAME"

            # Set default paths for Cloudways
            REMOTE_PROJECT_DIR="applications/$APP_NAME/public_html"

            # Confirm public directory
            echo ""
            echo "What is the public web directory name?"
            echo "1) web (Craft CMS default)"
            echo "2) public"
            echo "3) Other"
            read -p "Select option (1-3): " PUBLIC_DIR_OPTION

            case "$PUBLIC_DIR_OPTION" in
                1) PUBLIC_DIR="web" ;;
                2) PUBLIC_DIR="public" ;;
                3) prompt_with_default "Enter public directory name" "" "PUBLIC_DIR" ;;
                *) PUBLIC_DIR="web" ;;
            esac

            REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/$PUBLIC_DIR/uploads"

            # Cloudways uses master_xxxxx format for SSH user
            echo ""
            echo "Cloudways SSH username (found in Application Settings > Access Details)"
            echo "Format is usually: master_xxxxxxxx"
            prompt_with_default "SSH username" "" "SSH_USER"
            ;;

        6) # Other
            echo ""
            echo -e "${BLUE}Custom Server Configuration for ${ENV}${NC}"
            prompt_with_default "SSH username" "" "SSH_USER"
            prompt_with_default "Remote project directory (e.g., /var/www/html)" "" "REMOTE_PROJECT_DIR"
            prompt_with_default "Public web directory name (e.g., public, web)" "public" "PUBLIC_DIR"
            REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/$PUBLIC_DIR/uploads"
            ;;
    esac

    # SSH/FTP Configuration
    echo ""
    echo -e "${YELLOW}SSH/FTP Configuration for ${ENV}${NC}"
    echo ""
    echo "SSH and FTP connection details for your $ENV server:"
    echo ""
    prompt_with_default "SSH hostname" "${SITE_URL#https://}" "SSH_HOST"
    SSH_HOST="${SSH_HOST#http://}"  # Remove protocol if present
    SSH_HOST="${SSH_HOST#https://}" # Remove protocol if present
    prompt_with_default "SSH port" "22" "SSH_PORT"

    # SSH/FTP Username
    echo ""
    prompt_with_default "SSH/FTP username" "$SSH_USER" "SSH_USER"

    # FTP Password (optional)
    echo ""
    echo "FTP/SSH password (optional):"
    echo "Leave blank if using SSH key authentication (recommended)"
    prompt_password "FTP/SSH password" "FTP_PASSWORD"

    # Deployment method
    echo ""
    echo -e "${YELLOW}Deployment Configuration for ${ENV}${NC}"
    echo ""
    echo "How do you deploy updates to $ENV?"
    echo ""

    # Different options based on server type
    case "$SERVER_TOOL" in
        1) # ServerPilot
            echo "1) Manual deployment (SSH/SFTP)"
            echo "2) Push to deploy (auto-deploy on git push)"
            echo "3) Other"
            read -p "Select option (1-3): " DEPLOY_OPTION

            case "$DEPLOY_OPTION" in
                1) DEPLOYMENT_METHOD="manual" ;;
                2) DEPLOYMENT_METHOD="push-to-deploy" ;;
                3) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
                *) DEPLOYMENT_METHOD="manual" ;;
            esac
            ;;

        2) # Ploi
            echo "1) Ploi deployment (API)"
            echo "2) Manual deployment"
            echo "3) Push to deploy (auto-deploy on git push)"
            echo "4) Other"
            read -p "Select option (1-4): " DEPLOY_OPTION

            case "$DEPLOY_OPTION" in
                1)
                    DEPLOYMENT_METHOD="ploi"
                    prompt_with_default "Ploi server ID" "" "PLOI_SERVER_ID"
                    prompt_with_default "Ploi site ID" "" "PLOI_SITE_ID"
                    prompt_password "Ploi API token" "PLOI_API_TOKEN"
                    ;;
                2) DEPLOYMENT_METHOD="manual" ;;
                3) DEPLOYMENT_METHOD="push-to-deploy" ;;
                4) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
                *) DEPLOYMENT_METHOD="manual" ;;
            esac
            ;;

        3) # Laravel Forge
            echo "1) Envoyer deployment"
            echo "2) Forge deployment (webhook)"
            echo "3) Manual deployment"
            echo "4) Push to deploy (auto-deploy on git push)"
            echo "5) Other"
            read -p "Select option (1-5): " DEPLOY_OPTION

            case "$DEPLOY_OPTION" in
                1)
                    DEPLOYMENT_METHOD="envoyer"
                    prompt_with_default "Envoyer deployment URL" "" "ENVOYER_URL"
                    ;;
                2)
                    DEPLOYMENT_METHOD="forge"
                    prompt_with_default "Forge deployment URL" "" "FORGE_URL"
                    ;;
                3) DEPLOYMENT_METHOD="manual" ;;
                4) DEPLOYMENT_METHOD="push-to-deploy" ;;
                5) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
                *) DEPLOYMENT_METHOD="manual" ;;
            esac
            ;;

        4) # fortrabbit
            echo "1) Push to deploy (fortrabbit auto-deploys on git push)"
            echo "2) Manual"
            echo "3) Other"
            read -p "Select option (1-3): " DEPLOY_OPTION

            case "$DEPLOY_OPTION" in
                1)
                    DEPLOYMENT_METHOD="push-to-deploy"
                    echo -e "${YELLOW}Note: fortrabbit auto-deploys on git push${NC}"
                    ;;
                2) DEPLOYMENT_METHOD="manual" ;;
                3) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
                *) DEPLOYMENT_METHOD="push-to-deploy" ;;
            esac
            ;;

        5) # Cloudways
            echo "1) Cloudways SSH deployment (git pull, composer, craft commands via SSH)"
            echo "2) Push to deploy (Cloudways auto-deploys on git push)"
            echo "3) Manual deployment"
            echo "4) Other"
            read -p "Select option (1-4): " DEPLOY_OPTION

            case "$DEPLOY_OPTION" in
                1)
                    DEPLOYMENT_METHOD="cloudways"
                    echo -e "${GREEN}Cloudways SSH deployment configured${NC}"
                    echo -e "${YELLOW}Will run: git pull, composer install, craft project-config/apply, craft migrate/all${NC}"
                    ;;
                2)
                    DEPLOYMENT_METHOD="push-to-deploy"
                    echo -e "${YELLOW}Note: Configure Git deployment in Cloudways Application Settings${NC}"
                    ;;
                3) DEPLOYMENT_METHOD="manual" ;;
                4) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
                *) DEPLOYMENT_METHOD="cloudways" ;;
            esac
            ;;

        6) # Other
            echo "1) Push to deploy (auto-deploy on git push)"
            echo "2) Manual deployment"
            echo "3) Other"
            read -p "Select option (1-3): " DEPLOY_OPTION

            case "$DEPLOY_OPTION" in
                1) DEPLOYMENT_METHOD="push-to-deploy" ;;
                2) DEPLOYMENT_METHOD="manual" ;;
                3) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
                *) DEPLOYMENT_METHOD="manual" ;;
            esac
            ;;
    esac

    # Asset storage configuration
    echo ""
    echo -e "${YELLOW}Asset Storage Configuration${NC}"
    echo ""
    echo "What type of filesystem is used for Craft CMS assets on $ENV?"
    echo ""
    echo "1) Local Folder (files stored on server)"
    echo "2) AWS S3"
    echo "3) Digital Ocean Spaces"
    echo "4) Other cloud storage"
    echo ""
    read -p "Select option (1-4): " ASSET_STORAGE

    case "$ASSET_STORAGE" in
        1)
            ASSET_STORAGE_TYPE="local"
            echo -e "${BLUE}Local storage configured - will sync assets using SSH/FTP credentials${NC}"
            ;;
        2)
            ASSET_STORAGE_TYPE="s3"
            echo -e "${BLUE}AWS S3 configured - no local sync needed${NC}"
            ;;
        3)
            ASSET_STORAGE_TYPE="spaces"
            echo -e "${BLUE}Digital Ocean Spaces configured - no local sync needed${NC}"
            ;;
        4)
            ASSET_STORAGE_TYPE="other"
            echo -e "${BLUE}Cloud storage configured - no local sync needed${NC}"
            ;;
        *)
            ASSET_STORAGE_TYPE="local"
            ;;
    esac

    # Shared paths
    echo ""
    echo -e "${YELLOW}Directory Paths${NC}"
    echo ""
    prompt_with_default "Backup directory (relative path)" "storage/backups" "BACKUP_DIR"

    # Only ask for uploads directory if using local storage
    if [ "$ASSET_STORAGE_TYPE" = "local" ]; then
        prompt_with_default "Uploads directory (relative path)" "$PUBLIC_DIR/uploads" "UPLOADS_DIR"
    else
        UPLOADS_DIR="$PUBLIC_DIR/uploads"  # Set default but won't be used
    fi

    # Additional directories to sync
    echo ""
    read -p "Do you need to sync any other directories from $ENV? (y/N): " SYNC_OTHER
    ADDITIONAL_SYNC_DIRS=""
    if [[ "$SYNC_OTHER" =~ ^[Yy]$ ]]; then
        echo "Enter directories to sync (relative to project root, comma-separated)"
        echo "Example: storage/runtime/temp,config/project"
        read -p "Directories: " ADDITIONAL_SYNC_DIRS
    fi

    # Build settings
    echo ""
    echo -e "${YELLOW}Build Settings${NC}"
    echo ""
    read -p "Do you need to run npm build during deployment to $ENV? (y/N): " RUN_BUILD
    if [[ "$RUN_BUILD" =~ ^[Yy]$ ]]; then
        RUN_NPM_BUILD="true"
        prompt_with_default "NPM build command" "npm run build" "NPM_BUILD_COMMAND"
    else
        RUN_NPM_BUILD="false"
        NPM_BUILD_COMMAND="npm run build"
    fi

    # Create config file
    echo ""
    echo -e "${BLUE}Creating configuration file for ${ENV}...${NC}"

    cat > "$CONFIG_FILE" << EOF
# Craft CMS Update Configuration - ${ENV^^} Environment
# Generated on $(date)

# Environment identifier (do not change)
environment: $ENV

# Git settings
branch: $ENV_BRANCH

# Site URL
site_url: $SITE_URL

# SSH settings
ssh_host: $SSH_HOST
ssh_user: $SSH_USER
ssh_port: $SSH_PORT
remote_project_dir: $REMOTE_PROJECT_DIR

# Shared directory paths (same relative paths on local and remote)
backup_dir: $BACKUP_DIR
uploads_dir: $UPLOADS_DIR

# Asset storage configuration
asset_storage_type: $ASSET_STORAGE_TYPE

# Remote uploads path
remote_uploads_dir: $REMOTE_UPLOADS_DIR
EOF

    # Add FTP settings
    cat >> "$CONFIG_FILE" << EOF

# FTP/SSH settings for file operations
ftp_host: $SSH_HOST
ftp_user: $SSH_USER
ftp_password: $FTP_PASSWORD
EOF

    # Add additional sync directories if specified
    if [ -n "$ADDITIONAL_SYNC_DIRS" ]; then
        cat >> "$CONFIG_FILE" << EOF

# Additional directories to sync
additional_sync_dirs: $ADDITIONAL_SYNC_DIRS
EOF
    else
        cat >> "$CONFIG_FILE" << EOF

# Additional directories to sync
additional_sync_dirs:
EOF
    fi

    cat >> "$CONFIG_FILE" << EOF

# Deployment method
deployment_method: $DEPLOYMENT_METHOD
EOF

    # Add deployment-specific configuration
    case "$DEPLOYMENT_METHOD" in
        "ploi")
            if [ -n "$PLOI_SERVER_ID" ]; then
                cat >> "$CONFIG_FILE" << EOF

# Ploi settings
ploi_server_id: $PLOI_SERVER_ID
ploi_site_id: $PLOI_SITE_ID
ploi_api_token: $PLOI_API_TOKEN
EOF
            fi
            ;;
        "envoyer")
            if [ -n "$ENVOYER_URL" ]; then
                cat >> "$CONFIG_FILE" << EOF

# Envoyer settings
envoyer_url: $ENVOYER_URL
EOF
            fi
            ;;
        "forge")
            if [ -n "$FORGE_URL" ]; then
                cat >> "$CONFIG_FILE" << EOF

# Forge settings
forge_url: $FORGE_URL
EOF
            fi
            ;;
    esac

    # Add build settings
    cat >> "$CONFIG_FILE" << EOF

# Build settings
run_npm_build: $RUN_NPM_BUILD
npm_build_command: $NPM_BUILD_COMMAND
EOF

    echo ""
    echo -e "${GREEN}Configuration file created: $CONFIG_FILE${NC}"

    # Return server info for summary
    case "$SERVER_TOOL" in
        1) SERVER_NAME="ServerPilot" ;;
        2) SERVER_NAME="Ploi" ;;
        3) SERVER_NAME="Laravel Forge" ;;
        4) SERVER_NAME="fortrabbit" ;;
        5) SERVER_NAME="Cloudways" ;;
        6) SERVER_NAME="Custom" ;;
        *) SERVER_NAME="Unknown" ;;
    esac

    # Store summary info in global array
    ENV_SUMMARIES+=("$ENV|$SERVER_NAME|$REMOTE_PROJECT_DIR|$SSH_USER@$SSH_HOST:$SSH_PORT|$DEPLOYMENT_METHOD")
}

# Array to store environment summaries
declare -a ENV_SUMMARIES=()

# Configure each selected environment
for env in "${ENVIRONMENTS[@]}"; do
    configure_environment "$env"
done

# Make scripts executable
chmod +x "$UPDATE_DIR/update.sh" "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}Update scripts are now executable${NC}"

# Check for legacy config.yml and offer migration
if [ -f "$UPDATE_DIR/config.yml" ]; then
    echo ""
    echo -e "${YELLOW}Legacy Configuration Detected${NC}"
    echo "Found existing config.yml file. This is now deprecated in favor of"
    echo "environment-specific config files (config.staging.yml, config.production.yml)."
    echo ""
    read -p "Would you like to remove the legacy config.yml? (y/N): " REMOVE_LEGACY
    if [[ "$REMOVE_LEGACY" =~ ^[Yy]$ ]]; then
        rm "$UPDATE_DIR/config.yml"
        echo -e "${GREEN}Removed legacy config.yml${NC}"
    else
        echo -e "${YELLOW}Legacy config.yml retained. Note: It will be ignored by updated scripts.${NC}"
    fi
fi

# Setup npm scripts
echo ""
echo -e "${YELLOW}NPM Scripts Setup${NC}"
read -p "Do you want to setup npm scripts for easy command access? (Y/n): " SETUP_NPM
if [[ ! "$SETUP_NPM" =~ ^[Nn]$ ]]; then
    "$SCRIPT_DIR/setup-npm-scripts.sh"
else
    echo "Skipped npm scripts setup. You can run it later with: .update/scripts/setup-npm-scripts.sh"
fi

# Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Setup Complete!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Configuration summary:"
echo ""

for summary in "${ENV_SUMMARIES[@]}"; do
    IFS='|' read -r env server_name remote_path ssh_info deploy_method <<< "$summary"
    echo -e "${YELLOW}${env^^}:${NC}"
    echo "  - Server type: $server_name"
    echo "  - Remote path: $remote_path"
    echo "  - SSH: $ssh_info"
    echo "  - Deployment: $deploy_method"
    echo "  - Config file: .update/config.$env.yml"
    echo ""
done

echo -e "${YELLOW}Environment Detection:${NC}"
echo "Scripts automatically detect the target environment based on your current git branch:"
echo "  - 'staging' branch  staging environment"
echo "  - 'production' or 'main' branch  production environment"
echo "  - Feature branches will prompt you to select an environment"
echo ""
echo "You can also specify the environment explicitly:"
echo "  npm run update/sync-db -- --staging"
echo "  npm run update/sync-db -- --production"
echo "  npm run update/sync-db -- --env=staging"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review configurations:"
for env in "${ENVIRONMENTS[@]}"; do
    echo "   cat .update/config.$env.yml"
done
echo "2. Test SSH connection:"
echo "   npm run update/test-ssh -- --staging"
echo "   npm run update/test-ssh -- --production"
echo "3. Sync database from an environment:"
echo "   npm run update/sync-db"
echo ""
