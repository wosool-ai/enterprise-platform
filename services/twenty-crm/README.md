# Twenty CRM with Auto Schema Migration

This is a custom build of Twenty CRM that automatically runs schema migration on startup.

## Features

- ✅ **Automatic Schema Migration**: Runs on every container start
- ✅ **Idempotent**: Safe to run multiple times (skips existing objects)
- ✅ **Part of Docker Image**: Migration scripts are baked into the image
- ✅ **Multi-tenant Ready**: Works for all new installations

## What Gets Migrated

The migration creates:
- 7 Custom Objects (Agent Settings, Salla Products, Orders, Carts, Voice Calls, Workflow Executions, Communication Logs)
- Extended fields on 3 existing objects (Person, Opportunity, Workflow)
- 6 Relationships between objects

## Building the Image

```bash
docker build -t twenty-crm-custom:latest ./services/twenty-crm
```

Or use Docker Compose:
```bash
docker-compose build twenty-server
```

## How It Works

1. Container starts with custom entrypoint
2. Twenty CRM server starts in background
3. Entrypoint waits for server to be ready (up to 120 seconds)
4. Schema migration runs automatically
5. Server continues running normally

## Environment Variables

The migration uses these environment variables (from `.env`):
- `TWENTY_API_KEY` or `APP_SECRET`: API key for authentication
- `TWENTY_BASE_URL` or `SERVER_URL`: Base URL (defaults to `http://localhost:3000`)

## Manual Migration

If you need to run migration manually:

```bash
docker exec -it twenty-server sh
cd /app/scripts
export TWENTY_API_KEY="your-key"
export TWENTY_BASE_URL="http://localhost:3000"
npx ts-node migrate-schema.ts
```

## Troubleshooting

### Migration Fails on Startup
- This is OK! The migration is idempotent
- If objects already exist, it will skip them
- Container will still start normally

### Server Not Ready
- Migration waits up to 120 seconds for server
- If timeout, migration is skipped but server continues
- You can run migration manually later

## Files

- `Dockerfile`: Custom Dockerfile that adds migration scripts
- `scripts/migrate-schema.ts`: TypeScript migration script
- `scripts/docker-entrypoint.sh`: Custom entrypoint that runs migration
- `scripts/package.json`: Node.js dependencies for migration

