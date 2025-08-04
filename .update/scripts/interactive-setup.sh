#!/bin/bash

# Interactive setup script for Craft CMS update configuration

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/../config.yml"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Start configuration
echo -e "${YELLOW}Basic Configuration${NC}"
echo ""

# Git branch
prompt_with_default "Git branch" "main" "BRANCH"

# Production URL
prompt_with_default "Production site URL (e.g., https://example.com)" "" "PRODUCTION_URL"

# Server provisioning tool
echo ""
echo -e "${YELLOW}Server Configuration${NC}"
echo ""
echo "Which tool was used to provision the server?"
echo "1) ServerPilot"
echo "2) Ploi"
echo "3) Laravel Forge"
echo "4) fortrabbit"
echo "5) Other"
echo ""
read -p "Select option (1-5): " SERVER_TOOL

case "$SERVER_TOOL" in
    1) # ServerPilot
        echo ""
        echo -e "${BLUE}ServerPilot Configuration${NC}"
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
        echo -e "${BLUE}Ploi Configuration${NC}"
        prompt_with_default "Domain name (e.g., example.com)" "" "DOMAIN"
        
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
        echo -e "${BLUE}Laravel Forge Configuration${NC}"
        prompt_with_default "Domain name (e.g., example.com)" "" "DOMAIN"
        
        # Set default paths
        REMOTE_PROJECT_DIR="/home/forge/$DOMAIN"
        REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/web/uploads"
        SSH_USER="forge"
        PUBLIC_DIR="web"
        ;;
        
    4) # fortrabbit
        echo ""
        echo -e "${BLUE}fortrabbit Configuration${NC}"
        prompt_with_default "fortrabbit app name" "" "APP_NAME"
        
        # Set default paths
        REMOTE_PROJECT_DIR="/srv/app/$APP_NAME"
        REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/web/uploads"
        SSH_USER="$APP_NAME"
        PUBLIC_DIR="web"
        ;;
        
    5) # Other
        echo ""
        echo -e "${BLUE}Custom Server Configuration${NC}"
        prompt_with_default "SSH username" "" "SSH_USER"
        prompt_with_default "Remote project directory (e.g., /var/www/html)" "" "REMOTE_PROJECT_DIR"
        prompt_with_default "Public web directory name (e.g., public, web)" "public" "PUBLIC_DIR"
        REMOTE_UPLOADS_DIR="$REMOTE_PROJECT_DIR/$PUBLIC_DIR/uploads"
        ;;
esac

# Common SSH settings
echo ""
echo -e "${YELLOW}SSH Configuration${NC}"
prompt_with_default "SSH hostname" "${PRODUCTION_URL#https://}" "SSH_HOST"
SSH_HOST="${SSH_HOST#http://}"  # Remove protocol if present
SSH_HOST="${SSH_HOST#https://}" # Remove protocol if present
prompt_with_default "SSH port" "22" "SSH_PORT"

# Deployment method
echo ""
echo -e "${YELLOW}Deployment Configuration${NC}"
echo ""
echo "How do you deploy to production?"

# Different options based on server type
case "$SERVER_TOOL" in
    1) # ServerPilot
        echo "1) Manual deployment (SSH/SFTP)"
        echo "2) GitHub Actions (auto-deploy on push)"
        echo "3) Other"
        read -p "Select option (1-3): " DEPLOY_OPTION
        
        case "$DEPLOY_OPTION" in
            1) DEPLOYMENT_METHOD="manual" ;;
            2) DEPLOYMENT_METHOD="github-actions" ;;
            3) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
            *) DEPLOYMENT_METHOD="manual" ;;
        esac
        ;;
        
    2) # Ploi
        echo "1) Ploi deployment (API)"
        echo "2) Manual deployment"
        echo "3) GitHub Actions"
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
            3) DEPLOYMENT_METHOD="github-actions" ;;
            4) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
            *) DEPLOYMENT_METHOD="manual" ;;
        esac
        ;;
        
    3) # Laravel Forge
        echo "1) Envoyer deployment"
        echo "2) Forge deployment (webhook)"
        echo "3) Manual deployment"
        echo "4) GitHub Actions"
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
            4) DEPLOYMENT_METHOD="github-actions" ;;
            5) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
            *) DEPLOYMENT_METHOD="manual" ;;
        esac
        ;;
        
    4) # fortrabbit
        echo "1) Automatic (git push to fortrabbit)"
        echo "2) GitHub Actions"
        echo "3) Manual"
        echo "4) Other"
        read -p "Select option (1-4): " DEPLOY_OPTION
        
        case "$DEPLOY_OPTION" in
            1) 
                DEPLOYMENT_METHOD="github-actions"
                echo -e "${YELLOW}Note: fortrabbit auto-deploys on git push${NC}"
                ;;
            2) DEPLOYMENT_METHOD="github-actions" ;;
            3) DEPLOYMENT_METHOD="manual" ;;
            4) prompt_with_default "Enter deployment method" "" "DEPLOYMENT_METHOD" ;;
            *) DEPLOYMENT_METHOD="github-actions" ;;
        esac
        ;;
        
    5) # Other
        echo "1) GitHub Actions"
        echo "2) Manual deployment"
        echo "3) Other"
        read -p "Select option (1-3): " DEPLOY_OPTION
        
        case "$DEPLOY_OPTION" in
            1) DEPLOYMENT_METHOD="github-actions" ;;
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
echo "What type of filesystem is used for Craft CMS assets?"
echo "1) Local Folder (files stored on server)"
echo "2) AWS S3"
echo "3) Digital Ocean Spaces"
echo "4) Other cloud storage"
echo ""
read -p "Select option (1-4): " ASSET_STORAGE

