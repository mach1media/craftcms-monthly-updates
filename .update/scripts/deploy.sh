#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helpers.sh"

# Parse config
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"
DEPLOYMENT_METHOD=$(get_config "deployment_method")

# Source provider detection
source "$SCRIPT_DIR/provider-detect.sh"

case "$DEPLOYMENT_METHOD" in
    "github-actions")
        info "Deployment will be triggered by GitHub Actions on push"
        info "Check your repository's Actions tab for deployment status"
        ;;

    "ploi"|"ploi-cli"|"ploi-api")
        # Source Ploi provider functions
        source "$SCRIPT_DIR/providers/ploi.sh"

        # Determine deployment method preference
        USE_CLI=$(get_config "ploi_use_cli" "true" 2>/dev/null) || USE_CLI="true"
        STREAM_LOGS=$(get_config "ploi_stream_logs" "true" 2>/dev/null) || STREAM_LOGS="true"

        # Get server/site IDs (try both flat and nested formats)
        PLOI_SERVER_ID=$(get_nested_config "ploi.server_id" "" 2>/dev/null) || true
        PLOI_SITE_ID=$(get_nested_config "ploi.site_id" "" 2>/dev/null) || true

        # Fall back to flat format if nested not found
        if [ -z "$PLOI_SERVER_ID" ]; then
            PLOI_SERVER_ID=$(get_config "ploi_server_id" "" 2>/dev/null) || true
        fi
        if [ -z "$PLOI_SITE_ID" ]; then
            PLOI_SITE_ID=$(get_config "ploi_site_id" "" 2>/dev/null) || true
        fi

        # Try CLI first if preferred and available
        if [ "$USE_CLI" = "true" ] && ploi_cli_available; then
            if ploi_cli_configured; then
                if ploi_cli_initialized; then
                    info "Using Ploi CLI (project linked)"
                    if ploi_deploy_cli "$STREAM_LOGS"; then
                        success "Deployment completed via Ploi CLI"
                        exit 0
                    else
                        warn "Ploi CLI deployment failed, falling back to API"
                    fi
                else
                    info "Ploi CLI available but project not linked (no .ploi file)"
                    info "Run 'ploi init' in project root to link, or using API deployment"
                fi
            else
                info "Ploi CLI installed but not configured"
                info "Run 'ploi token' to configure, or using API deployment"
            fi
        fi

        # Fall back to API deployment
        if [ -n "$PLOI_SERVER_ID" ] && [ -n "$PLOI_SITE_ID" ]; then
            # Get API token
            PLOI_API_TOKEN=$(ploi_get_token)

            if [ -z "$PLOI_API_TOKEN" ]; then
                error "Ploi API token is required for API deployment"
            fi

            # Validate site exists (optional but helpful)
            if ! ploi_validate_site "$PLOI_SERVER_ID" "$PLOI_SITE_ID" 2>/dev/null; then
                warn "Could not validate Ploi site, proceeding anyway..."
            fi

            # Trigger deployment
            if ploi_deploy_api "$PLOI_SERVER_ID" "$PLOI_SITE_ID"; then
                info "Check Ploi dashboard for deployment progress"
                success "Deployment triggered via Ploi API"
            else
                error "Ploi API deployment failed"
            fi
        else
            # Neither CLI nor API available
            error "Ploi deployment requires either:
  1. Ploi CLI with 'ploi init' (run 'ploi token' first)
  2. ploi_server_id and ploi_site_id in config.yml

To find your IDs, check the URL in Ploi dashboard:
  https://ploi.io/panel/servers/[SERVER_ID]/sites/[SITE_ID]"
        fi
        ;;

    "envoyer")
        ENVOYER_URL=$(get_config "envoyer_url")

        info "Triggering Envoyer deployment..."

        curl -X GET "$ENVOYER_URL"

        info "Deployment triggered. Check Envoyer dashboard for status."
        ;;

    "forge")
        FORGE_URL=$(get_config "forge_url")

        info "Triggering Forge deployment..."

        curl -X GET "$FORGE_URL"

        info "Deployment triggered. Check Forge dashboard for status."
        ;;

    "manual")
        info "Manual deployment configured."
        info "Please deploy the changes manually to your production server."
        ;;

    *)
        error "Unknown deployment method: $DEPLOYMENT_METHOD"
        ;;
esac

success "Deployment initiated"
