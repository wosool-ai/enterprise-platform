#!/bin/bash
# Build and publish custom Twenty CRM Docker image

set -e

cd /home/ubuntu/wosool-ai-enterprise

echo "🏗️  Building Custom Twenty CRM Docker Image"
echo "============================================"
echo ""

# Check if repository is cloned
if [ ! -d "twenty-crm-source" ]; then
    echo "❌ twenty-crm-source directory not found"
    echo "   Run: git clone https://github.com/twentyhq/twenty.git twenty-crm-source"
    exit 1
fi

cd twenty-crm-source

# Check Docker Hub login
echo "🔐 Checking Docker Hub authentication..."
if ! docker info | grep -q "Username"; then
    echo "⚠️  Not logged into Docker Hub"
    echo "   Please run: docker login"
    read -p "Continue anyway? (y/n): " continue
    if [ "$continue" != "y" ]; then
        exit 1
    fi
fi

# Get version
VERSION=${1:-v1.0.0}
IMAGE_NAME="wosool-ai/twenty-crm"
SERVER_URL=${SERVER_URL:-http://167.99.20.94}

echo ""
echo "📋 Build Configuration:"
echo "   Image: ${IMAGE_NAME}:latest"
echo "   Version: ${IMAGE_NAME}:${VERSION}"
echo "   Server URL: ${SERVER_URL}"
echo ""

read -p "Continue with build? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Build cancelled"
    exit 0
fi

echo ""
echo "🔨 Starting build (this may take 15-30 minutes)..."
echo ""

# Build with Docker BuildKit
DOCKER_BUILDKIT=1 docker build \
  -f packages/twenty-docker/twenty/Dockerfile \
  -t ${IMAGE_NAME}:latest \
  -t ${IMAGE_NAME}:${VERSION} \
  --build-arg REACT_APP_SERVER_BASE_URL=${SERVER_URL} \
  --build-arg APP_VERSION=${VERSION} \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 Image tags created:"
    docker images | grep "${IMAGE_NAME}" | head -2
    echo ""
    
    read -p "Push to Docker Hub? (y/n): " push
    if [ "$push" = "y" ]; then
        echo ""
        echo "📤 Pushing to Docker Hub..."
        docker push ${IMAGE_NAME}:latest
        docker push ${IMAGE_NAME}:${VERSION}
        echo ""
        echo "✅ Images pushed successfully!"
        echo ""
        echo "🔗 View at: https://hub.docker.com/r/${IMAGE_NAME}"
    else
        echo ""
        echo "⏭️  Skipping push. Push manually with:"
        echo "   docker push ${IMAGE_NAME}:latest"
        echo "   docker push ${IMAGE_NAME}:${VERSION}"
    fi
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "✅ Build process complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Update docker-compose.yml to use: ${IMAGE_NAME}:latest"
echo "   2. Deploy: docker compose pull && docker compose up -d"
echo "   3. Cleanup: rm -rf twenty-crm-source (after verification)"

