#!/bin/bash

# Provider Detection and Path Routing
# Automatically detects hosting provider from configuration
# and provides provider-specific defaults

set -e

# Get script directory
PROVIDER_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helpers if not already sourced
if ! declare -f info &>/dev/null; then
    source "$PROVIDER_SCRIPT_DIR/helpers.sh"
fi

# ============================================================================
# Provider Detection
# ============================================================================

# Known hosting providers and their characteristics
declare -A PROVIDER_SSH_USERS=(
    ["ploi"]="ploi"
    ["forge"]="forge"
    ["serverpilot"]="serverpilot"
    ["fortrabbit"]=""  # Uses app name as user
    ["generic"]=""
)

declare -A PROVIDER_PATH_PATTERNS=(
    ["ploi"]="/home/ploi/{domain}"
    ["forge"]="/home/forge/{domain}"
    ["serverpilot"]="/srv/users/serverpilot/apps/{app}"
    ["fortrabbit"]="/srv/app/{app}"
    ["generic"]=""
)

# Detect provider from configuration
# Arguments: none (uses CONFIG_FILE)
# Returns: provider name string
detect_provider() {
    local config_file="${CONFIG_FILE:-$PROVIDER_SCRIPT_DIR/../config.yml}"

    if [ ! -f "$config_file" ]; then
        echo "generic"
        return 0
    fi

    # Check for explicit hosting_provider setting
    local explicit_provider
    explicit_provider=$(get_config "hosting_provider" "" 2>/dev/null) || true
    if [ -n "$explicit_provider" ]; then
        echo "$explicit_provider"
        return 0
    fi

    # Infer from deployment_method
    local deployment_method
    deployment_method=$(get_config "deployment_method" "" 2>/dev/null) || true
    case "$deployment_method" in
        "ploi"|"ploi-cli"|"ploi-api")
            echo "ploi"
            return 0
            ;;
        "forge")
            echo "forge"
            return 0
            ;;
        "envoyer")
            # Envoyer is commonly used with Forge
            echo "forge"
            return 0
            ;;
    esac

    # Infer from SSH user
    local ssh_user
    ssh_user=$(get_config "ssh_user" "" 2>/dev/null) || true
    case "$ssh_user" in
        "ploi")
            echo "ploi"
            return 0
            ;;
        "forge")
            echo "forge"
            return 0
            ;;
        "serverpilot")
            echo "serverpilot"
            return 0
            ;;
    esac

    # Infer from remote project directory
    local remote_dir
    remote_dir=$(get_config "remote_project_dir" "" 2>/dev/null) || true
    case "$remote_dir" in
        /home/ploi/*)
            echo "ploi"
            return 0
            ;;
        /home/forge/*)
            echo "forge"
            return 0
            ;;
        /srv/users/serverpilot/*)
            echo "serverpilot"
            return 0
            ;;
        /srv/app/*)
            echo "fortrabbit"
            return 0
            ;;
    esac

    # Default to generic
    echo "generic"
}

# Get provider-specific SSH user
# Arguments: provider_name
# Returns: SSH username for provider
get_provider_ssh_user() {
    local provider="${1:-$(detect_provider)}"

    case "$provider" in
        "ploi")
            echo "ploi"
            ;;
        "forge")
            echo "forge"
            ;;
        "serverpilot")
            echo "serverpilot"
            ;;
        *)
            # Return from config or empty
            get_config "ssh_user" "" 2>/dev/null || echo ""
            ;;
    esac
}

# Get provider-specific project directory
# Arguments: provider_name, domain_or_app
# Returns: full project path
get_provider_project_dir() {
    local provider="${1:-$(detect_provider)}"
    local domain_or_app="$2"

    case "$provider" in
        "ploi")
            echo "/home/ploi/$domain_or_app"
            ;;
        "forge")
            echo "/home/forge/$domain_or_app"
            ;;
        "serverpilot")
            echo "/srv/users/serverpilot/apps/$domain_or_app"
            ;;
        "fortrabbit")
            echo "/srv/app/$domain_or_app"
            ;;
        *)
            # Return from config
            get_config "remote_project_dir" "" 2>/dev/null || echo ""
            ;;
    esac
}

# Get SSH key paths to check for a provider
# Arguments: provider_name
# Returns: newline-separated list of key paths
get_provider_ssh_keys() {
    local provider="${1:-$(detect_provider)}"
    local keys=(
        "$HOME/.ssh/id_rsa"
        "$HOME/.ssh/id_ed25519"
        "$HOME/.ssh/id_ecdsa"
    )

    # Add provider-specific key paths
    case "$provider" in
        "ploi")
            keys+=("$HOME/.ssh/ploi" "$HOME/.ssh/ploi_rsa")
            ;;
        "forge")
            keys+=("$HOME/.ssh/forge" "$HOME/.ssh/forge_rsa")
            ;;
        "serverpilot")
            keys+=("$HOME/.ssh/serverpilot" "$HOME/.ssh/serverpilot_rsa")
            ;;
    esac

    printf '%s\n' "${keys[@]}"
}

# ============================================================================
# Provider-Aware Configuration Getters
# ============================================================================

# Get SSH user with provider-aware defaults
# Arguments: none (uses CONFIG_FILE)
# Returns: SSH username
get_ssh_user() {
    local config_file="${CONFIG_FILE:-$PROVIDER_SCRIPT_DIR/../config.yml}"

    # First check explicit config
    local user
    user=$(get_config "ssh_user" "" 2>/dev/null) || true
    if [ -n "$user" ]; then
        echo "$user"
        return 0
    fi

    # Fall back to provider default
    get_provider_ssh_user "$(detect_provider)"
}

# Get remote project directory with provider-aware defaults
# Arguments: domain_or_app (optional, for building default path)
# Returns: remote project directory path
get_remote_project_dir() {
    local domain_or_app="${1:-}"
    local config_file="${CONFIG_FILE:-$PROVIDER_SCRIPT_DIR/../config.yml}"

    # First check explicit config
    local dir
    dir=$(get_config "remote_project_dir" "" 2>/dev/null) || true
    if [ -n "$dir" ]; then
        echo "$dir"
        return 0
    fi

    # Fall back to provider default
    if [ -n "$domain_or_app" ]; then
        get_provider_project_dir "$(detect_provider)" "$domain_or_app"
    else
        echo ""
    fi
}

# ============================================================================
# Provider Information Functions
# ============================================================================

# Print provider information
# Arguments: none
print_provider_info() {
    local provider
    provider=$(detect_provider)

    echo "Detected provider: $provider"
    echo "Default SSH user: $(get_provider_ssh_user "$provider")"

    local ssh_keys
    ssh_keys=$(get_provider_ssh_keys "$provider")
    echo "SSH key paths to check:"
    echo "$ssh_keys" | while read -r key; do
        if [ -f "$key" ]; then
            echo "  [exists] $key"
        else
            echo "  [missing] $key"
        fi
    done
}

# Check if provider supports a feature
# Arguments: provider_name, feature_name
# Returns: 0 if supported, 1 if not
provider_supports() {
    local provider="${1:-$(detect_provider)}"
    local feature="$2"

    case "$feature" in
        "cli-deploy")
            # Ploi has CLI deployment
            [ "$provider" = "ploi" ]
            ;;
        "api-deploy")
            # Ploi and Forge have API deployment
            [ "$provider" = "ploi" ] || [ "$provider" = "forge" ]
            ;;
        "webhook-deploy")
            # Most providers support webhook deployment
            [ "$provider" = "forge" ] || [ "$provider" = "envoyer" ]
            ;;
        "ssh-deploy")
            # All providers support SSH
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# Provider Source Functions
# ============================================================================

# Source provider-specific functions
# Arguments: provider_name (optional)
source_provider() {
    local provider="${1:-$(detect_provider)}"
    local provider_file="$PROVIDER_SCRIPT_DIR/providers/$provider.sh"

    if [ -f "$provider_file" ]; then
        source "$provider_file"
        return 0
    fi

    # Provider file not found, that's okay for generic
    return 0
}

# Export functions
export -f detect_provider
export -f get_provider_ssh_user
export -f get_provider_project_dir
export -f get_provider_ssh_keys
export -f get_ssh_user
export -f get_remote_project_dir
export -f print_provider_info
export -f provider_supports
export -f source_provider

# If called directly, print provider info
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    print_provider_info
fi
