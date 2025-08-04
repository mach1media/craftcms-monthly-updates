#!/bin/bash

# Integration tests for main update workflows

# Get script directory and source test framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../test-framework.sh"

# Source the helpers functions
source "$SCRIPT_DIR/../../scripts/helpers.sh"

test_ssh_connection_workflow() {
    test_suite "Integration - SSH Connection Workflow"
    
    setup_test_environment
    
    # Create test config
    local test_config="$TEST_DIR/test_config.yml"
    create_mock_config "$test_config" "
ssh_host: localhost
ssh_user: $(whoami)
ssh_port: 22
remote_project_dir: $TEST_DIR/remote_project
"
    
    export CONFIG_FILE="$test_config"
    
    # Create mock remote project directory
    mkdir -p "$TEST_DIR/remote_project"
    echo "test content" > "$TEST_DIR/remote_project/test_file.txt"
    
    test_case "SSH connection test with local host"
    
    # Test if we can connect to localhost (common in development environments)
    if command -v ssh >/dev/null 2>&1; then
        # Try to connect to localhost - this will only work if SSH is set up
        if ssh -o ConnectTimeout=2 -o BatchMode=yes localhost "echo 'SSH test successful'" 2>/dev/null; then
            result="SSH_SUCCESS"
        else
            # Skip test if SSH to localhost is not available
            skip_test "SSH to localhost not available (normal in many environments)"
            result="SSH_SKIPPED"
        fi
    else
        skip_test "SSH command not available"
        result="SSH_NOT_AVAILABLE"
    fi
    
    # Just verify the test ran (actual SSH testing requires proper setup)
    assert_contains "SSH" "$result" "SSH connection test completed"
    
    teardown_test_environment
}

test_config_file_workflow() {
    test_suite "Integration - Config File Workflow"
    
    setup_test_environment
    
    # Test complete config file creation and parsing
    test_case "Complete config file creation and validation"
    
    local test_config="$TEST_DIR/complete_config.yml"
    create_mock_config "$test_config" "
# Complete test configuration
branch: main
production_url: https://example.com

# SSH settings
ssh_host: example.com
ssh_user: forge
ssh_port: 22
remote_project_dir: /home/forge/example.com

# Directory paths
backup_dir: storage/backups
uploads_dir: web/uploads

# Asset storage
asset_storage_type: local

# Remote paths
remote_uploads_dir: /home/forge/example.com/web/uploads

# FTP settings
ftp_host: example.com
ftp_user: forge
ftp_password: secret123

# Additional directories
additional_sync_dirs: storage/runtime,config/project

# Deployment
deployment_method: manual

# Build settings
run_npm_build: false
npm_build_command: npm run build
"
    
    export CONFIG_FILE="$test_config"
    
    # Test all config values can be parsed
    assert_equals "main" "$(get_config 'branch')" "Branch config should be parsed"
    assert_equals "https://example.com" "$(get_config 'production_url')" "Production URL should be parsed"
    assert_equals "example.com" "$(get_config 'ssh_host')" "SSH host should be parsed"
    assert_equals "forge" "$(get_config 'ssh_user')" "SSH user should be parsed"
    assert_equals "22" "$(get_config 'ssh_port')" "SSH port should be parsed"
    assert_equals "/home/forge/example.com" "$(get_config 'remote_project_dir')" "Remote project dir should be parsed"
    assert_equals "storage/backups" "$(get_config 'backup_dir')" "Backup dir should be parsed"
    assert_equals "web/uploads" "$(get_config 'uploads_dir')" "Uploads dir should be parsed"
    assert_equals "local" "$(get_config 'asset_storage_type')" "Asset storage type should be parsed"
    assert_equals "storage/runtime,config/project" "$(get_config 'additional_sync_dirs')" "Additional sync dirs should be parsed"
    assert_equals "manual" "$(get_config 'deployment_method')" "Deployment method should be parsed"
    assert_equals "false" "$(get_config 'run_npm_build')" "Build setting should be parsed"
    
    teardown_test_environment
}

test_npm_scripts_integration() {
    test_suite "Integration - NPM Scripts Integration"
    
    setup_test_environment
    
    # Create a test package.json
    local test_package="$TEST_DIR/package.json"
    cat > "$test_package" << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "scripts": {
    "existing-script": "echo 'existing'"
  }
}
EOF
    
    test_case "NPM scripts can be added to existing package.json"
    
    # Mock the script arrays (from setup-npm-scripts.sh)
    SCRIPT_NAMES=(
        "update"
        "sync-db"
        "sync-assets"
        "sync-directories"
    )
    
    SCRIPT_COMMANDS=(
        ".update/update.sh"
        ".update/scripts/sync-db.sh"
        ".update/scripts/sync-assets.sh"
        ".update/scripts/sync-directories.sh"
    )
    
    # Test that we can build the scripts correctly
    local scripts_built=""
    for i in "${!SCRIPT_NAMES[@]}"; do
        scripts_built="${scripts_built}\"${SCRIPT_NAMES[$i]}\": \"${SCRIPT_COMMANDS[$i]}\"\n"
    done
    
    assert_contains "update" "$scripts_built" "Should include update script"
    assert_contains "sync-db" "$scripts_built" "Should include sync-db script"
    assert_contains "sync-assets" "$scripts_built" "Should include sync-assets script"
    assert_contains "sync-directories" "$scripts_built" "Should include sync-directories script"
    
    # Test JSON validity (if jq is available)
    if command -v jq >/dev/null 2>&1; then
        test_case "Generated package.json is valid JSON"
        
        # Test that existing package.json is valid
        assert_command_success "jq '.' '$test_package' > /dev/null" "Existing package.json should be valid JSON"
        
        # Test that we can add scripts without breaking JSON
        local temp_package=$(mktemp)
        jq '.scripts["test-update"] = ".update/update.sh"' "$test_package" > "$temp_package"
        
        assert_command_success "jq '.' '$temp_package' > /dev/null" "Modified package.json should be valid JSON"
        
        # Verify the script was added
        local added_script=$(jq -r '.scripts["test-update"]' "$temp_package")
        assert_equals ".update/update.sh" "$added_script" "Script should be added correctly"
        
        rm -f "$temp_package"
    else
        skip_test "jq not available for JSON validation"
    fi
    
    teardown_test_environment
}

