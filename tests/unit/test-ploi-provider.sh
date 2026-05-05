#!/bin/bash

# Unit tests for Ploi provider functions

# Get script directory and source test framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../test-framework.sh"

# Source the helper functions first (required by provider scripts)
source "$SCRIPT_DIR/../../scripts/helpers.sh"

# Source the provider detection script
source "$SCRIPT_DIR/../../scripts/provider-detect.sh"

test_provider_detection() {
    test_suite "Provider Detection Functions"

    setup_test_environment

    # Test detecting Ploi from hosting_provider config
    test_case "detect_provider reads explicit hosting_provider"
    local test_config="$TEST_DIR/test_config.yml"
    create_mock_config "$test_config" "
hosting_provider: ploi
production_url: https://example.com
"
    export CONFIG_FILE="$test_config"

    local result=$(detect_provider)
    assert_equals "ploi" "$result" "Should detect Ploi from hosting_provider"

    # Test detecting Ploi from deployment_method
    test_case "detect_provider infers Ploi from deployment_method"
    create_mock_config "$test_config" "
production_url: https://example.com
deployment_method: ploi
"
    export CONFIG_FILE="$test_config"

    result=$(detect_provider)
    assert_equals "ploi" "$result" "Should infer Ploi from deployment_method"

    # Test detecting Ploi from SSH user
    test_case "detect_provider infers Ploi from ssh_user"
    create_mock_config "$test_config" "
production_url: https://example.com
ssh_user: ploi
deployment_method: manual
"
    export CONFIG_FILE="$test_config"

    result=$(detect_provider)
    assert_equals "ploi" "$result" "Should infer Ploi from ssh_user=ploi"

    # Test detecting Ploi from remote_project_dir path
    test_case "detect_provider infers Ploi from remote_project_dir path"
    create_mock_config "$test_config" "
production_url: https://example.com
remote_project_dir: /home/ploi/example.com
deployment_method: manual
"
    export CONFIG_FILE="$test_config"

    result=$(detect_provider)
    assert_equals "ploi" "$result" "Should infer Ploi from /home/ploi/ path"

    # Test detecting Forge from ssh_user
    test_case "detect_provider infers Forge from ssh_user"
    create_mock_config "$test_config" "
production_url: https://example.com
ssh_user: forge
deployment_method: manual
"
    export CONFIG_FILE="$test_config"

    result=$(detect_provider)
    assert_equals "forge" "$result" "Should infer Forge from ssh_user=forge"

    # Test detecting ServerPilot from path
    test_case "detect_provider infers ServerPilot from path"
    create_mock_config "$test_config" "
production_url: https://example.com
remote_project_dir: /srv/users/serverpilot/apps/myapp
deployment_method: manual
"
    export CONFIG_FILE="$test_config"

    result=$(detect_provider)
    assert_equals "serverpilot" "$result" "Should infer ServerPilot from path"

    # Test fallback to generic
    test_case "detect_provider falls back to generic"
    create_mock_config "$test_config" "
production_url: https://example.com
ssh_user: custom_user
remote_project_dir: /var/www/html
deployment_method: manual
"
    export CONFIG_FILE="$test_config"

    result=$(detect_provider)
    assert_equals "generic" "$result" "Should fall back to generic"

    teardown_test_environment
}

test_provider_ssh_user() {
    test_suite "Provider SSH User Functions"

    setup_test_environment

    # Test Ploi SSH user
    test_case "get_provider_ssh_user returns ploi for Ploi"
    local result=$(get_provider_ssh_user "ploi")
    assert_equals "ploi" "$result" "Should return 'ploi' for Ploi provider"

    # Test Forge SSH user
    test_case "get_provider_ssh_user returns forge for Forge"
    result=$(get_provider_ssh_user "forge")
    assert_equals "forge" "$result" "Should return 'forge' for Forge provider"

    # Test ServerPilot SSH user
    test_case "get_provider_ssh_user returns serverpilot for ServerPilot"
    result=$(get_provider_ssh_user "serverpilot")
    assert_equals "serverpilot" "$result" "Should return 'serverpilot' for ServerPilot provider"

    teardown_test_environment
}

test_provider_project_dir() {
    test_suite "Provider Project Directory Functions"

    setup_test_environment

    # Test Ploi project dir
    test_case "get_provider_project_dir returns correct Ploi path"
    local result=$(get_provider_project_dir "ploi" "example.com")
    assert_equals "/home/ploi/example.com" "$result" "Should return /home/ploi/domain"

    # Test Forge project dir
    test_case "get_provider_project_dir returns correct Forge path"
    result=$(get_provider_project_dir "forge" "example.com")
    assert_equals "/home/forge/example.com" "$result" "Should return /home/forge/domain"

    # Test ServerPilot project dir
    test_case "get_provider_project_dir returns correct ServerPilot path"
    result=$(get_provider_project_dir "serverpilot" "myapp")
    assert_equals "/srv/users/serverpilot/apps/myapp" "$result" "Should return ServerPilot app path"

    # Test fortrabbit project dir
    test_case "get_provider_project_dir returns correct fortrabbit path"
    result=$(get_provider_project_dir "fortrabbit" "myapp")
    assert_equals "/srv/app/myapp" "$result" "Should return fortrabbit app path"

    teardown_test_environment
}

test_nested_config_parsing() {
    test_suite "Nested Config Parsing for Ploi"

    setup_test_environment

    local test_config="$TEST_DIR/test_config.yml"
    export CONFIG_FILE="$test_config"

    # Test flat format (ploi_server_id)
    test_case "get_nested_config reads flat format"
    create_mock_config "$test_config" "
production_url: https://example.com
ploi_server_id: 12345
ploi_site_id: 67890
"

    local result=$(get_nested_config "ploi.server_id" "")
    assert_equals "12345" "$result" "Should read ploi_server_id as ploi.server_id"

    result=$(get_nested_config "ploi.site_id" "")
    assert_equals "67890" "$result" "Should read ploi_site_id as ploi.site_id"

    # Test default values
    test_case "get_nested_config returns default for missing key"
    result=$(get_nested_config "ploi.missing_key" "default_value")
    assert_equals "default_value" "$result" "Should return default for missing nested key"

    # Test non-nested key
    test_case "get_nested_config handles non-nested keys"
    result=$(get_nested_config "production_url" "")
    assert_equals "https://example.com" "$result" "Should handle non-nested keys"

    teardown_test_environment
}

test_provider_supports() {
    test_suite "Provider Feature Support"

    setup_test_environment

    # Test Ploi CLI deploy support
    test_case "provider_supports returns true for Ploi CLI deploy"
    if provider_supports "ploi" "cli-deploy"; then
        echo -e "${GREEN}✓ PASS${NC}: Ploi supports cli-deploy"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Ploi should support cli-deploy"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test Ploi API deploy support
    test_case "provider_supports returns true for Ploi API deploy"
    if provider_supports "ploi" "api-deploy"; then
        echo -e "${GREEN}✓ PASS${NC}: Ploi supports api-deploy"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Ploi should support api-deploy"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test that generic doesn't support CLI deploy
    test_case "provider_supports returns false for generic CLI deploy"
    if ! provider_supports "generic" "cli-deploy"; then
        echo -e "${GREEN}✓ PASS${NC}: generic does not support cli-deploy"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: generic should not support cli-deploy"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test that all providers support SSH deploy
    test_case "provider_supports returns true for SSH deploy"
    if provider_supports "ploi" "ssh-deploy" && \
       provider_supports "forge" "ssh-deploy" && \
       provider_supports "generic" "ssh-deploy"; then
        echo -e "${GREEN}✓ PASS${NC}: All providers support ssh-deploy"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: All providers should support ssh-deploy"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    teardown_test_environment
}

test_config_key_exists() {
    test_suite "Config Key Exists Function"

    setup_test_environment

    local test_config="$TEST_DIR/test_config.yml"
    export CONFIG_FILE="$test_config"

    create_mock_config "$test_config" "
production_url: https://example.com
ploi_server_id: 12345
empty_value:
"

    # Test existing key
    test_case "config_key_exists returns true for existing key"
    if config_key_exists "production_url"; then
        echo -e "${GREEN}✓ PASS${NC}: production_url exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: production_url should exist"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test nested key via flat format
    test_case "config_key_exists finds nested key in flat format"
    if config_key_exists "ploi.server_id"; then
        echo -e "${GREEN}✓ PASS${NC}: ploi.server_id exists (via flat format)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: ploi.server_id should exist"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test missing key
    test_case "config_key_exists returns false for missing key"
    if ! config_key_exists "nonexistent_key"; then
        echo -e "${GREEN}✓ PASS${NC}: nonexistent_key does not exist"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: nonexistent_key should not exist"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    teardown_test_environment
}

# Run all tests
main() {
    echo -e "${BLUE}Starting Ploi Provider Unit Tests${NC}"

    test_provider_detection
    test_provider_ssh_user
    test_provider_project_dir
    test_nested_config_parsing
    test_provider_supports
    test_config_key_exists

    test_summary
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
