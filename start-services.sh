#!/bin/bash
# Start all services after build

set -e

cd /root/wosool-ai

echo "🚀 Starting all services..."
echo ""

# Check if images are built
echo "Checking built images..."
docker images | grep wosool-ai || docker images | grep ent-

echo ""
echo "Starting services..."
docker compose up -d

echo ""
echo "Waiting 10 seconds for services to start..."
sleep 10

echo ""
echo "Service status:"
docker compose ps

echo ""
echo "To view logs:"
echo "  docker compose logs -f"

