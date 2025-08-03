#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helpers.sh"

# Parse config
export CONFIG_FILE="$SCRIPT_DIR/../config.yml"
DEPLOYMENT_METHOD=$(get_config "deployment_method")

case "$DEPLOYMENT_METHOD" in
    "github-actions")
        info "Deployment will be triggered by GitHub Actions on push"
        info "Check your repository's Actions tab for deployment status"
        ;;
        
    "ploi")
        PLOI_SERVER_ID=$(get_config "ploi_server_id")
        PLOI_SITE_ID=$(get_config "ploi_site_id")
        PLOI_API_TOKEN=$(get_password "ploi_api_token" "Enter Ploi API token:")
        
        info "Triggering Ploi deployment..."
        
        curl -X POST "https://ploi.io/api/servers/$PLOI_SERVER_ID/sites/$PLOI_SITE_ID/deploy" \
            -H "Authorization: Bearer $PLOI_API_TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json"
            
        info "Deployment triggered. Check Ploi dashboard for status."
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