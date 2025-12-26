#!/bin/bash
# Production Build Script for Twenty CRM
# Builds and pushes the custom Twenty CRM Docker image for production

set -e

DOCKER_ORG="wosool-ai"
IMAGE_NAME="twenty-crm"
IMAGE_TAG="production"
FULL_IMAGE_NAME="$DOCKER_ORG/$IMAGE_NAME:$IMAGE_TAG"

# Get production server URL from environment or use default
SERVER_URL="${SERVER_URL:-https://api.wosool.ai}"
CLERK_PUBLISHABLE_KEY="${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY:-}"

log_step() {
    echo "===================================================="
    echo "🚀 $1"
    echo "===================================================="
    echo ""
}

# Check if we're in the right directory
if [ ! -d "twenty-crm-source" ]; then
    echo "❌ Error: twenty-crm-source directory not found"
    echo "   Please run this script from the project root"
    exit 1
fi

log_step "Building Production Docker Image"
echo "Image: $FULL_IMAGE_NAME"
echo "Server URL: $SERVER_URL"
echo ""

cd twenty-crm-source

# Build arguments
BUILD_ARGS=(
    -f packages/twenty-docker/twenty/Dockerfile
    --build-arg REACT_APP_SERVER_BASE_URL="$SERVER_URL"
    --build-arg APP_VERSION="v1.0.0-production"
)

# Add Clerk key if provided
if [ -n "$CLERK_PUBLISHABLE_KEY" ]; then
    BUILD_ARGS+=(--build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$CLERK_PUBLISHABLE_KEY")
    echo "✅ Clerk publishable key will be included in build"
else
    echo "⚠️  No Clerk publishable key provided (will be injected at runtime)"
fi

BUILD_ARGS+=(-t "$FULL_IMAGE_NAME" .)

echo "Building with Docker BuildKit..."
DOCKER_BUILDKIT=1 docker build "${BUILD_ARGS[@]}"

cd ..

echo ""
log_step "Build Complete"
echo "✅ Image built: $FULL_IMAGE_NAME"
echo "   Size: $(docker images --format "{{.Size}}" "$FULL_IMAGE_NAME")"
echo ""

# Ask if user wants to push to Docker Hub
read -p "Push image to Docker Hub? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_step "Pushing to Docker Hub"
    
    # Check if logged in to Docker Hub
    if ! docker info | grep -q "Username"; then
        echo "⚠️  Not logged in to Docker Hub"
        echo "   Please run: docker login"
        exit 1
    fi
    
    docker push "$FULL_IMAGE_NAME"
    echo ""
    echo "✅ Image pushed to Docker Hub: $FULL_IMAGE_NAME"
    echo ""
    echo "📋 To use this image in production:"
    echo "   Update docker-compose.yml to use: $FULL_IMAGE_NAME"
else
    echo "⏭️  Skipping push to Docker Hub"
    echo ""
    echo "📋 To push later, run:"
    echo "   docker push $FULL_IMAGE_NAME"
fi

echo ""
echo "✅ Production build complete!"

