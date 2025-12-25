#!/bin/bash
# Initialize twenty_tenant_template database

set -e

cd /root/wosool-ai

echo "Creating twenty_tenant_template database..."

# Wait for tenant-db to be ready
echo "Waiting for tenant-db to be ready..."
sleep 5

# Get password from .env
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    exit 1
fi

source .env
export PGPASSWORD="${POSTGRES_PASSWORD}"

# Create database if it doesn't exist
docker exec ent-tenant-db psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'twenty_tenant_template'" | grep -q 1 || \
docker exec ent-tenant-db psql -U postgres -c "CREATE DATABASE twenty_tenant_template;"

echo "✅ Database 'twenty_tenant_template' created successfully!"

# Test connection
echo "Testing connection..."
docker exec ent-tenant-db psql -U postgres -d twenty_tenant_template -c "SELECT version();" > /dev/null && \
echo "✅ Connection test successful!" || \
echo "❌ Connection test failed"

