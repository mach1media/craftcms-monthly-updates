#!/bin/bash

# Connection Test Script
# Tests actual connections to production servers after setup is complete

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Source helpers
source "$SCRIPT_DIR/../scripts/helpers.sh"
source "$SCRIPT_DIR/../scripts/remote-exec.sh"

echo -e "${CYAN}🔗 Connection Test Suite${NC}"
echo -e "${CYAN}=======================${NC}"
echo ""

# Check if config file exists
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config.yml}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Config file not found: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Run the setup script first: .update/scripts/interactive-setup.sh${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Configuration Summary${NC}"
echo -e "Config file: $CONFIG_FILE"
echo -e "Production URL: $(get_config 'production_url')"
echo -e "SSH Host: $(get_config 'ssh_host')"
echo -e "SSH User: $(get_config 'ssh_user')"
echo -e "SSH Port: $(get_config 'ssh_port' '22')"
echo -e "Asset Storage: $(get_config 'asset_storage_type')"
echo -e "Deployment: $(get_config 'deployment_method')"
echo ""

# Test 1: SSH Connection
test_ssh_connection() {
    echo -e "${BLUE}🔐 Testing SSH Connection${NC}"
    echo -e "Attempting to connect to $(get_config 'ssh_user')@$(get_config 'ssh_host')..."
    
    if execute_remote_command "echo 'SSH connection successful'" false >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SSH connection successful${NC}"
        return 0
    else
        echo -e "${RED}❌ SSH connection failed${NC}"
        echo -e "${YELLOW}💡 Troubleshooting tips:${NC}"
        echo "   • Check SSH key is added to ssh-agent: ssh-add -l"
        echo "   • Test manual connection: ssh $(get_config 'ssh_user')@$(get_config 'ssh_host')"
        echo "   • Verify SSH key permissions: chmod 600 ~/.ssh/id_rsa"
        echo "   • Check server firewall allows SSH connections"
        return 1
    fi
}

# Test 2: Remote Directory Access
test_remote_directory() {
    echo -e "${BLUE}📁 Testing Remote Directory Access${NC}"
    
    local remote_dir=$(get_config 'remote_project_dir')
    echo -e "Checking access to: $remote_dir"
    
    if execute_remote_command "[ -d '$remote_dir' ] && echo 'Directory exists'" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Remote project directory accessible${NC}"
        
        # Test if we can read the directory
        local dir_contents=$(execute_remote_command "ls -la '$remote_dir' | head -5" 2>/dev/null || echo "")
        if [ -n "$dir_contents" ]; then
            echo -e "${GREEN}✅ Can read directory contents${NC}"
        else
            echo -e "${YELLOW}⚠️  Directory exists but may have permission issues${NC}"
        fi
        return 0
    else
        echo -e "${RED}❌ Cannot access remote project directory${NC}"
        echo -e "${YELLOW}💡 Troubleshooting tips:${NC}"
        echo "   • Verify the path in your config: $remote_dir"
        echo "   • Check directory permissions on the server"
        echo "   • Ensure the SSH user has access to this directory"
        return 1
    fi
}

# Test 3: Craft CMS Detection
test_craft_detection() {
    echo -e "${BLUE}⚙️  Testing Craft CMS Detection${NC}"
    
    local craft_files=("craft" "composer.json" "config/app.php" "config/db.php")
    local found_files=0
    
    for file in "${craft_files[@]}"; do
        if execute_remote_command "[ -f '$file' ]" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Found: $file${NC}"
            found_files=$((found_files + 1))
        else
            echo -e "${YELLOW}⚠️  Missing: $file${NC}"
        fi
    done
    
    if [ $found_files -ge 2 ]; then
        echo -e "${GREEN}✅ Craft CMS installation detected${NC}"
        return 0
    else
        echo -e "${RED}❌ Craft CMS installation not clearly detected${NC}"
        echo -e "${YELLOW}💡 Make sure the remote_project_dir points to your Craft CMS root${NC}"
        return 1
    fi
}

# Test 4: Database Connection (via Craft CLI)
test_database_connection() {
    echo -e "${BLUE}🗄️  Testing Database Connection${NC}"
    
    # Try to run a simple Craft command to test database connectivity
    if execute_remote_command "./craft --version" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Craft CLI accessible${NC}"
        
        # Try a database operation
        if execute_remote_command "./craft help" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Craft CLI working (database likely accessible)${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Craft CLI runs but may have database issues${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Craft CLI not accessible or not executable${NC}"
        echo -e "${YELLOW}💡 This might be normal if Craft is not in the project root${NC}"
        return 1
    fi
}

# Test 5: Backup Directory
test_backup_directory() {
    echo -e "${BLUE}💾 Testing Backup Directory${NC}"
    
    local backup_dir=$(get_config 'backup_dir')
    echo -e "Checking backup directory: $backup_dir"
    
    if execute_remote_command "mkdir -p '$backup_dir' && [ -d '$backup_dir' ]" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backup directory accessible/created${NC}"
        
        # Test write permissions
        if execute_remote_command "touch '$backup_dir/test_write.tmp' && rm '$backup_dir/test_write.tmp'" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Can write to backup directory${NC}"
            return 0
        else
            echo -e "${RED}❌ Cannot write to backup directory${NC}"
            echo -e "${YELLOW}💡 Check directory permissions${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Cannot access or create backup directory${NC}"
        return 1
    fi
}

# Test 6: Asset Storage (if local)
test_asset_storage() {
    echo -e "${BLUE}🖼️  Testing Asset Storage${NC}"
    
    local asset_storage_type=$(get_config 'asset_storage_type')
    echo -e "Asset storage type: $asset_storage_type"
    
    case "$asset_storage_type" in
        "local")
            local uploads_dir=$(get_config 'uploads_dir')
            local remote_uploads_dir=$(get_config 'remote_uploads_dir')
            
            echo -e "Checking uploads directory: $remote_uploads_dir"
            
            if execute_remote_command "[ -d '$remote_uploads_dir' ]" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Remote uploads directory exists${NC}"
                
                # Check if there are any assets
                local asset_count=$(execute_remote_command "find '$remote_uploads_dir' -type f | wc -l" 2>/dev/null | xargs)
                if [ -n "$asset_count" ] && [ "$asset_count" -gt 0 ]; then
                    echo -e "${GREEN}✅ Found $asset_count asset files${NC}"
                else
                    echo -e "${YELLOW}⚠️  No asset files found (might be normal for new sites)${NC}"
                fi
                return 0
            else
                echo -e "${YELLOW}⚠️  Remote uploads directory not found${NC}"
                echo -e "${YELLOW}💡 This might be normal if no assets have been uploaded yet${NC}"
                return 1
            fi
            ;;
        "s3"|"spaces"|"other")
            echo -e "${GREEN}✅ Cloud storage configured - no local sync needed${NC}"
            return 0
            ;;
        *)
            echo -e "${YELLOW}⚠️  Unknown asset storage type: $asset_storage_type${NC}"
            return 1
            ;;
    esac
}

