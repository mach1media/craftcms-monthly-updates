#!/bin/bash

# Helper functions for update scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory for sourcing other scripts
HELPERS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source environment detection (if not already sourced)
if [ -z "${ENV_DETECT_LOADED:-}" ]; then
    source "$HELPERS_SCRIPT_DIR/env-detect.sh"
    ENV_DETECT_LOADED=1
fi

info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

pause_on_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo -e "${YELLOW}Press Enter to continue after resolving the issue, or Ctrl+C to abort${NC}"
    read -r
}

# Function to parse YAML config file
get_config() {
    local key="$1"
    local default_value="$2"
    local config_file="${CONFIG_FILE:-config.yml}"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}[ERROR]${NC} Config file not found: $config_file" >&2
        exit 1
    fi
    
    # Check if key exists in config file first
    if ! grep -q "^${key}:" "$config_file"; then
        if [ -n "$default_value" ]; then
            echo "$default_value"
        else
            echo -e "${RED}[ERROR]${NC} Required config key '$key' not found in $config_file" >&2
            exit 1
        fi
        return
    fi
    
    # Simple YAML parser for key: value pairs
    local value=$(grep "^${key}:" "$config_file" | sed "s/^${key}:\s*//" | sed 's/^["'\'']//' | sed 's/["'\'']$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Return the value (even if empty) since the key exists
    echo "$value"
}

# Function to get password/token from config or prompt user
get_password() {
    local key="$1"
    local prompt="$2"
    local config_file="${CONFIG_FILE:-config.yml}"

    # Try to get from config first
    local value=$(get_config "$key" "")

    if [ -z "$value" ]; then
        echo -e "${YELLOW}$prompt${NC}" >&2
        read -rs value
        echo >&2  # Add newline after password input
    fi

    echo "$value"
}

# Initialize environment and set CONFIG_FILE
# Usage: init_environment "database sync" "$@"
# This should be called at the start of scripts that need environment awareness
init_environment() {
    local action="${1:-operation}"
    shift  # Remove action from args

    # Parse --env flag from remaining arguments
    parse_env_flag "$@"

    # Get environment (will prompt if needed)
    CURRENT_ENV=$(get_environment "$action")

    if [ -z "$CURRENT_ENV" ]; then
        error "Could not determine environment"
    fi

    # Validate environment and config
    if ! validate_environment "$CURRENT_ENV"; then
        exit 1
    fi

    # Set CONFIG_FILE to environment-specific config
    export CONFIG_FILE=$(get_config_file_for_env "$CURRENT_ENV")
    export CURRENT_ENV

    # Show environment info
    echo ""
    show_environment_info "$CURRENT_ENV"
    echo ""
}

# Check if legacy single config.yml exists (for backwards compatibility)
has_legacy_config() {
    local script_dir="${HELPERS_SCRIPT_DIR}"
    local update_dir="$(dirname "$script_dir")"
    [ -f "$update_dir/config.yml" ]
}

# Migrate legacy config to environment-specific config
# Usage: migrate_legacy_config "production"
migrate_legacy_config() {
    local target_env="$1"
    local script_dir="${HELPERS_SCRIPT_DIR}"
    local update_dir="$(dirname "$script_dir")"
    local legacy_config="$update_dir/config.yml"
    local new_config="$update_dir/config.$target_env.yml"

    if [ -f "$legacy_config" ] && [ ! -f "$new_config" ]; then
        info "Migrating config.yml to config.$target_env.yml"
        cp "$legacy_config" "$new_config"
        success "Created $new_config"
        echo ""
        echo -e "${YELLOW}Note: You may want to create config files for other environments.${NC}"
        echo -e "${YELLOW}Run 'npm run update/setup' to configure additional environments.${NC}"
    fi
}

# Safety check - prevent upstream database operations
# This function should be called before any database push operation
prevent_upstream_db_push() {
    error "Database push operations are not allowed. Database sync is downstream only (remote → local)."
}

# Get list of configured environments
get_configured_environments() {
    local script_dir="${HELPERS_SCRIPT_DIR}"
    local update_dir="$(dirname "$script_dir")"
    local envs=()

    for env in "${VALID_ENVIRONMENTS[@]}"; do
        if [ -f "$update_dir/config.$env.yml" ]; then
            envs+=("$env")
        fi
    done

    echo "${envs[*]}"
}

# Check if running in interactive mode
is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}