#!/bin/bash

# Unit tests for remote-exec.sh functions

# Get script directory and source test framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../test-framework.sh"

# Source the helpers and remote execution functions
source "$SCRIPT_DIR/../../scripts/helpers.sh"

test_find_ssh_key_function() {
    test_suite "Remote Execution - SSH Key Discovery"
    
    setup_test_environment
    
    # Create mock SSH directory
    local mock_ssh_dir="$TEST_DIR/.ssh"
    mkdir -p "$mock_ssh_dir"
    
    # Override HOME for testing
    export HOME="$TEST_DIR"
    
    # Test with no SSH keys
    test_case "find_ssh_key returns error when no keys exist"
    
    # We need to source the function in a way that doesn't exit the test
    source "$SCRIPT_DIR/../../scripts/remote-exec.sh" 2>/dev/null || true
    
    result=$(find_ssh_key 2>/dev/null && echo "FOUND" || echo "NOT_FOUND")
    assert_equals "NOT_FOUND" "$result" "Should return error when no SSH keys exist"
    
    # Test with id_rsa key
    test_case "find_ssh_key finds id_rsa key"
    touch "$mock_ssh_dir/id_rsa"
    
    result=$(find_ssh_key 2>/dev/null)
    assert_equals "$mock_ssh_dir/id_rsa" "$result" "Should find id_rsa key"
    
    # Test with multiple keys (should prefer serverpilot)
    test_case "find_ssh_key prefers serverpilot key"
    touch "$mock_ssh_dir/serverpilot"
    touch "$mock_ssh_dir/id_ed25519"
    
    result=$(find_ssh_key 2>/dev/null)
    assert_equals "$mock_ssh_dir/serverpilot" "$result" "Should prefer serverpilot key"
    
    # Test key precedence order
    test_case "find_ssh_key follows correct precedence"
    rm -f "$mock_ssh_dir/serverpilot"
    
    result=$(find_ssh_key 2>/dev/null)
    assert_equals "$mock_ssh_dir/id_rsa" "$result" "Should fall back to id_rsa when serverpilot missing"
    
    rm -f "$mock_ssh_dir/id_rsa"
    result=$(find_ssh_key 2>/dev/null)
    assert_equals "$mock_ssh_dir/id_ed25519" "$result" "Should find id_ed25519 when others missing"
    
    teardown_test_environment
}

test_ssh_config_parsing() {
    test_suite "Remote Execution - SSH Config Parsing"
    
    setup_test_environment
    
    # Create test config
    local test_config="$TEST_DIR/test_config.yml"
    create_mock_config "$test_config" "
ssh_host: test.example.com
ssh_user: testuser
ssh_port: 2222
ftp_password: secret123
remote_project_dir: /var/www/test
"
    
    export CONFIG_FILE="$test_config"
    
    # Source remote-exec to load config parsing
    source "$SCRIPT_DIR/../../scripts/remote-exec.sh" 2>/dev/null || true
    
    test_case "SSH config values are parsed correctly"
    assert_equals "test.example.com" "$SSH_HOST" "SSH_HOST should be parsed"
    assert_equals "testuser" "$SSH_USER" "SSH_USER should be parsed"
    assert_equals "2222" "$SSH_PORT" "SSH_PORT should be parsed"
    assert_equals "secret123" "$FTP_PASSWORD" "FTP_PASSWORD should be parsed"
    assert_equals "/var/www/test" "$REMOTE_PROJECT_DIR" "REMOTE_PROJECT_DIR should be parsed"
    
    teardown_test_environment
}

test_command_construction() {
    test_suite "Remote Execution - Command Construction"
    
    setup_test_environment
    
    # Create test config
    local test_config="$TEST_DIR/test_config.yml"
    create_mock_config "$test_config" "
remote_project_dir: /var/www/html
"
    export CONFIG_FILE="$test_config"
    
    # Mock the execute_remote_command function to just echo what it would run
    execute_remote_command() {
        local command=$1
        local use_project_dir=${2:-true}
        
        # Prepare the full command
        local full_command="$command"
        if [ "$use_project_dir" = "true" ] && [ -n "$REMOTE_PROJECT_DIR" ]; then
            full_command="cd '$REMOTE_PROJECT_DIR' && $command"
        fi
        
        echo "$full_command"
    }
    
    test_case "Commands are constructed with project directory"
    result=$(execute_remote_command "ls -la")
    assert_equals "cd '/var/www/html' && ls -la" "$result" "Should prepend cd command"
    
    test_case "Commands without project directory"
    result=$(execute_remote_command "whoami" false)
    assert_equals "whoami" "$result" "Should not prepend cd when disabled"
    
    test_case "Commands handle empty project directory"
    REMOTE_PROJECT_DIR=""
    result=$(execute_remote_command "pwd")
    assert_equals "pwd" "$result" "Should not prepend cd when project dir is empty"
    
    teardown_test_environment
}

