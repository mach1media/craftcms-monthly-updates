#!/bin/bash

# Helper functions for update scripts

# Ensure colors are defined
RED=${RED:-'\033[0;31m'}
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[1;33m'}
BLUE=${BLUE:-'\033[0;34m'}
NC=${NC:-'\033[0m'} # No Color

info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

pause_on_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo -e "${YELLOW}Press Enter to continue after resolving the issue, or Ctrl+C to abort${NC}"
    read -r
}

# Function to parse YAML config file (flat keys only)
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

# Function to parse nested YAML config (e.g., ploi.server_id)
# Supports both flat format (ploi_server_id) and nested format (ploi:\n  server_id:)
get_nested_config() {
    local key="$1"
    local default_value="$2"
    local config_file="${CONFIG_FILE:-config.yml}"

    if [ ! -f "$config_file" ]; then
        if [ -n "$default_value" ]; then
            echo "$default_value"
            return 0
        fi
        echo -e "${RED}[ERROR]${NC} Config file not found: $config_file" >&2
        return 1
    fi

    # Check if key contains a dot (nested format)
    if [[ "$key" == *.* ]]; then
        local parent="${key%%.*}"
        local child="${key#*.}"

        # First try flat format: parent_child (e.g., ploi_server_id)
        local flat_key="${parent}_${child}"
        if grep -q "^${flat_key}:" "$config_file" 2>/dev/null; then
            get_config "$flat_key" "$default_value"
            return $?
        fi

        # Try nested YAML format
        # This is a simplified parser - finds parent: block and extracts child value
        local in_block=false
        local value=""

        while IFS= read -r line || [ -n "$line" ]; do
            # Check for parent block start
            if [[ "$line" =~ ^${parent}:[[:space:]]*$ ]]; then
                in_block=true
                continue
            fi

            # If in block, look for indented child key
            if [ "$in_block" = true ]; then
                # Check if this line is still indented (part of the block)
                if [[ "$line" =~ ^[[:space:]]+ ]]; then
                    # Check for our child key
                    if [[ "$line" =~ ^[[:space:]]+${child}:[[:space:]]*(.*) ]]; then
                        value="${BASH_REMATCH[1]}"
                        # Remove quotes if present
                        value="${value#\"}"
                        value="${value%\"}"
                        value="${value#\'}"
                        value="${value%\'}"
                        # Trim whitespace
                        value="${value#"${value%%[![:space:]]*}"}"
                        value="${value%"${value##*[![:space:]]}"}"
                        echo "$value"
                        return 0
                    fi
                else
                    # Non-indented line means we've left the block
                    in_block=false
                fi
            fi
        done < "$config_file"

        # Key not found, return default
        if [ -n "$default_value" ]; then
            echo "$default_value"
            return 0
        fi
        return 1
    else
        # No dot in key, use standard get_config
        get_config "$key" "$default_value"
    fi
}

# Function to check if a config key exists
config_key_exists() {
    local key="$1"
    local config_file="${CONFIG_FILE:-config.yml}"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Check for flat key
    if grep -q "^${key}:" "$config_file" 2>/dev/null; then
        return 0
    fi

    # Check for nested key
    if [[ "$key" == *.* ]]; then
        local parent="${key%%.*}"
        local child="${key#*.}"
        local flat_key="${parent}_${child}"

        if grep -q "^${flat_key}:" "$config_file" 2>/dev/null; then
            return 0
        fi

        # Check nested format
        local in_block=false
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ ^${parent}:[[:space:]]*$ ]]; then
                in_block=true
                continue
            fi
            if [ "$in_block" = true ]; then
                if [[ "$line" =~ ^[[:space:]]+ ]]; then
                    if [[ "$line" =~ ^[[:space:]]+${child}: ]]; then
                        return 0
                    fi
                else
                    in_block=false
                fi
            fi
        done < "$config_file"
    fi

    return 1
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