case "$ASSET_STORAGE" in
    1) 
        ASSET_STORAGE_TYPE="local"
        # FTP settings for local asset sync
        echo ""
        echo -e "${YELLOW}FTP Configuration (for asset sync)${NC}"
        prompt_with_default "FTP hostname" "$SSH_HOST" "FTP_HOST"
        prompt_with_default "FTP username" "$SSH_USER" "FTP_USER"
        prompt_password "FTP/SSH password" "FTP_PASSWORD"
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
prompt_with_default "Backup directory (relative path)" "storage/backups" "BACKUP_DIR"

# Only ask for uploads directory if using local storage
if [ "$ASSET_STORAGE_TYPE" = "local" ]; then
    prompt_with_default "Uploads directory (relative path)" "$PUBLIC_DIR/uploads" "UPLOADS_DIR"
else
    UPLOADS_DIR="$PUBLIC_DIR/uploads"  # Set default but won't be used
fi

# Additional directories to sync
echo ""
echo -e "${YELLOW}Additional Directory Sync${NC}"
echo ""
read -p "Do you need to sync any other directories from production? (y/N): " SYNC_OTHER
ADDITIONAL_SYNC_DIRS=""
if [[ "$SYNC_OTHER" =~ ^[Yy]$ ]]; then
    echo "Enter directories to sync (relative to project root, comma-separated)"
    echo "Example: storage/runtime/temp,config/project"
    read -p "Directories: " ADDITIONAL_SYNC_DIRS
fi

# Build settings
echo ""
echo -e "${YELLOW}Build Settings${NC}"
read -p "Do you need to run npm build during updates? (y/N): " RUN_BUILD
if [[ "$RUN_BUILD" =~ ^[Yy]$ ]]; then
    RUN_NPM_BUILD="true"
    prompt_with_default "NPM build command" "npm run build" "NPM_BUILD_COMMAND"
else
    RUN_NPM_BUILD="false"
    NPM_BUILD_COMMAND="npm run build"
fi

# Create config file
echo ""
echo -e "${BLUE}Creating configuration file...${NC}"

cat > "$CONFIG_FILE" << EOF
# Craft CMS Update Configuration
# Generated on $(date)

# Git settings
branch: $BRANCH

# Production site
production_url: $PRODUCTION_URL

# SSH settings for automated database sync
ssh_host: $SSH_HOST
ssh_user: $SSH_USER
ssh_port: $SSH_PORT
remote_project_dir: $REMOTE_PROJECT_DIR

# Shared directory paths (same relative paths on local and remote)
backup_dir: $BACKUP_DIR
uploads_dir: $UPLOADS_DIR

# Asset storage configuration
asset_storage_type: $ASSET_STORAGE_TYPE

# Remote server paths
remote_uploads_dir: $REMOTE_UPLOADS_DIR
EOF

# Only add FTP settings if using local storage
if [ "$ASSET_STORAGE_TYPE" = "local" ]; then
    cat >> "$CONFIG_FILE" << EOF

# FTP settings for asset sync
ftp_host: $FTP_HOST
ftp_user: $FTP_USER
ftp_password: $FTP_PASSWORD
EOF
fi

# Add additional sync directories if specified
if [ -n "$ADDITIONAL_SYNC_DIRS" ]; then
    cat >> "$CONFIG_FILE" << EOF

# Additional directories to sync
additional_sync_dirs: $ADDITIONAL_SYNC_DIRS
EOF
fi

cat >> "$CONFIG_FILE" << EOF

# Deployment method: $DEPLOYMENT_METHOD
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
echo -e "${GREEN}✓ Configuration file created at: $CONFIG_FILE${NC}"

# Make scripts executable
chmod +x "$SCRIPT_DIR/../update.sh" "$SCRIPT_DIR"/*.sh

echo -e "${GREEN}✓ Update scripts are now executable${NC}"

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
case "$SERVER_TOOL" in
    1) SERVER_NAME="ServerPilot" ;;
    2) SERVER_NAME="Ploi" ;;
    3) SERVER_NAME="Laravel Forge" ;;
    4) SERVER_NAME="fortrabbit" ;;
    5) SERVER_NAME="Custom" ;;
    *) SERVER_NAME="Unknown" ;;
esac
echo "- Server type: $SERVER_NAME"
echo "- Remote path: $REMOTE_PROJECT_DIR"
echo "- SSH: $SSH_USER@$SSH_HOST:$SSH_PORT"
echo "- Deployment: $DEPLOYMENT_METHOD"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the configuration: cat $CONFIG_FILE"
echo "2. Test SSH connection: npm run update/test-ssh"
echo "3. Run monthly update: npm run update"
echo ""