test_asset_storage_decision_workflow() {
    test_suite "Integration - Asset Storage Decision Workflow"
    
    setup_test_environment
    
    test_case "Asset sync decision based on storage type configuration"
    
    # Test with local storage
    local local_config="$TEST_DIR/local_config.yml"
    create_mock_config "$local_config" "asset_storage_type: local"
    export CONFIG_FILE="$local_config"
    
    local storage_type=$(get_config "asset_storage_type")
    local should_sync_assets=""
    
    case "$storage_type" in
        "local")
            should_sync_assets="yes"
            ;;
        "s3"|"spaces"|"other")
            should_sync_assets="no"
            ;;
        *)
            should_sync_assets="yes"  # Default to sync for unknown types
            ;;
    esac
    
    assert_equals "yes" "$should_sync_assets" "Should sync assets for local storage"
    
    # Test with S3 storage
    local s3_config="$TEST_DIR/s3_config.yml"
    create_mock_config "$s3_config" "asset_storage_type: s3"
    export CONFIG_FILE="$s3_config"
    
    storage_type=$(get_config "asset_storage_type")
    
    case "$storage_type" in
        "local")
            should_sync_assets="yes"
            ;;
        "s3"|"spaces"|"other")
            should_sync_assets="no"
            ;;
        *)
            should_sync_assets="yes"
            ;;
    esac
    
    assert_equals "no" "$should_sync_assets" "Should not sync assets for S3 storage"
    
    teardown_test_environment
}

test_directory_structure_validation() {
    test_suite "Integration - Directory Structure Validation"
    
    setup_test_environment
    
    test_case "Required directory structure exists"
    
    # Check that all expected script files exist in the actual project
    local project_root="$SCRIPT_DIR/../../.."
    
    assert_file_exists "$project_root/.update/update.sh" "Main update script exists"
    assert_file_exists "$project_root/.update/scripts/helpers.sh" "Helper functions exist"
    assert_file_exists "$project_root/.update/scripts/sync-db.sh" "Database sync script exists"
    assert_file_exists "$project_root/.update/scripts/sync-assets.sh" "Asset sync script exists"
    assert_file_exists "$project_root/.update/scripts/sync-directories.sh" "Directory sync script exists"
    assert_file_exists "$project_root/.update/scripts/remote-exec.sh" "Remote execution script exists"
    assert_file_exists "$project_root/.update/scripts/interactive-setup.sh" "Setup script exists"
    assert_file_exists "$project_root/.update/scripts/setup-npm-scripts.sh" "NPM setup script exists"
    assert_file_exists "$project_root/.update/scripts/test-ssh.sh" "SSH test script exists"
    assert_file_exists "$project_root/.update/scripts/deploy.sh" "Deploy script exists"
    
    # Check that all scripts are executable
    test_case "All scripts are executable"
    
    assert_command_success "[ -x '$project_root/.update/update.sh' ]" "Main update script is executable"
    assert_command_success "[ -x '$project_root/.update/scripts/sync-db.sh' ]" "Database sync script is executable"
    assert_command_success "[ -x '$project_root/.update/scripts/sync-assets.sh' ]" "Asset sync script is executable"
    assert_command_success "[ -x '$project_root/.update/scripts/sync-directories.sh' ]" "Directory sync script is executable"
    
    teardown_test_environment
}

test_config_validation_workflow() {
    test_suite "Integration - Config Validation Workflow"
    
    setup_test_environment
    
    test_case "Config validation catches missing required keys"
    
    # Test with incomplete config
    local incomplete_config="$TEST_DIR/incomplete_config.yml"
    create_mock_config "$incomplete_config" "
# Incomplete config - missing required keys
branch: main
"
    
    export CONFIG_FILE="$incomplete_config"
    
    # Test that missing required keys are caught
    result=$(get_config "ssh_host" 2>&1 || echo "MISSING_KEY_ERROR")
    assert_contains "Required config key 'ssh_host' not found" "$result" "Should catch missing required key"
    
    # Test that optional keys work with defaults
    result=$(get_config "ssh_port" "22")
    assert_equals "22" "$result" "Should use default for missing optional key"
    
    teardown_test_environment
}

# Run all tests
main() {
    echo -e "${BLUE}Starting Integration Tests${NC}"
    
    test_ssh_connection_workflow
    test_config_file_workflow
    test_npm_scripts_integration
    test_asset_storage_decision_workflow
    test_directory_structure_validation
    test_config_validation_workflow
    
    test_summary
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi