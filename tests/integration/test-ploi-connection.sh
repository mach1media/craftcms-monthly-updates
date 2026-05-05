#!/bin/bash

# Integration tests for Ploi connection and deployment
# These tests require actual Ploi configuration and connectivity

# Get script directory and source test framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../test-framework.sh"

# Source the helper functions
source "$SCRIPT_DIR/../../scripts/helpers.sh"
source "$SCRIPT_DIR/../../scripts/provider-detect.sh"

# Check if we should run connection tests
check_ploi_prerequisites() {
    # Check if config file exists
    local config_file="$SCRIPT_DIR/../../config.yml"
    if [ ! -f "$config_file" ]; then
        skip_test "No config.yml found - skipping connection tests"
        return 1
    fi

    export CONFIG_FILE="$config_file"

    # Check if Ploi is configured
    local provider=$(detect_provider)
    if [ "$provider" != "ploi" ]; then
        skip_test "Provider is not Ploi ($provider) - skipping Ploi-specific tests"
        return 1
    fi

    return 0
}

test_ploi_cli_detection() {
    test_suite "Ploi CLI Detection"

    # Source Ploi provider functions
    source "$SCRIPT_DIR/../../scripts/providers/ploi.sh"

    test_case "ploi_cli_available checks for CLI installation"
    if ploi_cli_available; then
        echo -e "${GREEN}✓ PASS${NC}: Ploi CLI is installed"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # Additional tests only if CLI is available
        test_case "ploi_cli_configured checks for token"
        if ploi_cli_configured; then
            echo -e "${GREEN}✓ PASS${NC}: Ploi CLI is configured with token"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${YELLOW}⚠ INFO${NC}: Ploi CLI not configured (run 'ploi token')"
            TESTS_PASSED=$((TESTS_PASSED + 1))  # Not a failure, just informational
        fi

        test_case "ploi_cli_initialized checks for .ploi file"
        if ploi_cli_initialized; then
            echo -e "${GREEN}✓ PASS${NC}: Project is linked to Ploi (found .ploi file)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${YELLOW}⚠ INFO${NC}: Project not linked to Ploi (run 'ploi init')"
            TESTS_PASSED=$((TESTS_PASSED + 1))  # Not a failure, just informational
        fi
    else
        echo -e "${YELLOW}⚠ INFO${NC}: Ploi CLI is not installed"
        echo -e "  Install with: brew tap ploi/ploi && brew install ploi"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Not a failure, CLI is optional
    fi
}

test_ploi_api_connectivity() {
    test_suite "Ploi API Connectivity"

    if ! check_ploi_prerequisites; then
        return
    fi

    # Source Ploi provider functions
    source "$SCRIPT_DIR/../../scripts/providers/ploi.sh"

    # Get server and site IDs
    local server_id=$(get_nested_config "ploi.server_id" "" 2>/dev/null) || true
    local site_id=$(get_nested_config "ploi.site_id" "" 2>/dev/null) || true

    if [ -z "$server_id" ]; then
        server_id=$(get_config "ploi_server_id" "" 2>/dev/null) || true
    fi
    if [ -z "$site_id" ]; then
        site_id=$(get_config "ploi_site_id" "" 2>/dev/null) || true
    fi

    if [ -z "$server_id" ] || [ -z "$site_id" ]; then
        skip_test "Server ID or Site ID not configured - skipping API tests"
        return
    fi

    test_case "Ploi API can validate site"
    if ploi_validate_site "$server_id" "$site_id" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: Successfully validated Ploi site"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Could not validate Ploi site"
        echo -e "  Server ID: $server_id"
        echo -e "  Site ID: $site_id"
        echo -e "  Check your API token and IDs"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_ploi_ssh_connectivity() {
    test_suite "Ploi SSH Connectivity"

    if ! check_ploi_prerequisites; then
        return
    fi

    local ssh_host=$(get_config "ssh_host")
    local ssh_user=$(get_config "ssh_user" "ploi")
    local ssh_port=$(get_config "ssh_port" "22")
    local remote_dir=$(get_config "remote_project_dir")

    test_case "SSH connection to Ploi server"

    # Find SSH key
    local ssh_key=""
    for key in "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/ploi"; do
        if [ -f "$key" ]; then
            ssh_key="$key"
            break
        fi
    done

    if [ -z "$ssh_key" ]; then
        echo -e "${RED}✗ FAIL${NC}: No SSH key found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return
    fi

    # Test SSH connection
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no \
        -i "$ssh_key" -p "$ssh_port" \
        "$ssh_user@$ssh_host" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: SSH connection to $ssh_user@$ssh_host successful"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # Test project directory access
        test_case "Remote project directory exists"
        if ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
            -i "$ssh_key" -p "$ssh_port" \
            "$ssh_user@$ssh_host" "test -d '$remote_dir'" 2>/dev/null; then
            echo -e "${GREEN}✓ PASS${NC}: Remote project directory exists ($remote_dir)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC}: Remote project directory not found"
            echo -e "  Expected: $remote_dir"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi

        # Test Craft CMS installation
        test_case "Craft CMS installation detected"
        if ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
            -i "$ssh_key" -p "$ssh_port" \
            "$ssh_user@$ssh_host" "test -f '$remote_dir/craft'" 2>/dev/null; then
            echo -e "${GREEN}✓ PASS${NC}: Craft CMS executable found"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC}: Craft CMS executable not found at $remote_dir/craft"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗ FAIL${NC}: SSH connection failed"
        echo -e "  Host: $ssh_user@$ssh_host:$ssh_port"
        echo -e "  Key: $ssh_key"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_ploi_path_structure() {
    test_suite "Ploi Path Structure"

    if ! check_ploi_prerequisites; then
        return
    fi

    local remote_dir=$(get_config "remote_project_dir")

    test_case "Remote path follows Ploi convention"
    if [[ "$remote_dir" == /home/ploi/* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Path follows Ploi convention (/home/ploi/...)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ WARN${NC}: Path does not follow Ploi convention"
        echo -e "  Current: $remote_dir"
        echo -e "  Expected: /home/ploi/{domain}"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Not a failure, just a warning
    fi

    test_case "SSH user is 'ploi'"
    local ssh_user=$(get_config "ssh_user")
    if [ "$ssh_user" = "ploi" ]; then
        echo -e "${GREEN}✓ PASS${NC}: SSH user is 'ploi'"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ WARN${NC}: SSH user is '$ssh_user' (expected 'ploi')"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Not a failure, could be intentional
    fi
}

# Run all tests
main() {
    echo -e "${BLUE}Starting Ploi Integration Tests${NC}"
    echo -e "${YELLOW}Note: These tests require actual Ploi configuration${NC}"
    echo ""

    test_ploi_cli_detection
    test_ploi_api_connectivity
    test_ploi_ssh_connectivity
    test_ploi_path_structure

    test_summary
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
