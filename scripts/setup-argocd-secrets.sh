#!/usr/bin/env bash
# ArgoCD Secrets Setup Script
# Creates/updates SSM parameters for ArgoCD deployment
# Feature: 002-argocd-bootstrap

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-eu-central-1}"
SSM_DEPLOY_KEY_PATH="${SSM_DEPLOY_KEY_PATH:-/argocd/deploy-key}"
SSM_KEYCLOAK_ADMIN_PATH="${SSM_KEYCLOAK_ADMIN_PATH:-/keycloak/admin-credentials}"
DEPLOY_KEY_FILE="/tmp/argocd-deploy-key-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
    rm -f "$DEPLOY_KEY_FILE" "${DEPLOY_KEY_FILE}.pub" 2>/dev/null || true
}
trap cleanup EXIT

check_aws_cli() {
    if ! command -v aws &>/dev/null; then
        error "AWS CLI not found. Please install it first."
        exit 1
    fi

    if ! aws sts get-caller-identity &>/dev/null; then
        error "AWS credentials not configured. Please run 'aws configure' or set AWS_PROFILE."
        exit 1
    fi

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    info "Using AWS Account: $ACCOUNT_ID (Region: $AWS_REGION)"
}

check_parameter_exists() {
    local path="$1"
    aws ssm get-parameter --name "$path" --region "$AWS_REGION" &>/dev/null
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -r -p "$prompt" response
    response="${response:-$default}"
    [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# SSH Deploy Key Setup
# =============================================================================

setup_deploy_key() {
    echo ""
    echo "=========================================="
    echo "  SSH Deploy Key Setup"
    echo "=========================================="
    echo ""

    if check_parameter_exists "$SSM_DEPLOY_KEY_PATH"; then
        warn "Deploy key already exists at: $SSM_DEPLOY_KEY_PATH"
        echo ""
        echo "Options:"
        echo "  1) Keep existing key (skip)"
        echo "  2) Generate new key (will require updating GitHub deploy key)"
        echo "  3) Import existing private key from file"
        echo ""
        read -r -p "Choose option [1/2/3]: " choice

        case "$choice" in
            1)
                info "Keeping existing deploy key."
                return 0
                ;;
            2)
                info "Generating new deploy key..."
                ;;
            3)
                import_deploy_key
                return 0
                ;;
            *)
                info "Invalid choice. Keeping existing key."
                return 0
                ;;
        esac
    fi

    # Generate new SSH key
    info "Generating ED25519 SSH key pair..."
    ssh-keygen -t ed25519 -C "argocd-deploy-key" -f "$DEPLOY_KEY_FILE" -N "" -q

    PRIVATE_KEY=$(cat "$DEPLOY_KEY_FILE")
    PUBLIC_KEY=$(cat "${DEPLOY_KEY_FILE}.pub")

    echo ""
    success "SSH key pair generated!"
    echo ""
    echo "=========================================="
    echo "  PUBLIC KEY - Add to GitHub"
    echo "=========================================="
    echo ""
    echo "$PUBLIC_KEY"
    echo ""
    echo "=========================================="
    echo ""
    echo "Instructions:"
    echo "  1. Go to: https://github.com/web-tree/infrastructure/settings/keys"
    echo "  2. Click 'Add deploy key'"
    echo "  3. Title: 'ArgoCD Deploy Key'"
    echo "  4. Paste the public key above"
    echo "  5. Check 'Allow write access' ONLY if ArgoCD needs to push (usually not needed)"
    echo "  6. Click 'Add key'"
    echo ""

    if ! confirm "Have you added the public key to GitHub?"; then
        warn "Please add the key to GitHub before proceeding."
        if ! confirm "Continue anyway?"; then
            error "Aborted. Please run this script again after adding the key."
            exit 1
        fi
    fi

    # Store private key in SSM
    info "Storing private key in SSM at: $SSM_DEPLOY_KEY_PATH"
    aws ssm put-parameter \
        --name "$SSM_DEPLOY_KEY_PATH" \
        --type "SecureString" \
        --value "$PRIVATE_KEY" \
        --overwrite \
        --region "$AWS_REGION" \
        --description "ArgoCD SSH deploy key for Git repository access" \
        >/dev/null

    success "Deploy key stored in SSM!"
}

