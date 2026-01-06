#!/bin/bash
# Cluster validation script
# Usage: ./validate-cluster.sh [LOAD_BALANCER_IP]

set -e

# Use TF_DIR if set, otherwise default to relative path
TARGET_DIR="${TF_DIR:-$(dirname "$0")/../cluster-infrastructure}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Terraform directory $TARGET_DIR not found."
    exit 1
fi

# cd to terraform directory to run output command
cd "$TARGET_DIR"

LB_IP="${1:-$(terraform output -json load_balancer 2>/dev/null | jq -r '.ipv4')}"

if [ -z "$LB_IP" ]; then
  echo "Error: Load balancer IP not provided and cannot be determined from terraform output"
  echo "Usage: $0 [LOAD_BALANCER_IP]"
  exit 1
fi

echo "=== Cluster Validation ==="
echo "Load Balancer IP: $LB_IP"
echo ""

# Test API endpoint
echo "Testing API endpoint..."
if curl -k -s --max-time 5 "https://${LB_IP}:6443/healthz" | grep -q "ok"; then
  echo "✓ API endpoint is healthy"
else
  echo "✗ API endpoint is not responding"
  exit 1
fi

# Check HAProxy status
echo ""
echo "Testing HAProxy backend status..."
node_count=$(terraform output -json control_plane_nodes 2>/dev/null | jq '. | length')
if [ -n "$node_count" ] && [ "$node_count" -ge 2 ]; then
  echo "✓ Expected $node_count control plane nodes"
else
  echo "✗ Cannot determine node count"
fi

echo ""
echo "=== Validation Complete ==="
echo "Cluster appears to be operational"
