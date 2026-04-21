#!/bin/bash

# NPM Scripts Setup Helper
# Adds update scripts to existing package.json or creates a new one

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
PACKAGE_JSON="$PROJECT_ROOT/package.json"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# NPM scripts to add - using explicit arrays to ensure proper ordering
SCRIPT_NAMES=(
    "update"
    "sync-db"
    "sync-assets"
    "sync-directories"
    "update/deploy"
    "update/setup"
    "update/test-ssh"
    "update/test"
    "update/test-connections"
    "update/logs"
)

SCRIPT_COMMANDS=(
    ".update/update.sh"
    ".update/scripts/sync-db.sh"
    ".update/scripts/sync-assets.sh"
    ".update/scripts/sync-directories.sh"
    ".update/scripts/deploy.sh"
    ".update/scripts/interactive-setup.sh"
    "echo 'Testing SSH connection...' && .update/scripts/test-ssh.sh"
    ".update/tests/run-tests.sh"
    ".update/tests/test-connections.sh"
    "ls -la .update/logs/ && echo 'Latest log:' && ls -t .update/logs/*.log 2>/dev/null | head -1 | xargs tail -20"
)

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to create a new package.json
create_package_json() {
    info "Creating new package.json..."
    
    # Get project name from directory
    PROJECT_NAME=$(basename "$PROJECT_ROOT")
    
    cat > "$PACKAGE_JSON" << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Craft CMS project with monthly update scripts",
  "private": true,
  "scripts": {
EOF

    # Add update scripts
    local first=true
    for i in "${!SCRIPT_NAMES[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$PACKAGE_JSON"
        fi
        echo -n "    \"${SCRIPT_NAMES[$i]}\": \"${SCRIPT_COMMANDS[$i]}\"" >> "$PACKAGE_JSON"
    done
    
    cat >> "$PACKAGE_JSON" << EOF

  },
  "engines": {
    "node": ">=14.0.0"
  }
}
EOF
    
    success "Created new package.json with update scripts"
}

# Function to add scripts to existing package.json
add_to_existing_package_json() {
    info "Adding update scripts to existing package.json..."
    
    # Check if jq is available for JSON manipulation
    if command -v jq >/dev/null 2>&1; then
        # Use jq for safe JSON manipulation
        local temp_file=$(mktemp)
        
        # Read existing package.json and add scripts
        jq_script='.'
        for i in "${!SCRIPT_NAMES[@]}"; do
            jq_script="$jq_script | .scripts[\"${SCRIPT_NAMES[$i]}\"] = \"${SCRIPT_COMMANDS[$i]}\""
        done
        
        jq "$jq_script" "$PACKAGE_JSON" > "$temp_file"
        mv "$temp_file" "$PACKAGE_JSON"
        
        success "Added update scripts using jq"
    else
        # Fallback: Node.js script for JSON manipulation
        info "jq not found, using Node.js for JSON manipulation..."
        
        if command -v node >/dev/null 2>&1; then
            # Create a temporary Node.js script
            cat > /tmp/add_scripts.js << 'EOF'
const fs = require('fs');
const path = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));

// Ensure scripts object exists
if (!pkg.scripts) {
    pkg.scripts = {};
}

// Add update scripts
const updateScripts = {
    "update": ".update/update.sh",
    "sync-db": ".update/scripts/sync-db.sh",
    "sync-assets": ".update/scripts/sync-assets.sh", 
    "sync-directories": ".update/scripts/sync-directories.sh",
    "update/deploy": ".update/scripts/deploy.sh",
    "update/setup": ".update/scripts/interactive-setup.sh",
    "update/test-ssh": "echo 'Testing SSH connection...' && .update/scripts/test-ssh.sh",
    "update/test": ".update/tests/run-tests.sh",
    "update/test-connections": ".update/tests/test-connections.sh",
    "update/logs": "ls -la .update/logs/ && echo 'Latest log:' && ls -t .update/logs/*.log 2>/dev/null | head -1 | xargs tail -20"
};

Object.assign(pkg.scripts, updateScripts);

fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');
EOF
            
            node /tmp/add_scripts.js "$PACKAGE_JSON"
            rm /tmp/add_scripts.js
            
            success "Added update scripts using Node.js"
        else
            # Manual fallback - warn user
            warning "Neither jq nor Node.js found for safe JSON manipulation"
            echo ""
            echo "Please manually add these scripts to your package.json:"
            echo ""
            for i in "${!SCRIPT_NAMES[@]}"; do
                echo "  \"${SCRIPT_NAMES[$i]}\": \"${SCRIPT_COMMANDS[$i]}\","
            done
            echo ""
            echo "Add them to the \"scripts\" section of your package.json file."
            return 1
        fi
    fi
}

# Function to check for conflicting scripts
check_for_conflicts() {
    if command -v jq >/dev/null 2>&1; then
        local conflicts=()
        for i in "${!SCRIPT_NAMES[@]}"; do
            if jq -r ".scripts[\"${SCRIPT_NAMES[$i]}\"] // empty" "$PACKAGE_JSON" | grep -q .; then
                conflicts+=("${SCRIPT_NAMES[$i]}")
            fi
        done
        
        if [ ${#conflicts[@]} -gt 0 ]; then
            warning "Found existing scripts that will be overwritten:"
            for conflict in "${conflicts[@]}"; do
                local existing=$(jq -r ".scripts[\"$conflict\"]" "$PACKAGE_JSON")
                echo "  $conflict: $existing"
            done
            echo ""
            read -p "Do you want to continue and overwrite these scripts? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "Aborted by user"
                exit 1
            fi
        fi
    fi
}

# Main logic
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}NPM Scripts Setup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [ -f "$PACKAGE_JSON" ]; then
    info "Found existing package.json"
    
    # Check for conflicts
    check_for_conflicts
    
    # Add scripts to existing file
    add_to_existing_package_json
    
    echo ""
    info "Updated package.json with Craft CMS update scripts"
else
    info "No package.json found"
    
    # Create new package.json
    create_package_json
    
    echo ""
    info "Created package.json with Craft CMS update scripts"
fi

echo ""
echo -e "${GREEN}Available npm commands:${NC}"
echo "• npm run update                - Run complete update workflow"
echo "• npm run sync-db               - Sync database from production"
echo "• npm run sync-assets           - Sync assets from production"
echo "• npm run sync-directories      - Sync additional directories"
echo "• npm run update/deploy         - Deploy to production"
echo "• npm run update/setup          - Interactive setup wizard"
echo "• npm run update/test-ssh       - Test SSH connection"
echo "• npm run update/test           - Run all unit and integration tests"
echo "• npm run update/test-connections - Test connections to production"
echo "• npm run update/logs           - View recent update logs"
echo ""
success "NPM scripts setup complete!"