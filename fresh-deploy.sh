#!/bin/bash
# Fresh deployment script for DigitalOcean droplet
# This script cleans the server, clones the new repo, and launches services

set -e

SERVER_IP="167.99.20.94"
SERVER_USER="root"
REPO_URL="https://github.com/wosool-ai/enterprise-platform.git"
DEPLOY_DIR="/root/wosool-ai"

echo "🚀 Starting fresh deployment on $SERVER_IP"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Step 1: Clean existing deployment
echo -e "${YELLOW}Step 1: Cleaning existing deployment...${NC}"
ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP << 'ENDSSH'
    echo "Stopping all containers..."
    cd /root/wosool-ai* 2>/dev/null && docker-compose down -v 2>/dev/null || true
    cd /root 2>/dev/null && docker-compose down -v 2>/dev/null || true
    
    echo "Removing old directories..."
    rm -rf /root/wosool-ai* /root/twenty-crm* 2>/dev/null || true
    
    echo "Cleaning up Docker resources..."
    docker system prune -af --volumes 2>/dev/null || true
    
    echo "✅ Cleanup complete"
ENDSSH

# Step 2: Clone new repository
echo -e "${YELLOW}Step 2: Cloning new repository...${NC}"
ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP << ENDSSH
    cd /root
    git clone $REPO_URL $DEPLOY_DIR
    cd $DEPLOY_DIR
    echo "✅ Repository cloned"
ENDSSH

# Step 3: Create .env file if it doesn't exist
echo -e "${YELLOW}Step 3: Setting up environment...${NC}"
ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP << 'ENDSSH'
    cd /root/wosool-ai
    
    if [ ! -f .env ]; then
        echo "Creating .env file with default values..."
        cat > .env << 'ENVEOF'
# Database Configuration
POSTGRES_PASSWORD=$(openssl rand -base64 32)
POSTGRES_ADMIN_USER=postgres
POSTGRES_ADMIN_PASSWORD=${POSTGRES_PASSWORD}
GLOBAL_DATABASE_NAME=twenty_global
SOURCE_DATABASE_NAME=twenty
TENANT_DB_PREFIX=twenty_tenant_

# Application URLs
APP_URL=http://167.99.20.94
API_URL=http://167.99.20.94/api

# JWT & Security
JWT_SECRET=$(openssl rand -base64 64)
SUPER_ADMIN_KEY=$(openssl rand -base64 32)

# Redis
REDIS_URL=redis://redis:6379

# Salla Integration (Update these with your actual credentials)
SALLA_CLIENT_ID=your_salla_client_id
SALLA_CLIENT_SECRET=your_salla_client_secret
SALLA_WEBHOOK_SECRET=$(openssl rand -base64 32)

# Clerk Integration (Update these with your actual credentials)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=your_clerk_publishable_key
CLERK_SECRET_KEY=your_clerk_secret_key
CLERK_WEBHOOK_SECRET=$(openssl rand -base64 32)

# Database Hosts
POSTGRES_HOST=tenant-db
GLOBAL_DB_HOST=global-db

# Ports
PORT=3001
ENVEOF
        echo "✅ .env file created"
        echo -e "${YELLOW}⚠️  Please update Salla and Clerk credentials in .env file${NC}"
    else
        echo "✅ .env file already exists"
    fi
ENDSSH

# Step 4: Deploy services
echo -e "${YELLOW}Step 4: Deploying services...${NC}"
ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP << 'ENDSSH'
    cd /root/wosool-ai
    
    echo "Making deploy script executable..."
    chmod +x deploy-server.sh
    
    echo "Running deployment script..."
    ./deploy-server.sh
    
    echo "✅ Deployment complete"
ENDSSH

echo ""
echo -e "${GREEN}✅ Fresh deployment completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. SSH into the server: ssh root@167.99.20.94"
echo "2. Update .env file with your Salla and Clerk credentials:"
echo "   cd /root/wosool-ai && nano .env"
echo "3. Restart services if needed:"
echo "   cd /root/wosool-ai && docker-compose restart"
echo ""
echo "Access points:"
echo "- Main Application: http://167.99.20.94"
echo "- API: http://167.99.20.94/api"
echo "- Grafana: http://167.99.20.94:3002"
echo "- Prometheus: http://167.99.20.94:9092"

