#!/bin/bash
set -e

# Wait for Kubernetes API to be ready
# Usage: KUBECONFIG=path/to/kubeconfig.yaml ./wait-for-cluster.sh

MAX_RETRIES=30
RETRY_INTERVAL=10

echo "Waiting for Kubernetes API to be ready..."

for i in $(seq 1 $MAX_RETRIES); do
  if kubectl cluster-info &>/dev/null; then
    echo "✓ Kubernetes API is ready"
    
    # Also wait for nodes to be ready
    echo "Waiting for nodes to be ready..."
    if kubectl wait --for=condition=Ready nodes --all --timeout=120s &>/dev/null; then
      echo "✓ All nodes are ready"
      exit 0
    else
      echo "Warning: Not all nodes are ready yet, but API is accessible"
      exit 0
    fi
  fi
  
  echo "Attempt $i/$MAX_RETRIES: API not ready yet, waiting ${RETRY_INTERVAL}s..."
  sleep $RETRY_INTERVAL
done

echo "Error: Kubernetes API did not become ready after $MAX_RETRIES attempts"
exit 1
