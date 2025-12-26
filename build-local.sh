#!/bin/bash
# Build script for local testing with localhost URL

set -e

cd "$(dirname "$0")/twenty-crm-source"

echo "🔨 Building Twenty CRM with localhost configuration..."
echo ""

DOCKER_BUILDKIT=1 docker build \
  -f packages/twenty-docker/twenty/Dockerfile \
  --build-arg REACT_APP_SERVER_BASE_URL=http://localhost:3000 \
  --build-arg APP_VERSION=v1.0.1-localhost \
  -t wosool-ai/twenty-crm:test \
  .

echo ""
echo "✅ Build complete!"
echo "   Image: wosool-ai/twenty-crm:test"
echo ""
echo "🧪 To test:"
echo "   docker compose -f docker-compose.test.yml up -d"

