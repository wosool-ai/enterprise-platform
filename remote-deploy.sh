#!/bin/bash
# Remote deployment script using provided SSH key
# This script will clean, clone, and deploy on the DigitalOcean server

set -e

SERVER_IP="167.99.20.94"
SERVER_USER="root"
REPO_URL="https://github.com/wosool-ai/enterprise-platform.git"
DEPLOY_DIR="/root/wosool-ai"

# SSH key content (embedded)
SSH_KEY_CONTENT='-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAVaLMQTFxgSfwsFBmn57FKC1OI+zOJBDCe2fnwX2jB1QAAAKALtgCmC7YA
pgAAAAtzc2gtZWQyNTUxOQAAACAVaLMQTFxgSfwsFBmn57FKC1OI+zOJBDCe2fnwX2jB1Q
AAAEDUmWrbTzOlw2lTTvJc74H8wnqPqzTuN+Ndxu11FPF+qRVosxBMXGBJ/CwUGafnsUoL
U4j7M4kEMJ7Z+fBfaMHVAAAAG3VidW50dUB1YnVudHUtRGVsbC1HMTYtNzYzMAEC
-----END OPENSSH PRIVATE KEY-----'

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create temporary SSH key file
SSH_KEY_FILE=$(mktemp)
trap "rm -f $SSH_KEY_FILE" EXIT

echo "$SSH_KEY_CONTENT" > $SSH_KEY_FILE
chmod 600 $SSH_KEY_FILE

echo "🚀 Starting fresh deployment on $SERVER_IP"
echo "=========================================="
echo ""

# Step 1: Clean existing deployment
echo -e "${YELLOW}Step 1: Cleaning existing deployment...${NC}"
ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SERVER_USER@$SERVER_IP << 'ENDSSH'
    set -e
    echo "Stopping all containers..."
    for dir in /root/wosool-ai* /root/twenty-crm*; do
        if [ -d "$dir" ]; then
            cd "$dir"
            docker-compose down -v 2>/dev/null || docker compose down -v 2>/dev/null || true
        fi
    done
    
    echo "Removing old directories..."
    rm -rf /root/wosool-ai* /root/twenty-crm* 2>/dev/null || true
    
    echo "Cleaning up Docker resources..."
    docker container prune -f 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    
    echo "✅ Cleanup complete"
ENDSSH

# Step 2: Clone new repository
echo -e "${YELLOW}Step 2: Cloning new repository...${NC}"
ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SERVER_USER@$SERVER_IP << ENDSSH
    set -e
    cd /root
    echo "Cloning repository..."
    git clone $REPO_URL $DEPLOY_DIR
    cd $DEPLOY_DIR
    echo "✅ Repository cloned successfully"
ENDSSH

# Step 3: Deploy services
echo -e "${YELLOW}Step 3: Deploying services...${NC}"
ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SERVER_USER@$SERVER_IP << 'ENDSSH'
    set -e
    cd /root/wosool-ai
    
    echo "Making deploy script executable..."
    chmod +x deploy-server.sh
    
    echo "Running deployment script..."
    ./deploy-server.sh
    
    echo "✅ Deployment initiated"
ENDSSH

echo ""
echo -e "${GREEN}✅ Fresh deployment completed successfully!${NC}"
echo ""
echo "Services are being deployed. You can monitor progress with:"
echo "  ssh -i <key> root@167.99.20.94 'cd /root/wosool-ai && docker-compose logs -f'"
echo ""
echo "Next steps:"
echo "1. SSH into the server: ssh -i <key> root@167.99.20.94"
echo "2. Update .env file with your Salla and Clerk credentials:"
echo "   cd /root/wosool-ai && nano .env"
echo "3. Check service status:"
echo "   cd /root/wosool-ai && docker-compose ps"
echo ""
echo "Access points:"
echo "- Main Application: http://167.99.20.94"
echo "- API: http://167.99.20.94/api"
echo "- Grafana: http://167.99.20.94:3002"
echo "- Prometheus: http://167.99.20.94:9092"

