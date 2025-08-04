#!/bin/bash

# Helper functions for update scripts

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