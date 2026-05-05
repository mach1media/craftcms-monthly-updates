#!/bin/bash

# Environment Detection Script
# Determines target environment based on current git branch or user selection

# Colors (may be overridden by helpers.sh)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
NC="${NC:-\033[0m}"

# Valid environments
VALID_ENVIRONMENTS=("staging" "production")

# Get current git branch
get_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Check if a branch exists (local or remote)
branch_exists() {
    local branch="$1"
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || \
    git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null
}

# Detect environment from branch name
# Returns: "staging", "production", or "prompt"
detect_environment_from_branch() {
    local branch="$1"

    case "$branch" in
        staging)
            echo "staging"
            ;;
        production)
            echo "production"
            ;;
        main|master)
            # main/master targets production only if no production branch exists
            if branch_exists "production"; then
                echo "prompt"
            else
                echo "production"
            fi
            ;;
        *)
            # Feature branches, hotfixes, etc. require prompt
            echo "prompt"
            ;;
    esac
}

# Capitalize first letter of a string (label form for prompts/messages)
env_label() {
    local env="$1"
    echo "$(tr '[:lower:]' '[:upper:]' <<< "${env:0:1}")${env:1}"
}

# Get configured environments as a bash array via stdout (newline-separated)
# Mirrors helpers.sh::get_configured_environments but is available before helpers.sh sources us
list_configured_environments() {
    local this_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local update_dir="$(dirname "$this_script_dir")"

    for env in "${VALID_ENVIRONMENTS[@]}"; do
        if [ -f "$update_dir/config.$env.yml" ]; then
            echo "$env"
        fi
    done
}

# Prompt user to select environment, listing only configured environments with labels
prompt_for_environment() {
    local action="${1:-operation}"

    # Build list of configured environments
    local configured=()
    while IFS= read -r env; do
        [ -n "$env" ] && configured+=("$env")
    done < <(list_configured_environments)

    local count="${#configured[@]}"

    if [ "$count" -eq 0 ]; then
        echo -e "${RED}No environments are configured.${NC}" >&2
        echo -e "${YELLOW}Run 'npm run update/setup' to configure an environment.${NC}" >&2
        return 1
    fi

    echo "" >&2
    echo -e "${YELLOW}Environment Selection Required${NC}" >&2
    echo -e "Current branch: ${BLUE}$(get_current_branch)${NC}" >&2
    echo "" >&2
    echo "Which environment should be used for this $action?" >&2

    local i=1
    for env in "${configured[@]}"; do
        echo "$i) $(env_label "$env")" >&2
        i=$((i + 1))
    done
    echo "" >&2

    while true; do
        read -p "Select environment (1-$count): " choice

        # Numeric selection
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
            echo "${configured[$((choice - 1))]}"
            return 0
        fi

        # Name match (case-insensitive)
        local lc_choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        for env in "${configured[@]}"; do
            if [ "$lc_choice" = "$env" ]; then
                echo "$env"
                return 0
            fi
        done

        echo -e "${RED}Invalid selection. Please enter a number between 1 and $count.${NC}" >&2
    done
}

# Main environment detection function
# Usage: ENV=$(get_environment [action_description])
# Can be overridden with ENV environment variable or --env=<env> flag
get_environment() {
    local action="${1:-operation}"

    # Check for environment override via ENV variable
    if [ -n "${ENV:-}" ]; then
        # Validate the override
        if [[ " ${VALID_ENVIRONMENTS[*]} " =~ " ${ENV} " ]]; then
            echo "$ENV"
            return 0
        else
            echo -e "${RED}Invalid environment: $ENV${NC}" >&2
            echo -e "${RED}Valid environments: ${VALID_ENVIRONMENTS[*]}${NC}" >&2
            return 1
        fi
    fi

    # Get current branch
    local branch=$(get_current_branch)

    if [ -z "$branch" ]; then
        echo -e "${RED}Could not determine current git branch${NC}" >&2
        return 1
    fi

    # Detect environment from branch
    local detected=$(detect_environment_from_branch "$branch")

    if [ "$detected" = "prompt" ]; then
        # If only one environment is configured, use it without prompting
        local configured=()
        while IFS= read -r env; do
            [ -n "$env" ] && configured+=("$env")
        done < <(list_configured_environments)

        if [ "${#configured[@]}" -eq 1 ]; then
            local only_env="${configured[0]}"
            echo -e "${BLUE}Only one environment configured — using $(env_label "$only_env")${NC}" >&2
            echo "$only_env"
            return 0
        fi

        # Multiple (or zero) configured — prompt user
        prompt_for_environment "$action"
    else
        echo "$detected"
    fi
}

# Get config file path for environment
# Usage: CONFIG_FILE=$(get_config_file_for_env "staging")
get_config_file_for_env() {
    local env="$1"
    # Always compute relative to this script's location (scripts/)
    local this_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local update_dir="$(dirname "$this_script_dir")"

    echo "$update_dir/config.$env.yml"
}

# Check if environment config exists
env_config_exists() {
    local env="$1"
    local config_file=$(get_config_file_for_env "$env")
    [ -f "$config_file" ]
}

# Validate environment and config
validate_environment() {
    local env="$1"

    if [[ ! " ${VALID_ENVIRONMENTS[*]} " =~ " ${env} " ]]; then
        echo -e "${RED}Invalid environment: $env${NC}" >&2
        return 1
    fi

    if ! env_config_exists "$env"; then
        echo -e "${RED}Configuration not found for $env environment${NC}" >&2
        echo -e "${YELLOW}Expected: $(get_config_file_for_env "$env")${NC}" >&2
        echo -e "${YELLOW}Run 'npm run update/setup' to configure this environment${NC}" >&2
        return 1
    fi

    return 0
}

# Display current environment info
show_environment_info() {
    local env="$1"
    local branch=$(get_current_branch)

    echo -e "${BLUE}Environment: ${GREEN}$(env_label "$env")${NC}"
    echo -e "${BLUE}Branch: ${NC}$branch"
    echo -e "${BLUE}Config: ${NC}$(get_config_file_for_env "$env")"
}

# Parse --env=<environment> from command line arguments
# Sets ENV variable if found
parse_env_flag() {
    for arg in "$@"; do
        case "$arg" in
            --env=*)
                ENV="${arg#*=}"
                export ENV
                ;;
            --staging)
                ENV="staging"
                export ENV
                ;;
            --production|--prod)
                ENV="production"
                export ENV
                ;;
        esac
    done
}

# Export functions
export -f get_current_branch
export -f branch_exists
export -f detect_environment_from_branch
export -f env_label
export -f list_configured_environments
export -f prompt_for_environment
export -f get_environment
export -f get_config_file_for_env
export -f env_config_exists
export -f validate_environment
export -f show_environment_info
export -f parse_env_flag
