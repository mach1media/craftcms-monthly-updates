#!/bin/bash

# Unit tests for helpers.sh functions

# Get script directory and source test framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../test-framework.sh"

# Source the helpers functions
source "$SCRIPT_DIR/../../scripts/helpers.sh"

test_get_config_functions() {
    test_suite "Helper Functions - Config Parsing"
    
    setup_test_environment
    
    # Test get_config with valid config
    test_case "get_config reads valid config values"
    local test_config="$TEST_DIR/test_config.yml"
    create_mock_config "$test_config" "
# Test config
branch: main
ssh_host: example.com
ssh_port: 22
empty_value:
"
    
    export CONFIG_FILE="$test_config"
    
    local result=$(get_config "branch")
    assert_equals "main" "$result" "Should read branch value"
    
    result=$(get_config "ssh_host")
    assert_equals "example.com" "$result" "Should read ssh_host value"
    
    result=$(get_config "ssh_port")
    assert_equals "22" "$result" "Should read ssh_port value"
    
    # Test get_config with default value
    test_case "get_config returns default when key missing"
    result=$(get_config "missing_key" "default_value")
    assert_equals "default_value" "$result" "Should return default value for missing key"
    
    # Test get_config with empty value
    test_case "get_config handles empty values"
    result=$(get_config "empty_value" "fallback")
    assert_equals "fallback" "$result" "Should use default for empty value"
    
    # Test get_config with quotes
    test_case "get_config handles quoted values"
    create_mock_config "$test_config" "
quoted_single: 'single quoted'
quoted_double: \"double quoted\"
"
    result=$(get_config "quoted_single")
    assert_equals "single quoted" "$result" "Should strip single quotes"
    
    result=$(get_config "quoted_double")
    assert_equals "double quoted" "$result" "Should strip double quotes"
    
    # Test get_config with spaces
    test_case "get_config trims whitespace"
    create_mock_config "$test_config" "
spaced_value:   trimmed value   
"
    result=$(get_config "spaced_value")
    assert_equals "trimmed value" "$result" "Should trim whitespace"
    
    teardown_test_environment
}

test_get_config_error_handling() {
    test_suite "Helper Functions - Config Error Handling"
    
    setup_test_environment
    
    # Test missing config file
    test_case "get_config fails with missing config file"
    export CONFIG_FILE="/nonexistent/config.yml"
    
    # Capture the function in a subshell to prevent exit from killing the test
    result=$(get_config "test_key" 2>&1 || echo "EXIT_CODE:$?")
    assert_contains "Config file not found" "$result" "Should error on missing config file"
    assert_contains "EXIT_CODE:1" "$result" "Should exit with code 1"
    
    # Test missing required key
    test_case "get_config fails with missing required key"
    local test_config="$TEST_DIR/test_config.yml"
    create_mock_config "$test_config" "existing_key: value"
    export CONFIG_FILE="$test_config"
    
    result=$(get_config "missing_required_key" 2>&1 || echo "EXIT_CODE:$?")
    assert_contains "Required config key 'missing_required_key' not found" "$result" "Should error on missing required key"
    assert_contains "EXIT_CODE:1" "$result" "Should exit with code 1"
    
    teardown_test_environment
}

test_helper_output_functions() {
    test_suite "Helper Functions - Output Functions"
    
    setup_test_environment
    
    # Set color variables to test output
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export NC='\033[0m'
    
    # Test info function
    test_case "info function formats message correctly"
    result=$(info "test message" 2>&1)
    assert_contains "[INFO]" "$result" "Should contain INFO tag"
    assert_contains "test message" "$result" "Should contain the message"
    
    # Test success function
    test_case "success function formats message correctly"
    result=$(success "success message" 2>&1)
    assert_contains "[SUCCESS]" "$result" "Should contain SUCCESS tag"
    assert_contains "success message" "$result" "Should contain the message"
    
    # Test error function (in subshell to prevent exit)
    test_case "error function formats message and exits"
    result=$(error "error message" 2>&1 || echo "EXIT_CODE:$?")
    assert_contains "[ERROR]" "$result" "Should contain ERROR tag"
    assert_contains "error message" "$result" "Should contain the message"
    assert_contains "EXIT_CODE:1" "$result" "Should exit with code 1"
    
    teardown_test_environment
}

test_yaml_parsing_edge_cases() {
    test_suite "Helper Functions - YAML Parsing Edge Cases"
    
    setup_test_environment
    
    local test_config="$TEST_DIR/test_config.yml"
    export CONFIG_FILE="$test_config"
    
    # Test YAML with comments
    test_case "get_config ignores comments"
    create_mock_config "$test_config" "
# This is a comment
key_after_comment: value1
# Another comment
key_with_comment: value2  # inline comment
"
    
    result=$(get_config "key_after_comment")
    assert_equals "value1" "$result" "Should read value after comment"
    
    result=$(get_config "key_with_comment")
    assert_equals "value2" "$result" "Should ignore inline comment"
    
    # Test YAML with colons in values
    test_case "get_config handles colons in values"
    create_mock_config "$test_config" "
url: https://example.com:8080
time: 12:30:45
"
    
    result=$(get_config "url")
    assert_equals "https://example.com:8080" "$result" "Should handle URL with port"
    
    result=$(get_config "time")
    assert_equals "12:30:45" "$result" "Should handle time format"
    
    # Test YAML with special characters
    test_case "get_config handles special characters"
    create_mock_config "$test_config" "
password: \"p@ssw0rd!#$\"
path: \"/var/www/html\"
"
    
    result=$(get_config "password")
    assert_equals "p@ssw0rd!#$" "$result" "Should handle special characters in password"
    
    result=$(get_config "path")
    assert_equals "/var/www/html" "$result" "Should handle quoted paths"
    
    teardown_test_environment
}

# Run all tests
main() {
    echo -e "${BLUE}Starting Helper Functions Unit Tests${NC}"
    
    test_get_config_functions
    test_get_config_error_handling
    test_helper_output_functions
    test_yaml_parsing_edge_cases
    
    test_summary
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi