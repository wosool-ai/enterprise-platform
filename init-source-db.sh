#!/bin/bash
# One-time source database initialization script
# Run this ONCE to initialize the source database template

set -e

echo "🔄 Initializing source database 'twenty' (one-time setup)..."

cd /root/twenty-crm-enterprise-v1 || cd "$(dirname "$0")"

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

POSTGRES_HOST=${POSTGRES_HOST:-tenant-db}
POSTGRES_USER=${POSTGRES_ADMIN_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
SOURCE_DB=${SOURCE_DATABASE_NAME:-twenty}

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "❌ Error: POSTGRES_PASSWORD not set in .env"
    exit 1
fi

# Check if using docker-compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Error: docker-compose not found"
    exit 1
fi

# Start tenant-db if not running
echo "Starting tenant-db container..."
$COMPOSE_CMD up -d tenant-db

# Wait for database
echo "Waiting for database to be ready..."
sleep 10

# Check if database exists
DB_EXISTS=$($COMPOSE_CMD exec -T tenant-db psql -U "$POSTGRES_USER" -tAc "SELECT 1 FROM pg_database WHERE datname = '$SOURCE_DB'" 2>/dev/null || echo "0")

if [ "$DB_EXISTS" = "1" ]; then
    echo "✅ Source database '$SOURCE_DB' already exists"
else
    echo "📦 Creating source database '$SOURCE_DB'..."
    $COMPOSE_CMD exec -T tenant-db psql -U "$POSTGRES_USER" -c "CREATE DATABASE \"$SOURCE_DB\";"
fi

# Initialize schema
echo "📦 Initializing core schema..."
$COMPOSE_CMD exec -T tenant-db psql -U "$POSTGRES_USER" -d "$SOURCE_DB" << 'EOF'
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
EOF

# Verify
TABLE_COUNT=$($COMPOSE_CMD exec -T tenant-db psql -U "$POSTGRES_USER" -d "$SOURCE_DB" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'core'")

echo ""
echo "✅ Source database initialization complete!"
echo "   Database: $SOURCE_DB"
echo "   Tables in core schema: $TABLE_COUNT"
echo ""
echo "You can now create new tenant organizations."

