#!/bin/bash

# Ploi Provider Abstraction
# Provides Ploi CLI and API integration for deployments
#
# Features:
# - Automatic CLI detection and usage when available
# - Fallback to REST API via curl
# - Log streaming during deployment
# - Server and site validation

set -e

# Get script directory
PLOI_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helpers if not already sourced
if ! declare -f info &>/dev/null; then
    source "$PLOI_SCRIPT_DIR/../helpers.sh"
fi

# Ploi API Base URL
PLOI_API_URL="https://ploi.io/api"

# ============================================================================
# Ploi CLI Functions
# ============================================================================

# Check if Ploi CLI is installed
# Returns: 0 if installed, 1 if not
ploi_cli_available() {
    command -v ploi &>/dev/null
}

# Check if Ploi CLI is configured with a token
# Returns: 0 if configured, 1 if not
ploi_cli_configured() {
    if ! ploi_cli_available; then
        return 1
    fi

    # Check if ploi can authenticate (token is set)
    # The CLI stores token in ~/.ploi/config.json
    local config_file="$HOME/.ploi/config.json"
    if [ -f "$config_file" ]; then
        # Check if token exists in config
        if grep -q '"token":' "$config_file" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Check if the current directory is linked to a Ploi site
# Returns: 0 if linked, 1 if not
ploi_cli_initialized() {
    if ! ploi_cli_available; then
        return 1
    fi

    # Check for .ploi file in current or parent directories
    local dir="$(pwd)"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/.ploi" ]; then
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    return 1
}

# Deploy using Ploi CLI with log streaming
# Arguments: none (uses linked project)
# Returns: exit code from ploi command
ploi_deploy_cli() {
    local stream_logs=${1:-true}

    if ! ploi_cli_available; then
        error "Ploi CLI is not installed"
        return 1
    fi

    if ! ploi_cli_configured; then
        error "Ploi CLI is not configured. Run 'ploi token' to set your API token."
        return 1
    fi

    info "Triggering deployment via Ploi CLI..."

    if [ "$stream_logs" = "true" ]; then
        ploi deploy:run --log
    else
        ploi deploy:run
    fi

    return $?
}

# ============================================================================
# Ploi API Functions
# ============================================================================

# Get Ploi API token from environment or config
# Arguments: optional config file path
# Returns: API token string, exits if not found
ploi_get_token() {
    local config_file="${CONFIG_FILE:-}"

    # First check environment variable
    if [ -n "${PLOI_API_TOKEN:-}" ]; then
        echo "$PLOI_API_TOKEN"
        return 0
    fi

    # Then check config file
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        local token

        # Try nested format first: ploi.api_token
        token=$(get_nested_config "ploi.api_token" "" 2>/dev/null) || true
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi

        # Try flat format: ploi_api_token
        token=$(get_config "ploi_api_token" "" 2>/dev/null) || true
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi

    # Prompt for token if not found
    echo -e "${YELLOW}Ploi API token not found. Enter token:${NC}" >&2
    read -rs token
    echo >&2

    if [ -z "$token" ]; then
        error "Ploi API token is required"
        return 1
    fi

    echo "$token"
}

# Make authenticated API request to Ploi
# Arguments: method, endpoint, [data]
# Returns: JSON response
ploi_api_request() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local token

    token=$(ploi_get_token) || return 1

    local url="${PLOI_API_URL}${endpoint}"
    local curl_opts=(
        -s
        -X "$method"
        -H "Authorization: Bearer $token"
        -H "Content-Type: application/json"
        -H "Accept: application/json"
    )

    if [ -n "$data" ]; then
        curl_opts+=(-d "$data")
    fi

    curl "${curl_opts[@]}" "$url"
}

# Get server information
# Arguments: server_id
# Returns: JSON server object
ploi_get_server() {
    local server_id="$1"

    if [ -z "$server_id" ]; then
        error "Server ID is required"
        return 1
    fi

    ploi_api_request "GET" "/servers/$server_id"
}

# Get site information
# Arguments: server_id, site_id
# Returns: JSON site object
ploi_get_site() {
    local server_id="$1"
    local site_id="$2"

    if [ -z "$server_id" ] || [ -z "$site_id" ]; then
        error "Server ID and Site ID are required"
        return 1
    fi

    ploi_api_request "GET" "/servers/$server_id/sites/$site_id"
}

# Validate server and site exist
# Arguments: server_id, site_id
# Returns: 0 if valid, 1 if not
ploi_validate_site() {
    local server_id="$1"
    local site_id="$2"

    info "Validating Ploi server ($server_id) and site ($site_id)..."

    local response
    response=$(ploi_get_site "$server_id" "$site_id")

    # Check for error in response
    if echo "$response" | grep -q '"error"' 2>/dev/null; then
        local error_msg
        error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | sed 's/"message":"//;s/"$//')
        error "Ploi API error: $error_msg"
        return 1
    fi

    # Check if we got a valid site response
    if echo "$response" | grep -q '"domain"' 2>/dev/null; then
        local domain
        domain=$(echo "$response" | grep -o '"domain":"[^"]*"' | head -1 | sed 's/"domain":"//;s/"$//')
        info "Validated site: $domain"
        return 0
    fi

    error "Unable to validate Ploi site"
    return 1
}