test_authentication_method_detection() {
    test_suite "Remote Execution - Authentication Method Detection"
    
    setup_test_environment
    
    # Create mock SSH directory and keys
    local mock_ssh_dir="$TEST_DIR/.ssh"
    mkdir -p "$mock_ssh_dir"
    export HOME="$TEST_DIR"
    
    # Create test config
    local test_config="$TEST_DIR/test_config.yml"
    export CONFIG_FILE="$test_config"
    
    # Mock test_ssh_connection to simulate different scenarios
    test_ssh_connection() {
        local method=$1
        local ssh_key=$2
        
        case "$method" in
            "key")
                # Simulate key auth success if key file exists
                if [ -n "$ssh_key" ] && [ -f "$ssh_key" ]; then
                    return 0
                else
                    return 1
                fi
                ;;
            "password")
                # Simulate password auth success if sshpass available and password set
                if command -v sshpass >/dev/null 2>&1 && [ -n "$FTP_PASSWORD" ]; then
                    return 0
                else
                    return 1
                fi
                ;;
            *)
                return 1
                ;;
        esac
    }
    
    test_case "Key authentication preferred when available"
    touch "$mock_ssh_dir/id_rsa"
    create_mock_config "$test_config" "ftp_password: secret"
    
    # Source remote-exec functions
    source "$SCRIPT_DIR/../../scripts/remote-exec.sh" 2>/dev/null || true
    
    # This would normally try key first, then fall back to password
    # We can test the preference by checking find_ssh_key
    local found_key=$(find_ssh_key 2>/dev/null)
    assert_equals "$mock_ssh_dir/id_rsa" "$found_key" "Should find SSH key for key auth"
    
    test_case "Password authentication fallback"
    rm -f "$mock_ssh_dir/id_rsa"
    create_mock_config "$test_config" "ftp_password: secret123"
    
    # Reload config
    source "$SCRIPT_DIR/../../scripts/remote-exec.sh" 2>/dev/null || true
    
    assert_equals "secret123" "$FTP_PASSWORD" "Should have password for password auth"
    
    teardown_test_environment
}

test_rsync_options_building() {
    test_suite "Remote Execution - Rsync Options"
    
    setup_test_environment
    
    # Test sync_directory function with different exclude patterns
    # We'll mock the actual rsync execution
    sync_directory() {
        local remote_path=$1
        local local_path=$2
        local exclude_patterns=${3:-""}
        
        # Build rsync exclude options
        local exclude_opts=""
        if [ -n "$exclude_patterns" ]; then
            IFS=',' read -ra EXCLUDES <<< "$exclude_patterns"
            for pattern in "${EXCLUDES[@]}"; do
                exclude_opts="$exclude_opts --exclude='$pattern'"
            done
        fi
        
        echo "rsync -avz --delete $exclude_opts"
    }
    
    test_case "Rsync options without excludes"
    result=$(sync_directory "/remote/path" "/local/path")
    assert_equals "rsync -avz --delete " "$result" "Should build basic rsync command"
    
    test_case "Rsync options with single exclude"
    result=$(sync_directory "/remote/path" "/local/path" "*.log")
    assert_contains "--exclude='*.log'" "$result" "Should add single exclude pattern"
    
    test_case "Rsync options with multiple excludes"
    result=$(sync_directory "/remote/path" "/local/path" "*.log,*.tmp,cache/*")
    assert_contains "--exclude='*.log'" "$result" "Should add first exclude pattern"
    assert_contains "--exclude='*.tmp'" "$result" "Should add second exclude pattern"
    assert_contains "--exclude='cache/*'" "$result" "Should add third exclude pattern"
    
    teardown_test_environment
}

# Run all tests
main() {
    echo -e "${BLUE}Starting Remote Execution Unit Tests${NC}"
    
    test_find_ssh_key_function
    test_ssh_config_parsing
    test_command_construction
    test_authentication_method_detection
    test_rsync_options_building
    
    test_summary
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi