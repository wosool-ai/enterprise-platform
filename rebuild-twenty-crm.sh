#!/bin/bash
# Rebuild twenty-crm after fixing inotify limit

set -e

cd /root/wosool-ai

echo "🔨 Rebuilding twenty-crm service..."
echo ""

# Clean up any failed builds
echo "Cleaning up..."
docker compose down 2>/dev/null || true
docker builder prune -f

# Rebuild twenty-crm
echo "Building twenty-crm (this may take 10-15 minutes)..."
docker compose build --no-cache --progress=plain twenty-crm

echo ""
echo "✅ Build complete! Starting services..."
docker compose up -d

echo ""
echo "Service status:"
docker compose ps

