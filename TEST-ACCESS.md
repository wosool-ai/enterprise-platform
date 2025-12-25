# How to Access Your Test Build

## ✅ Server Status

Your custom Twenty CRM build is now running and accessible!

## 🌐 Access the Application

**URL**: http://localhost:3000

Open this in your browser to test:
- Clerk authentication integration
- Custom routing
- Frontend functionality

## 📋 Current Status

- ✅ **Database**: Running (PostgreSQL on port 5433)
- ✅ **Redis**: Running (on port 6380)
- ✅ **Twenty CRM**: Running (on port 3000)
- ⚠️ **Migration**: Needs `TWENTY_ADMIN_TOKEN` (will run after first login)

## 🔍 Check Status

```bash
# View all containers
docker compose -f docker-compose.test.yml ps

# View logs
docker compose -f docker-compose.test.yml logs -f

# Check health
curl http://localhost:3000/health
```

## 🧪 Testing Checklist

1. **Access Application**
   - Open: http://localhost:3000
   - Should redirect to Clerk sign-in

2. **Clerk Authentication**
   - Sign in with Clerk
   - Should skip sign-in form
   - Redirect to workspace creation

3. **Check Logs for Migration**
   ```bash
   docker compose -f docker-compose.test.yml logs twenty-crm-test | grep -i migration
   ```

## 🔧 Get Admin Token (for Migration)

After first login, get the admin token:

```bash
# Check logs for token
docker compose -f docker-compose.test.yml logs twenty-crm-test | grep -i "admin\|token"

# Or generate one (if command available)
docker exec -it twenty-crm-test node dist/command/command.js generate:admin-token
```

Then update `docker-compose.test.yml` with:
```yaml
TWENTY_ADMIN_TOKEN: your-token-here
```

And restart:
```bash
docker compose -f docker-compose.test.yml restart twenty-crm-test
```

## 🛑 Stop Testing

```bash
docker compose -f docker-compose.test.yml down
```

## 🧹 Clean Up

```bash
# Stop and remove containers
docker compose -f docker-compose.test.yml down

# Remove volumes (deletes database data)
docker compose -f docker-compose.test.yml down -v
```

## 📝 Notes

- Migration will run automatically once `TWENTY_ADMIN_TOKEN` is set
- The migration is idempotent (safe to run multiple times)
- Custom schema migration creates 7 custom objects and extends 3 existing ones

