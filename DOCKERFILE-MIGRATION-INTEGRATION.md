# Dockerfile & Entrypoint Migration Integration

## Changes Made

### 1. Dockerfile Updates (`packages/twenty-docker/twenty/Dockerfile`)

#### Added Migration Script Dependencies Installation
- Installs dependencies for the migration script during the build stage
- Location: After copying twenty-server source, before building

```dockerfile
# Install migration script dependencies
RUN cd /app/packages/twenty-server/scripts && yarn install --production
```

#### Added Migration Script Copy
- Copies the migration script and package.json to the final image
- Location: After copying built applications

```dockerfile
# Copy migration script and dependencies
COPY --chown=1000 ./packages/twenty-server/scripts /app/packages/twenty-server/scripts
```

### 2. Entrypoint Script Updates (`packages/twenty-docker/twenty/entrypoint.sh`)

#### Added Custom Schema Migration Function
- `run_custom_schema_migration()` function that:
  1. Checks if migration is disabled via `DISABLE_CUSTOM_SCHEMA_MIGRATION` env var
  2. Waits for server to be ready (checks `/health` endpoint)
  3. Runs the migration script using `tsx`
  4. Handles errors gracefully (warnings, not failures)

#### Modified Startup Flow
The entrypoint now:
1. Runs database setup and migrations (existing)
2. Registers background jobs (existing)
3. **NEW**: If custom migration is enabled:
   - Starts server in background
   - Waits for server to be ready
   - Runs custom schema migration
   - Stops background server
4. Starts server normally via `exec "$@"`

## Environment Variables

### Required for Migration
- `TWENTY_ADMIN_TOKEN` or `APP_SECRET`: API token for authentication
- `TWENTY_BASE_URL` or `SERVER_URL` or `REACT_APP_SERVER_BASE_URL`: Server URL (defaults to `http://localhost:3000`)

### Optional
- `DISABLE_CUSTOM_SCHEMA_MIGRATION=true`: Disable custom schema migration

## Migration Script Location

- **Source**: `packages/twenty-server/scripts/migrate-schema.ts`
- **Destination in Image**: `/app/packages/twenty-server/scripts/migrate-schema.ts`
- **Dependencies**: Installed in build stage, available at runtime

## How It Works

1. **Build Time**:
   - Migration script dependencies are installed
   - Migration script is copied to the image

2. **Runtime**:
   - Entrypoint runs standard database migrations
   - If custom migration enabled:
     - Starts server in background
     - Waits up to 120 seconds for server to be ready
     - Runs migration script
     - Stops background server
   - Starts server normally

## Benefits

1. **Automatic**: Migration runs automatically on container startup
2. **Idempotent**: Safe to run multiple times (skips existing objects)
3. **Non-blocking**: If migration fails, server still starts
4. **Configurable**: Can be disabled via environment variable
5. **Production-ready**: Handles errors gracefully

## Testing

To test the migration:

```bash
# Build the image
docker build -f packages/twenty-docker/twenty/Dockerfile -t twenty-crm-custom:latest .

# Run with migration enabled (default)
docker run -e TWENTY_ADMIN_TOKEN=your-token -e SERVER_URL=http://localhost:3000 twenty-crm-custom:latest

# Run with migration disabled
docker run -e DISABLE_CUSTOM_SCHEMA_MIGRATION=true twenty-crm-custom:latest
```

## Troubleshooting

### Migration Script Not Found
- Ensure the script is copied in Dockerfile
- Check file permissions (should be 1000:1000)

### Server Not Ready
- Check server logs for startup errors
- Increase wait time if needed (modify `max_attempts` in entrypoint.sh)
- Verify health endpoint is accessible

### Migration Fails
- Check `TWENTY_ADMIN_TOKEN` is set correctly
- Verify `SERVER_URL` points to correct server
- Check server logs for authentication errors
- Migration script logs errors but doesn't stop server startup

