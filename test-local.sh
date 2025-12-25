#!/bin/bash
# Quick test script for local Docker build

set -e

echo "🧪 Testing Local Docker Build"
echo "=============================="
echo ""

# Check if image exists
if ! docker images | grep -q "wosool-ai/twenty-crm.*test"; then
    echo "❌ Image wosool-ai/twenty-crm:test not found"
    echo "   Build it first with:"
    echo "   cd twenty-crm-source"
    echo "   docker build -f packages/twenty-docker/twenty/Dockerfile -t wosool-ai/twenty-crm:test ."
    exit 1
fi

echo "✅ Image found"
echo ""

# Start test environment
echo "🚀 Starting test environment..."
docker compose -f docker-compose.test.yml up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check health
echo ""
echo "📋 Checking service health..."
if docker compose -f docker-compose.test.yml ps | grep -q "healthy\|Up"; then
    echo "✅ Services are running"
else
    echo "⚠️  Some services may not be healthy. Check logs:"
    echo "   docker compose -f docker-compose.test.yml logs"
fi

echo ""
echo "🌐 Access the application at: http://localhost:3000"
echo ""
echo "📋 Useful commands:"
echo "   View logs:        docker compose -f docker-compose.test.yml logs -f"
echo "   Stop services:   docker compose -f docker-compose.test.yml down"
echo "   Check status:    docker compose -f docker-compose.test.yml ps"
echo ""
echo "✅ Test environment ready!"