# Deploy using Ploi REST API
# Arguments: server_id, site_id
# Returns: 0 on success, 1 on failure
ploi_deploy_api() {
    local server_id="$1"
    local site_id="$2"

    if [ -z "$server_id" ] || [ -z "$site_id" ]; then
        error "Server ID and Site ID are required for API deployment"
        return 1
    fi

    info "Triggering deployment via Ploi API..."

    local response
    response=$(ploi_api_request "POST" "/servers/$server_id/sites/$site_id/deploy")

    # Check for error in response
    if echo "$response" | grep -q '"error"' 2>/dev/null; then
        local error_msg
        error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | sed 's/"message":"//;s/"$//')
        error "Ploi API error: $error_msg"
        return 1
    fi

    # Check for success
    if echo "$response" | grep -q '"message"' 2>/dev/null; then
        local message
        message=$(echo "$response" | grep -o '"message":"[^"]*"' | sed 's/"message":"//;s/"$//')
        success "Ploi: $message"
        return 0
    fi

    success "Deployment triggered successfully"
    return 0
}

# Get deploy script content
# Arguments: server_id, site_id
# Returns: deploy script content
ploi_get_deploy_script() {
    local server_id="$1"
    local site_id="$2"

    ploi_api_request "GET" "/servers/$server_id/sites/$site_id/deploy/script"
}

# Update deploy script
# Arguments: server_id, site_id, script_content
# Returns: 0 on success, 1 on failure
ploi_update_deploy_script() {
    local server_id="$1"
    local site_id="$2"
    local script="$3"

    # Escape script content for JSON
    local escaped_script
    escaped_script=$(echo "$script" | jq -Rs .)

    local data="{\"script\": $escaped_script}"

    ploi_api_request "PATCH" "/servers/$server_id/sites/$site_id/deploy/script" "$data"
}

# ============================================================================
# Combined Functions (CLI + API)
# ============================================================================

# Deploy using best available method (CLI preferred, API fallback)
# Arguments: server_id, site_id, stream_logs
# Returns: 0 on success, 1 on failure
ploi_deploy() {
    local server_id="${1:-}"
    local site_id="${2:-}"
    local stream_logs="${3:-true}"

    # Try CLI first if available and configured
    if ploi_cli_available && ploi_cli_configured; then
        if ploi_cli_initialized; then
            info "Using Ploi CLI (project is linked)"
            ploi_deploy_cli "$stream_logs"
            return $?
        else
            info "Ploi CLI available but project not linked (no .ploi file)"
        fi
    fi

    # Fall back to API
    if [ -z "$server_id" ] || [ -z "$site_id" ]; then
        # Try to get from config
        server_id=$(get_config "ploi_server_id" "" 2>/dev/null) || true
        site_id=$(get_config "ploi_site_id" "" 2>/dev/null) || true

        # Also try nested format
        if [ -z "$server_id" ]; then
            server_id=$(get_nested_config "ploi.server_id" "" 2>/dev/null) || true
        fi
        if [ -z "$site_id" ]; then
            site_id=$(get_nested_config "ploi.site_id" "" 2>/dev/null) || true
        fi
    fi

    if [ -z "$server_id" ] || [ -z "$site_id" ]; then
        error "Server ID and Site ID required. Configure in config.yml or use Ploi CLI with 'ploi init'"
        return 1
    fi

    info "Using Ploi REST API"
    ploi_deploy_api "$server_id" "$site_id"
    return $?
}

# ============================================================================
# Ploi Provider Path Helpers
# ============================================================================

# Get default Ploi paths based on domain
# Arguments: domain
# Returns: nothing, sets global variables
ploi_get_default_paths() {
    local domain="$1"

    if [ -z "$domain" ]; then
        return 1
    fi

    # Ploi default path structure
    PLOI_PROJECT_DIR="/home/ploi/$domain"
    PLOI_SSH_USER="ploi"
}

# Check if a path looks like a Ploi path
# Arguments: path
# Returns: 0 if Ploi path, 1 if not
ploi_is_ploi_path() {
    local path="$1"

    [[ "$path" == /home/ploi/* ]]
}

# ============================================================================
# Setup Helpers
# ============================================================================

# Print Ploi CLI installation instructions
ploi_print_cli_install() {
    echo ""
    echo "To install Ploi CLI (optional):"
    echo ""
    echo "  # macOS (Homebrew)"
    echo "  brew tap ploi/ploi"
    echo "  brew install ploi"
    echo ""
    echo "  # Or download binary from:"
    echo "  https://github.com/ploi/ploi-cli/releases"
    echo ""
    echo "After installation, configure with:"
    echo "  ploi token"
    echo ""
}

# Print instructions for finding Ploi server/site IDs
ploi_print_id_instructions() {
    echo ""
    echo "To find your Ploi Server ID and Site ID:"
    echo ""
    echo "1. Log in to https://ploi.io"
    echo "2. Go to your server"
    echo "3. Select your site"
    echo "4. Look at the URL:"
    echo "   https://ploi.io/panel/servers/[SERVER_ID]/sites/[SITE_ID]"
    echo ""
    echo "Or use Ploi CLI:"
    echo "  ploi servers      # List servers with IDs"
    echo "  ploi sites        # List sites with IDs"
    echo ""
}

# Export functions for use by other scripts
export -f ploi_cli_available
export -f ploi_cli_configured
export -f ploi_cli_initialized
export -f ploi_deploy_cli
export -f ploi_get_token
export -f ploi_api_request
export -f ploi_get_server
export -f ploi_get_site
export -f ploi_validate_site
export -f ploi_deploy_api
export -f ploi_get_deploy_script
export -f ploi_update_deploy_script
export -f ploi_deploy
export -f ploi_get_default_paths
export -f ploi_is_ploi_path
export -f ploi_print_cli_install
export -f ploi_print_id_instructions
