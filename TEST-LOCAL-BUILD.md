# Testing the Local Docker Build

## Quick Start

### Option 1: Test with Docker Compose (Recommended)

Create a test `docker-compose.test.yml` file:

```yaml
version: '3.8'

services:
  test-db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: twenty_test
    ports:
      - "5433:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  twenty-crm-test:
    image: wosool-ai/twenty-crm:test
    depends_on:
      test-db:
        condition: service_healthy
    environment:
      # Database
      PG_DATABASE_URL: postgresql://postgres:postgres@test-db:5432/twenty_test
      
      # Server URL
      SERVER_URL: http://localhost:3000
      REACT_APP_SERVER_BASE_URL: http://localhost:3000
      
      # Clerk (use your test keys)
      NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: pk_test_ZW1lcmdpbmctc2tpbmstNzUuY2xlcmsuYWNjb3VudHMuZGV2JA
      CLERK_SECRET_KEY: sk_test_kIRXGCc7WeA4MMaAkh6L3d17NbGRB6QkRodqsYHqrm
      CLERK_WEBHOOK_SECRET: whsec_e43dYrJxMJVz/8YBe3Lcq078Cx7CYpTm
      CLERK_WEBHOOK_URL: http://localhost:3000/api/clerk/webhooks
      
      # Migration
      TWENTY_ADMIN_TOKEN: your-admin-token-here  # Get this after first run
      
      # Optional: Disable migration if needed
      # DISABLE_CUSTOM_SCHEMA_MIGRATION: "true"
    ports:
      - "3000:3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 5
```

Run it:
```bash
cd /home/ubuntu/wosool-ai-enterprise
docker compose -f docker-compose.test.yml up -d
```

Access: http://localhost:3000

### Option 2: Test with Docker Run

```bash
# Start a test database
docker run -d \
  --name test-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=twenty_test \
  -p 5433:5432 \
  postgres:15-alpine

# Wait for database to be ready
sleep 5

# Run the custom Twenty CRM image
docker run -d \
  --name twenty-crm-test \
  --link test-postgres:postgres \
  -p 3000:3000 \
  -e PG_DATABASE_URL=postgresql://postgres:postgres@postgres:5432/twenty_test \
  -e SERVER_URL=http://localhost:3000 \
  -e REACT_APP_SERVER_BASE_URL=http://localhost:3000 \
  -e NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_ZW1lcmdpbmctc2tpbmstNzUuY2xlcmsuYWNjb3VudHMuZGV2JA \
  -e CLERK_SECRET_KEY=sk_test_kIRXGCc7WeA4MMaAkh6L3d17NbGRB6QkRodqsYHqrm \
  -e CLERK_WEBHOOK_SECRET=whsec_e43dYrJxMJVz/8YBe3Lcq078Cx7CYpTm \
  -e CLERK_WEBHOOK_URL=http://localhost:3000/api/clerk/webhooks \
  wosool-ai/twenty-crm:test
```

Access: http://localhost:3000

## Getting the Admin Token

After the container starts, you need to get the admin token for the migration:

```bash
# Check container logs
docker logs twenty-crm-test

# Look for a line like:
# "Admin token: xxxxxx"
# Or check the database for the token

# Alternative: Generate token manually
docker exec -it twenty-crm-test node dist/command/command.js generate:admin-token
```

Then update the environment variable and restart:
```bash
docker stop twenty-crm-test
docker rm twenty-crm-test
# Run again with TWENTY_ADMIN_TOKEN set
```

## Testing Checklist

### 1. Basic Functionality
- [ ] Container starts without errors
- [ ] Health endpoint responds: `curl http://localhost:3000/health`
- [ ] Frontend loads: http://localhost:3000
- [ ] Database migrations completed

### 2. Clerk Integration
- [ ] Visiting root URL redirects to Clerk sign-in
- [ ] Clerk sign-in page displays
- [ ] After sign-in, redirects to workspace creation
- [ ] Workspace creation works

### 3. Data Model Migration
- [ ] Check logs for migration success:
  ```bash
  docker logs twenty-crm-test | grep -i migration
  ```
- [ ] Verify custom objects created (check via GraphQL or UI)
- [ ] Check for errors in logs

### 4. Multi-tenant
- [ ] Create organization in Clerk
- [ ] Verify tenant created via webhook
- [ ] Access tenant-specific workspace

## Viewing Logs

```bash
# All logs
docker logs twenty-crm-test

# Follow logs
docker logs -f twenty-crm-test

# Last 50 lines
docker logs --tail 50 twenty-crm-test

# Filter for migration
docker logs twenty-crm-test | grep -i "migration\|schema\|custom"
```

## Common Issues

### Database Connection Error
```
psql: error: connection to server failed
```
**Solution**: Ensure database container is running and healthy:
```bash
docker ps | grep postgres
docker logs test-postgres
```

### Migration Fails
```
Warning: Custom schema migration failed
```
**Solution**: 
1. Check `TWENTY_ADMIN_TOKEN` is set correctly
2. Verify server is ready before migration runs
3. Check logs for specific error messages

### Clerk Not Working
```
Clerk publishable key not found
```
**Solution**: Ensure `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` is set in environment

### Port Already in Use
```
Error: bind: address already in use
```
**Solution**: Change port mapping:
```yaml
ports:
  - "3001:3000"  # Use port 3001 instead
```

## Testing with Production-like Setup

To test with a setup similar to production:

```bash
# Use the actual docker-compose.yml but with test image
cd /home/ubuntu/wosool-ai-enterprise

# Edit docker-compose.yml temporarily to use test image
# Change: image: twentycrm/twenty:latest
# To:     image: wosool-ai/twenty-crm:test

# Then run
docker compose up -d
```

## Cleanup

```bash
# Stop and remove test containers
docker compose -f docker-compose.test.yml down

# Or for docker run:
docker stop twenty-crm-test test-postgres
docker rm twenty-crm-test test-postgres

# Remove test image (optional)
docker rmi wosool-ai/twenty-crm:test
```

## Next Steps After Testing

1. ✅ Verify all functionality works
2. ⏭️  Push to Docker Hub
3. ⏭️  Update production docker-compose.yml
4. ⏭️  Deploy to production server

