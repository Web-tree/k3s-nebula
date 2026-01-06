#!/bin/bash
set -e

# Usage: ./create-user.sh <username> [group1,group2,...]
#
# Note: This script creates certificates with groups, but RBAC permissions
# are managed by Terraform in k8s/cluster-configuration/rbac.tf
# Ensure the appropriate ClusterRoleBinding exists for the groups used.

USERNAME="$1"
USER_GROUPS="$2"

if [ -z "$USERNAME" ]; then
  echo "Usage: $0 <username> [group1,group2,...]"
  exit 1
fi

# Directory to store user keys and certs
USER_DIR="users/$USERNAME"
mkdir -p "$USER_DIR"

# 1. Generate Private Key
echo "Generating private key for $USERNAME..."
openssl genrsa -out "$USER_DIR/$USERNAME.key" 2048

# 2. Generate CSR
echo "Generating CSR for $USERNAME..."
# Construct O=group1,O=group2 string
# Note: OpenSSL -subj expects /CN=name/O=group1/O=group2 format
SUBJ="/CN=$USERNAME"
if [ -n "$USER_GROUPS" ]; then
  # Split by comma
  for group in $(echo $USER_GROUPS | tr "," " "); do
    SUBJ="$SUBJ/O=$group"
  done
fi

openssl req -new -key "$USER_DIR/$USERNAME.key" -out "$USER_DIR/$USERNAME.csr" -subj "$SUBJ"

# 3. Submit CSR to Kubernetes
echo "Submitting CSR to Kubernetes..."
CSR_NAME="$USERNAME-csr"

# Delete existing CSR if it exists
kubectl delete csr "$CSR_NAME" --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CSR_NAME
spec:
  request: $(cat "$USER_DIR/$USERNAME.csr" | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 864000  # 10 days validity for example
  usages:
  - client auth
EOF

# 4. Approve CSR
# 4. Approve CSR
echo "Approving CSR..."
# Retry approval loop as the CSR might take a moment to be visible
MAX_APPROVE_RETRIES=10
for i in $(seq 1 $MAX_APPROVE_RETRIES); do
  if kubectl certificate approve "$CSR_NAME" 2>/dev/null; then
    echo "✓ CSR approved"
    break
  fi
  
  if [ $i -eq $MAX_APPROVE_RETRIES ]; then
    echo "Error: Failed to approve CSR after $MAX_APPROVE_RETRIES attempts."
    exit 1
  fi
  
  echo "Waiting for CSR to be available... (attempt $i/$MAX_APPROVE_RETRIES)"
  sleep 2
done

# 5. Retrieve Certificate
echo "Retrieving certificate..."
# Wait for the certificate to be issued with retry logic
MAX_RETRIES=30
RETRY_INTERVAL=2

for i in $(seq 1 $MAX_RETRIES); do
  kubectl get csr "$CSR_NAME" -o jsonpath='{.status.certificate}' | base64 --decode > "$USER_DIR/$USERNAME.crt"
  
  if [ -s "$USER_DIR/$USERNAME.crt" ]; then
    echo "✓ Certificate retrieved successfully"
    break
  fi
  
  if [ $i -eq $MAX_RETRIES ]; then
    echo "Error: Failed to retrieve certificate after $MAX_RETRIES attempts."
    exit 1
  fi
  
  echo "Waiting for certificate to be issued... (attempt $i/$MAX_RETRIES)"
  sleep $RETRY_INTERVAL
done


echo "Certificate retrieved successfully."

# 6. Configure kubectl (Targeting default kubeconfig)
echo "Configuring default kubectl config..."

TARGET_KUBECONFIG="${HOME}/.kube/config"
TARGET_CLUSTER_NAME="${CLUSTER_NAME:-k3s-ha}"

# Get cluster CA and server URL from CURRENT context (the one used to approve CSR)
CURRENT_CONTEXT=$(kubectl config current-context)
CURRENT_CLUSTER_NAME=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CURRENT_CONTEXT\")].context.cluster}")
SERVER_URL=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CURRENT_CLUSTER_NAME\")].cluster.server}")
CA_DATA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CURRENT_CLUSTER_NAME\")].cluster.certificate-authority-data}")

# Ensure target cluster exists in target kubeconfig
# Note: set-cluster doesn't support --certificate-authority-data directly, so we use a temp file
CA_FILE=$(mktemp)
echo "$CA_DATA" | base64 --decode > "$CA_FILE"

kubectl config set-cluster "$TARGET_CLUSTER_NAME" \
  --server="$SERVER_URL" \
  --certificate-authority="$CA_FILE" \
  --embed-certs=true \
  --kubeconfig="$TARGET_KUBECONFIG"

rm "$CA_FILE"

# Set credentials in target kubeconfig
kubectl config set-credentials "$USERNAME" \
  --client-certificate="$USER_DIR/$USERNAME.crt" \
  --client-key="$USER_DIR/$USERNAME.key" \
  --embed-certs=true \
  --kubeconfig="$TARGET_KUBECONFIG"

# Set context in target kubeconfig
CONTEXT_NAME="$USERNAME-context"
kubectl config set-context "$CONTEXT_NAME" \
  --cluster="$TARGET_CLUSTER_NAME" \
  --user="$USERNAME" \
  --kubeconfig="$TARGET_KUBECONFIG"

echo ""
echo "User $USERNAME created and configured in $TARGET_KUBECONFIG."
echo "To switch to this user's context, run:"
echo "  kubectl config use-context $CONTEXT_NAME"
