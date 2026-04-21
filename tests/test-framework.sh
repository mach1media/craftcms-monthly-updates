#!/bin/bash

# Simple Bash Test Framework
# Provides utilities for unit and integration testing

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST_SUITE=""

# Test framework functions
test_suite() {
    CURRENT_TEST_SUITE="$1"
    echo -e "\n${BLUE}=== Test Suite: $1 ===${NC}"
}

test_case() {
    local test_name="$1"
    echo -e "\n${YELLOW}Running: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$not_expected" != "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  Should not equal: '$not_expected'"
        echo -e "  Actual:          '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_contains() {
    local not_expected_substring="$1"
    local actual_string="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$actual_string" != *"$not_expected_substring"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  Should not contain: '$not_expected_substring'"
        echo -e "  Actual string:      '$actual_string'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local expected_substring="$1"
    local actual_string="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$actual_string" == *"$expected_substring"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  Expected to contain: '$expected_substring'"
        echo -e "  Actual string:       '$actual_string'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist}"
    
    if [ -f "$file_path" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message ($file_path)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  File not found: '$file_path'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_not_exists() {
    local file_path="$1"
    local message="${2:-File should not exist}"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  File should not exist: '$file_path'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  Command failed: '$command'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-Command should fail}"
    
    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo -e "  Command should have failed: '$command'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Mock utilities for testing
create_mock_config() {
    local config_file="$1"
    local content="$2"
    
    cat > "$config_file" << EOF
$content
EOF
}

cleanup_mock_files() {
    local test_dir="$1"
    if [ -d "$test_dir" ]; then
        rm -rf "$test_dir"
    fi
}

# Test results summary
test_summary() {
    echo -e "\n${BLUE}=== Test Results Summary ===${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed.${NC}"
        return 1
    fi
}

# Skip test utility
skip_test() {
    local reason="$1"
    echo -e "${YELLOW}⚠ SKIP${NC}: $reason"
}

# Setup and teardown utilities
setup_test_environment() {
    export TEST_MODE=true
    export TEST_DIR="/tmp/craftcms-update-tests-$$"
    mkdir -p "$TEST_DIR"
    
    # Override color variables to prevent conflicts
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export BLUE='\033[0;34m'
    export NC='\033[0m'
}

teardown_test_environment() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    unset TEST_MODE
    unset TEST_DIR
}