import_deploy_key() {
    echo ""
    read -r -p "Enter path to private key file: " key_file

    if [[ ! -f "$key_file" ]]; then
        error "File not found: $key_file"
        exit 1
    fi

    PRIVATE_KEY=$(cat "$key_file")

    # Validate it looks like a private key
    if ! echo "$PRIVATE_KEY" | grep -q "PRIVATE KEY"; then
        error "File does not appear to be a valid private key."
        exit 1
    fi

    info "Storing private key in SSM at: $SSM_DEPLOY_KEY_PATH"
    aws ssm put-parameter \
        --name "$SSM_DEPLOY_KEY_PATH" \
        --type "SecureString" \
        --value "$PRIVATE_KEY" \
        --overwrite \
        --region "$AWS_REGION" \
        --description "ArgoCD SSH deploy key for Git repository access" \
        >/dev/null

    success "Deploy key stored in SSM!"
}

# =============================================================================
# Keycloak Admin Credentials Setup
# =============================================================================

setup_keycloak_credentials() {
    echo ""
    echo "=========================================="
    echo "  Keycloak Admin Credentials Setup"
    echo "=========================================="
    echo ""

    if check_parameter_exists "$SSM_KEYCLOAK_ADMIN_PATH"; then
        warn "Keycloak credentials already exist at: $SSM_KEYCLOAK_ADMIN_PATH"
        if ! confirm "Update existing credentials?"; then
            info "Keeping existing credentials."
            return 0
        fi
    fi

    echo "Enter Keycloak admin credentials for Terraform to create the ArgoCD OIDC client."
    echo ""
    echo "This should be a Keycloak user with permissions to:"
    echo "  - Create/manage clients in the target realm"
    echo "  - Create/manage client scopes"
    echo ""
    echo "See: k8s/OPERATIONS.md for Keycloak setup instructions"
    echo ""

    read -r -p "Keycloak admin username: " KC_USERNAME
    read -r -s -p "Keycloak admin password: " KC_PASSWORD
    echo ""

    if [[ -z "$KC_USERNAME" || -z "$KC_PASSWORD" ]]; then
        error "Username and password are required."
        exit 1
    fi

    # Create JSON credentials
    KC_CREDENTIALS=$(cat <<EOF
{"username":"$KC_USERNAME","password":"$KC_PASSWORD"}
EOF
)

    info "Storing credentials in SSM at: $SSM_KEYCLOAK_ADMIN_PATH"
    aws ssm put-parameter \
        --name "$SSM_KEYCLOAK_ADMIN_PATH" \
        --type "SecureString" \
        --value "$KC_CREDENTIALS" \
        --overwrite \
        --region "$AWS_REGION" \
        --description "Keycloak admin credentials for ArgoCD OIDC client creation" \
        >/dev/null

    success "Keycloak credentials stored in SSM!"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  ArgoCD Secrets Setup"
    echo "=========================================="
    echo ""
    echo "This script will help you configure:"
    echo "  1. SSH deploy key for Git repository access"
    echo "  2. Keycloak admin credentials for OIDC client creation"
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI configured with appropriate permissions"
    echo "  - Access to GitHub repository settings"
    echo "  - Keycloak admin credentials"
    echo ""

    check_aws_cli

    echo ""
    if confirm "Continue with setup?" "y"; then
        setup_deploy_key
        setup_keycloak_credentials

        echo ""
        echo "=========================================="
        echo "  Setup Complete!"
        echo "=========================================="
        echo ""
        echo "SSM Parameters created:"
        echo "  - $SSM_DEPLOY_KEY_PATH"
        echo "  - $SSM_KEYCLOAK_ADMIN_PATH"
        echo ""
        echo "Next steps:"
        echo "  1. Run: terraform plan"
        echo "  2. Review the plan"
        echo "  3. Run: terraform apply"
        echo ""
    else
        info "Setup cancelled."
    fi
}

main "$@"