# Test 7: Additional Directories
test_additional_directories() {
    echo -e "${BLUE}📂 Testing Additional Sync Directories${NC}"
    
    local additional_dirs=$(get_config 'additional_sync_dirs')
    
    if [ -z "$additional_dirs" ]; then
        echo -e "${GREEN}✅ No additional directories configured${NC}"
        return 0
    fi
    
    echo -e "Additional directories: $additional_dirs"
    
    IFS=',' read -ra DIRS <<< "$additional_dirs"
    local found_dirs=0
    
    for dir in "${DIRS[@]}"; do
        dir=$(echo "$dir" | xargs)  # Trim whitespace
        
        if [ -n "$dir" ]; then
            if execute_remote_command "[ -d '$dir' ]" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Found: $dir${NC}"
                found_dirs=$((found_dirs + 1))
            else
                echo -e "${YELLOW}⚠️  Not found: $dir${NC}"
            fi
        fi
    done
    
    if [ $found_dirs -gt 0 ]; then
        echo -e "${GREEN}✅ Found $found_dirs additional directories${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No additional directories found${NC}"
        return 1
    fi
}

# Main test runner
main() {
    local failed_tests=0
    local total_tests=0
    
    echo -e "${YELLOW}Running connection tests...${NC}"
    echo ""
    
    # Run all tests
    tests=(
        "test_ssh_connection"
        "test_remote_directory"
        "test_craft_detection"
        "test_database_connection"
        "test_backup_directory"
        "test_asset_storage"
        "test_additional_directories"
    )
    
    for test_func in "${tests[@]}"; do
        total_tests=$((total_tests + 1))
        if ! $test_func; then
            failed_tests=$((failed_tests + 1))
        fi
        echo ""
    done
    
    # Summary
    echo -e "${CYAN}📊 Connection Test Results${NC}"
    echo -e "${CYAN}=========================${NC}"
    echo -e "Total tests: $total_tests"
    echo -e "${GREEN}Passed: $((total_tests - failed_tests))${NC}"
    echo -e "${RED}Failed: $failed_tests${NC}"
    echo ""
    
    if [ $failed_tests -eq 0 ]; then
        echo -e "${GREEN}🎉 All connection tests passed!${NC}"
        echo -e "${GREEN}Your update scripts are ready to use.${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "• Run 'npm run update' to start your first monthly update"
        echo "• The scripts will guide you through the process"
        echo ""
        return 0
    else
        echo -e "${YELLOW}⚠️  $failed_tests connection test(s) failed.${NC}"
        echo -e "${YELLOW}You may still be able to run updates, but some features might not work.${NC}"
        echo ""
        echo -e "${CYAN}Consider fixing the issues above before running updates.${NC}"
        echo ""
        return 1
    fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi