#!/bin/bash
# Resolve merge conflict and setup

set -e

echo "🔧 Resolving merge conflict..."

cd /root/wosool-ai

# Check what changes exist
echo "Checking local changes..."
git status

# Stash local changes
echo "Stashing local changes..."
git stash

# Pull latest
echo "Pulling latest changes..."
git pull

# Show what was stashed (optional)
echo ""
echo "Local changes were stashed. To see them: git stash show"
echo ""

# Now run setup
echo "Running setup..."
chmod +x setup-swap-and-clean.sh
./setup-swap-and-clean.sh

