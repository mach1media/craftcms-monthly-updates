#!/bin/bash

# Craft CMS Update Scripts Test Runner
# Runs all unit and integration tests for the update script package

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

echo -e "${CYAN}🧪 Craft CMS Update Scripts Test Suite${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# Function to run a test file and capture results
run_test_file() {
    local test_file="$1"
    local test_name="$2"
    
    echo -e "${BLUE}Running $test_name...${NC}"
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    
    if "$test_file"; then
        echo -e "${GREEN}✅ $test_name passed${NC}"
        PASSED_SUITES=$((PASSED_SUITES + 1))
        echo ""
        return 0
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        echo ""
        return 1
    fi
}

# Function to check dependencies
check_dependencies() {
    echo -e "${YELLOW}Checking test dependencies...${NC}"
    
    local missing_deps=()
    
    # Check for required commands
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi
    
    # Optional but recommended
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  jq not found - some JSON validation tests will be skipped${NC}"
    fi
    
    if ! command -v ssh >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  ssh not found - SSH connection tests will be skipped${NC}"
    fi
    
    if ! command -v rsync >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  rsync not found - some sync tests will use fallback methods${NC}"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required dependencies: ${missing_deps[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Dependencies check passed${NC}"
    echo ""
}

# Function to run pre-test setup
setup_test_environment() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    
    # Make sure all test files are executable
    find "$SCRIPT_DIR" -name "*.sh" -exec chmod +x {} \;
    
    # Create temporary test directory if needed
    export TEST_TEMP_DIR="/tmp/craftcms-update-tests-$$"
    mkdir -p "$TEST_TEMP_DIR"
    
    echo -e "${GREEN}✅ Test environment ready${NC}"
    echo ""
}

# Function to cleanup after tests
cleanup_test_environment() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Function to run unit tests
run_unit_tests() {
    echo -e "${CYAN}🔬 Running Unit Tests${NC}"
    echo -e "${CYAN}===================${NC}"
    echo ""
    
    local unit_test_dir="$SCRIPT_DIR/unit"
    local unit_failed=0
    
    if [ -d "$unit_test_dir" ]; then
        for test_file in "$unit_test_dir"/test-*.sh; do
            if [ -f "$test_file" ]; then
                local test_name=$(basename "$test_file" .sh)
                if ! run_test_file "$test_file" "$test_name"; then
                    unit_failed=1
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠️  No unit tests directory found${NC}"
        echo ""
    fi
    
    return $unit_failed
}

# Function to run integration tests
run_integration_tests() {
    echo -e "${CYAN}🔗 Running Integration Tests${NC}"
    echo -e "${CYAN}===========================${NC}"
    echo ""
    
    local integration_test_dir="$SCRIPT_DIR/integration"
    local integration_failed=0
    
    if [ -d "$integration_test_dir" ]; then
        for test_file in "$integration_test_dir"/test-*.sh; do
            if [ -f "$test_file" ]; then
                local test_name=$(basename "$test_file" .sh)
                if ! run_test_file "$test_file" "$test_name"; then
                    integration_failed=1
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠️  No integration tests directory found${NC}"
        echo ""
    fi
    
    return $integration_failed
}

# Function to run connection tests (if config exists)
run_connection_tests() {
    echo -e "${CYAN}🌐 Running Connection Tests${NC}"
    echo -e "${CYAN}==========================${NC}"
    echo ""
    
    local config_file="$SCRIPT_DIR/../config.yml"
    
    if [ -f "$config_file" ]; then
        echo -e "${YELLOW}Config file found - running connection tests...${NC}"
        
        # Test SSH connection if configured
        local ssh_test_script="$SCRIPT_DIR/../scripts/test-ssh.sh"
        if [ -f "$ssh_test_script" ]; then
            echo -e "${BLUE}Testing SSH connection...${NC}"
            if "$ssh_test_script"; then
                echo -e "${GREEN}✅ SSH connection test passed${NC}"
            else
                echo -e "${YELLOW}⚠️  SSH connection test failed (this might be expected)${NC}"
            fi
            echo ""
        fi
        
        # Validate config file structure
        echo -e "${BLUE}Validating config file structure...${NC}"
        
        local required_keys=(
            "branch"
            "production_url"
            "ssh_host"
            "ssh_user"
            "remote_project_dir"
            "backup_dir"
            "uploads_dir"
            "asset_storage_type"
            "additional_sync_dirs"
            "deployment_method"
        )
        
        local config_valid=true
        
        for key in "${required_keys[@]}"; do
            if ! grep -q "^${key}:" "$config_file"; then
                echo -e "${RED}❌ Missing required config key: $key${NC}"
                config_valid=false
            fi
        done
        
        if [ "$config_valid" = true ]; then
            echo -e "${GREEN}✅ Config file structure is valid${NC}"
        else
            echo -e "${RED}❌ Config file structure has issues${NC}"
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠️  No config file found - skipping connection tests${NC}"
        echo -e "    Run '.update/scripts/interactive-setup.sh' to create config file"
        echo ""
    fi
}

# Function to display final summary
show_final_summary() {
    echo -e "${CYAN}📊 Final Test Results${NC}"
    echo -e "${CYAN}===================${NC}"
    echo ""
    echo -e "Total test suites: $TOTAL_SUITES"
    echo -e "${GREEN}Passed: $PASSED_SUITES${NC}"
    echo -e "${RED}Failed: $FAILED_SUITES${NC}"
    echo ""
    
    if [ $FAILED_SUITES -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! Your update scripts are working correctly.${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "1. Run 'npm run update/test-ssh' to test your production connection"
        echo "2. Run 'npm run update' to perform your first monthly update"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
        echo ""
        echo -e "${CYAN}Troubleshooting:${NC}"
        echo "1. Check that all required dependencies are installed"
        echo "2. Verify your config file is properly set up"
        echo "3. Ensure SSH keys and connections are working"
        echo "4. Check file permissions on all scripts"
        echo ""
        return 1
    fi
}

# Main function
main() {
    local run_unit=true
    local run_integration=true
    local run_connections=false
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit-only)
                run_integration=false
                run_connections=false
                shift
                ;;
            --integration-only)
                run_unit=false
                run_connections=false
                shift
                ;;
            --with-connections)
                run_connections=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --unit-only         Run only unit tests"
                echo "  --integration-only  Run only integration tests"
                echo "  --with-connections  Include connection tests (requires config)"
                echo "  --verbose, -v       Verbose output"
                echo "  --help, -h          Show this help message"
                echo ""
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Trap to ensure cleanup happens
    trap cleanup_test_environment EXIT
    
    # Run test phases
    check_dependencies
    setup_test_environment
    
    local overall_failed=0
    
    if [ "$run_unit" = true ]; then
        if ! run_unit_tests; then
            overall_failed=1
        fi
    fi
    
    if [ "$run_integration" = true ]; then
        if ! run_integration_tests; then
            overall_failed=1
        fi
    fi
    
    if [ "$run_connections" = true ]; then
        run_connection_tests
    fi
    
    show_final_summary
    
    exit $overall_failed
}

# Show usage if no arguments and not being sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi