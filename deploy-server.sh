#!/bin/bash
# Server Deployment Script
# Run this on the server to set up and start all services

set -e

echo "🚀 Starting Twenty CRM Enterprise Deployment"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker is installed${NC}"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose (plugin) is available${NC}"
    else
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}✓ Docker Compose installed${NC}"
    fi
else
    echo -e "${GREEN}✓ Docker Compose is installed${NC}"
fi

# Navigate to project directory
cd /root/wosool-ai || { echo -e "${RED}Error: Project directory not found${NC}"; exit 1; }

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cat > .env << 'ENVEOF'
# Database Configuration
POSTGRES_ADMIN_USER=postgres
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
POSTGRES_HOST=global-db

# Application URLs
APP_URL=http://167.99.20.94

# Security Secrets (Generate strong random secrets)
JWT_SECRET=$(openssl rand -base64 32)
SUPER_ADMIN_KEY=$(openssl rand -base64 32)
SALLA_WEBHOOK_SECRET=$(openssl rand -base64 32)

# Salla Integration (Update with your credentials)
SALLA_CLIENT_ID=your_salla_client_id
SALLA_CLIENT_SECRET=your_salla_client_secret

# Clerk Integration
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_ZW1lcmdpbmctc2tpbmstNzUuY2xlcmsuYWNjb3VudHMuZGV2JA
CLERK_SECRET_KEY=sk_test_kIRXGCc7WeA4MMaAkh6L3d17NbGRB6QkRodqsYHqrm
CLERK_WEBHOOK_SECRET=whsec_e43dYrJxMJVz/8YBe3Lcq078Cx7CYpTm
CLERK_WEBHOOK_URL=https://api.wosool.ai/api/webhooks/clerk

# Grafana
GRAFANA_ADMIN_PASSWORD=admin

# PgAdmin
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=admin
ENVEOF
    
    # Generate actual random values
    POSTGRES_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    JWT_SEC=$(openssl rand -base64 32)
    ADMIN_KEY=$(openssl rand -base64 32)
    WEBHOOK_SEC=$(openssl rand -base64 32)
    # Note: CLERK_WEBHOOK_SECRET is already set to the provided value, no need to replace
    
    # Replace placeholders with actual values
    sed -i "s#\$(openssl rand -base64 32 | tr -d \"=+/\" | cut -c1-25)#${POSTGRES_PASS}#g" .env
    sed -i "s#\$(openssl rand -base64 32)#${JWT_SEC}#g" .env
    sed -i "s#\$(openssl rand -base64 32)#${ADMIN_KEY}#g" .env
    sed -i "s#\$(openssl rand -base64 32)#${WEBHOOK_SEC}#g" .env
    # CLERK_WEBHOOK_SECRET is already set correctly, no replacement needed
    
    echo -e "${GREEN}✓ .env file created with generated secrets${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Update SALLA_CLIENT_ID and SALLA_CLIENT_SECRET in .env${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Fix docker-compose.yml syntax error (line 11 has duplicate "environment:")
echo "Checking docker-compose.yml..."
if grep -q "environment:" docker-compose.yml | head -2; then
    echo "Fixing docker-compose.yml syntax..."
    sed -i '11d' docker-compose.yml
fi

# Stop and remove any existing containers
echo "Stopping existing containers..."
docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true

# Forcefully remove any orphaned containers with our naming pattern
echo "Removing orphaned containers..."
docker ps -a --filter "name=ent-" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true

# Remove any containers with conflicting names
CONTAINERS_TO_REMOVE="ent-tenant-db ent-global-db ent-tenant-manager ent-twenty-crm ent-nginx ent-redis ent-salla-orchestrator ent-prometheus ent-grafana ent-pgadmin ent-redis-commander"
for container in $CONTAINERS_TO_REMOVE; do
    if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "Removing old container: $container"
        docker rm -f "$container" 2>/dev/null || true
    fi
done

# Initialize source database (ONE TIME ONLY)
echo ""
echo -e "${YELLOW}Initializing source database (one-time setup)...${NC}"
if docker compose version &> /dev/null; then
    docker compose up -d tenant-db
else
    docker-compose up -d tenant-db
fi

# Wait for database to be ready
echo "Waiting for database to be ready..."
sleep 10

# Initialize source database
if docker compose version &> /dev/null; then
    docker compose exec -T tenant-db psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname = 'twenty'" | grep -q 1 || \
    docker compose exec -T tenant-db psql -U postgres -c "CREATE DATABASE twenty;" && \
    docker compose exec -T tenant-db psql -U postgres -d twenty << 'SQLINIT'
CREATE SCHEMA IF NOT EXISTS core;

CREATE TABLE IF NOT EXISTS core.application (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255),
  "universalIdentifier" VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS core.workspace (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "displayName" VARCHAR(255),
  subdomain VARCHAR(255),
  "activationStatus" VARCHAR(50),
  "databaseUrl" VARCHAR(255),
  "databaseSchema" VARCHAR(255),
  "workspaceCustomApplicationId" UUID,
  "defaultRoleId" UUID
);

CREATE TABLE IF NOT EXISTS core.role (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "workspaceId" UUID,
  label VARCHAR(255),
  "canUpdateAllSettings" BOOLEAN,
  "canAccessAllTools" BOOLEAN,
  "canReadAllObjectRecords" BOOLEAN,
  "canUpdateAllObjectRecords" BOOLEAN,
  "canSoftDeleteAllObjectRecords" BOOLEAN,
  "canDestroyAllObjectRecords" BOOLEAN
);

CREATE TABLE IF NOT EXISTS core."user" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE,
  "firstName" VARCHAR(255),
  "lastName" VARCHAR(255),
  "passwordHash" VARCHAR(255),
  "isEmailVerified" BOOLEAN DEFAULT false,
  "defaultWorkspaceId" UUID
);

CREATE TABLE IF NOT EXISTS core."userWorkspace" (
  "userId" UUID,
  "workspaceId" UUID,
  PRIMARY KEY ("userId", "workspaceId")
);

CREATE TABLE IF NOT EXISTS core.person (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS core.opportunity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255)
);
SQLINIT
else
    docker-compose exec -T tenant-db psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname = 'twenty'" | grep -q 1 || \
    docker-compose exec -T tenant-db psql -U postgres -c "CREATE DATABASE twenty;" && \
    docker-compose exec -T tenant-db psql -U postgres -d twenty << 'SQLINIT'
CREATE SCHEMA IF NOT EXISTS core;

CREATE TABLE IF NOT EXISTS core.application (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255),
  "universalIdentifier" VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS core.workspace (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "displayName" VARCHAR(255),
  subdomain VARCHAR(255),
  "activationStatus" VARCHAR(50),
  "databaseUrl" VARCHAR(255),
  "databaseSchema" VARCHAR(255),
  "workspaceCustomApplicationId" UUID,
  "defaultRoleId" UUID
);

CREATE TABLE IF NOT EXISTS core.role (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "workspaceId" UUID,
  label VARCHAR(255),
  "canUpdateAllSettings" BOOLEAN,
  "canAccessAllTools" BOOLEAN,
  "canReadAllObjectRecords" BOOLEAN,
  "canUpdateAllObjectRecords" BOOLEAN,
  "canSoftDeleteAllObjectRecords" BOOLEAN,
  "canDestroyAllObjectRecords" BOOLEAN
);

CREATE TABLE IF NOT EXISTS core."user" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE,
  "firstName" VARCHAR(255),
  "lastName" VARCHAR(255),
  "passwordHash" VARCHAR(255),
  "isEmailVerified" BOOLEAN DEFAULT false,
  "defaultWorkspaceId" UUID
);

CREATE TABLE IF NOT EXISTS core."userWorkspace" (
  "userId" UUID,
  "workspaceId" UUID,
  PRIMARY KEY ("userId", "workspaceId")
);

CREATE TABLE IF NOT EXISTS core.person (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS core.opportunity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255)
);
SQLINIT
fi

echo -e "${GREEN}✓ Source database initialized${NC}"

# Build and start services
echo ""
echo -e "${GREEN}Building and starting services...${NC}"
echo "This may take several minutes..."
echo ""

# Build services sequentially to avoid memory issues on small droplets
echo -e "${YELLOW}Building services sequentially to prevent memory issues...${NC}"
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Build services one at a time
echo "Building tenant-manager..."
$COMPOSE_CMD build --no-cache tenant-manager || echo "Warning: tenant-manager build failed, will retry later"

echo "Building salla-orchestrator..."
$COMPOSE_CMD build --no-cache salla-orchestrator || echo "Warning: salla-orchestrator build failed, will retry later"

# Build twenty-crm if the directory exists
if [ -d "/root/twenty" ]; then
    echo "Building twenty-crm..."
    $COMPOSE_CMD build --no-cache twenty-crm || echo "Warning: twenty-crm build failed"
else
    echo -e "${YELLOW}⚠️  /root/twenty directory not found, skipping twenty-crm build${NC}"
fi

# Start all services (pre-built images will be used)
echo "Starting all services..."
$COMPOSE_CMD up -d

# Wait for services to be ready
echo ""
echo "Waiting for services to start..."
sleep 10

# Check service status
echo ""
echo "Service Status:"
if docker compose version &> /dev/null; then
    docker compose ps
else
    docker-compose ps
fi

echo ""
echo -e "${GREEN}============================================"
echo "✓ Deployment Complete!"
echo "============================================${NC}"
echo ""
echo "Services are starting up. Access points:"
echo "  - Main Application: http://167.99.20.94"
echo "  - Grafana: http://167.99.20.94:3000 (admin/admin)"
echo "  - Prometheus: http://167.99.20.94:9092"
echo "  - PgAdmin: http://167.99.20.94:5050"
echo ""
echo "To view logs:"
echo "  docker compose logs -f"
echo ""
echo "To stop services:"
echo "  docker compose down"
echo ""

