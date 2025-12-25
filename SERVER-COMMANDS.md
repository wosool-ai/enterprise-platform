# Server Update Commands

Run these commands directly on the server (167.99.20.94) to fix the deployment:

```bash
# 1. Navigate to the project directory
cd /root/wosool-ai

# 2. Pull the latest changes from GitHub
git pull

# 3. Update .env file with Clerk variables if missing
if ! grep -q "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" .env; then
    echo "" >> .env
    echo "# Clerk Integration" >> .env
    echo "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=your_clerk_publishable_key" >> .env
    echo "CLERK_SECRET_KEY=your_clerk_secret_key" >> .env
    CLERK_WEBHOOK_SEC=$(openssl rand -base64 32)
    echo "CLERK_WEBHOOK_SECRET=$CLERK_WEBHOOK_SEC" >> .env
fi

# 4. Stop all services
docker-compose down

# 5. Start all services
docker-compose up -d

# 6. Check service status
docker-compose ps

# 7. View logs if needed
docker-compose logs -f
```

## What was fixed:

1. **Commented out twenty-crm service** - This was trying to build from `/root/twenty` which doesn't exist
2. **Removed nginx dependency on twenty-crm** - Nginx now only depends on tenant-manager
3. **Added Clerk environment variables** - Added to .env generation in deploy-server.sh
4. **Fixed sed command syntax** - Changed delimiter from `|` to `#` to avoid conflicts

## Expected services after fix:

- ✅ ent-tenant-db (PostgreSQL)
- ✅ ent-global-db (PostgreSQL)
- ✅ ent-redis (Redis)
- ✅ ent-tenant-manager (Node.js service)
- ✅ ent-salla-orchestrator (Python FastAPI)
- ✅ ent-nginx (Nginx reverse proxy)
- ✅ ent-prometheus (Monitoring)
- ✅ ent-grafana (Dashboards)
- ✅ ent-pgadmin (Database management)
- ✅ ent-redis-commander (Redis management)

