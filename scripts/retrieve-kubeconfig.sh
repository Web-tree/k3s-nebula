#!/bin/bash
set -e

# Use TF_DIR if set, otherwise default to relative path
TARGET_DIR="${TF_DIR:-$(dirname "$0")/../cluster-infrastructure}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Terraform directory $TARGET_DIR not found."
    exit 1
fi

cd "$TARGET_DIR"

echo "Retrieving kubeconfig..."
CMD=$(terraform output -raw kubeconfig_command)

if [ -z "$CMD" ]; then
    echo "Error: Could not get kubeconfig_command from terraform output"
    exit 1
fi

eval "$CMD"

echo "✓ kubeconfig.yaml retrieved"
