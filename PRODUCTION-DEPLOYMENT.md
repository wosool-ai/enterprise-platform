# Production Deployment Guide

## Overview

This guide covers deploying the Wosool AI Enterprise Platform to production with all services healthy, Salla integration configured, and the custom data model properly migrated.

## Prerequisites

1. **Docker & Docker Compose** installed on production server
2. **Docker Hub account** (wosool-ai organization)
3. **Salla Partner credentials** (Client ID and Secret)
4. **Clerk credentials** (will be added during deployment)
5. **Domain name** configured (optional but recommended)

## Step 1: Build Production Docker Image

### Option A: Build Locally and Push

```bash
# Set production server URL
export SERVER_URL="https://api.wosool.ai"

# Build production image
./build-production.sh

# The script will prompt to push to Docker Hub
# Or push manually:
docker push wosool-ai/twenty-crm:production
```

### Option B: Build on Server

```bash
# On production server
cd /root/wosool-ai-enterprise
./build-production.sh
```

## Step 2: Configure Environment Variables

### Create/Update `.env` File

```bash
# Database Configuration
POSTGRES_ADMIN_USER=postgres
POSTGRES_PASSWORD=<generate-strong-password>
POSTGRES_PASSWORD_ENCRYPTED=<same-as-above>

# JWT & Security (Generate strong random values)
JWT_SECRET=<generate-random-64-chars>
APP_SECRET=<generate-random-64-chars>
SUPER_ADMIN_KEY=<generate-random-64-chars>

# Application URLs
APP_URL=https://api.wosool.ai
CRM_BASE_URL=https://api.wosool.ai
SERVER_URL=https://api.wosool.ai

# Salla Integration (REQUIRED)
SALLA_CLIENT_ID=your_salla_client_id
SALLA_CLIENT_SECRET=your_salla_client_secret
SALLA_REDIRECT_URI=https://api.wosool.ai/salla/callback
SALLA_WEBHOOK_SECRET=<generate-random-64-chars>

# Clerk Authentication (Add during deployment)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...
CLERK_SECRET_KEY=sk_live_...
CLERK_WEBHOOK_SECRET=whsec_...
CLERK_WEBHOOK_URL=https://api.wosool.ai/api/webhooks/clerk

# Twenty CRM Admin Token (for data model migration)
TWENTY_ADMIN_TOKEN=<get-from-first-admin-user>

# Migration Control
DISABLE_DB_MIGRATIONS=false
DISABLE_CRON_JOBS_REGISTRATION=false
DISABLE_CUSTOM_SCHEMA_MIGRATION=false

# Node.js Configuration
NODE_ENV=production

# Grafana
GRAFANA_ADMIN_PASSWORD=<strong-password>

# PgAdmin
PGADMIN_EMAIL=admin@wosool.ai
PGADMIN_PASSWORD=<strong-password>
```

### Generate Secure Secrets

```bash
# Generate random passwords
openssl rand -base64 32 | tr -d "=+/" | cut -c1-25  # For POSTGRES_PASSWORD
openssl rand -base64 64  # For JWT_SECRET, APP_SECRET, SUPER_ADMIN_KEY
openssl rand -base64 32  # For SALLA_WEBHOOK_SECRET
```

## Step 3: Deploy Services

### Using Deployment Script

```bash
cd /root/wosool-ai-enterprise
chmod +x deploy-server.sh
./deploy-server.sh
```

### Manual Deployment

```bash
# Pull latest code
git pull origin main

# Start all services
docker compose up -d

# Check service health
docker compose ps

# View logs
docker compose logs -f
```

## Step 4: Verify All Services

### Check Service Health

```bash
# Check all services are running
docker compose ps

# Expected output: All services should show "healthy" or "running"
```

### Verify Service Endpoints

```bash
# Tenant Manager
curl http://localhost:3001/health

# Twenty CRM
curl http://localhost:3000/health

# Salla Orchestrator
curl http://localhost:8000/health

# Nginx
curl http://localhost/health
```

## Step 5: Configure Salla Integration

### 1. Get Salla Partner Credentials

1. Log in to [Salla Partner Portal](https://s.salla.sa/partners)
2. Create or select your app
3. Copy **Client ID** and **Client Secret**
4. Update `.env` file with these values

### 2. Configure Salla App Settings

In Salla Partner Portal:
- **Redirect URI**: `https://api.wosool.ai/salla/callback`
- **Webhook URL**: `https://api.wosool.ai/api/salla/webhooks`
- **Scopes**: Configure minimal scopes as per `SALLA_SCOPES.md`

### 3. Restart Salla Orchestrator

```bash
docker compose restart salla-orchestrator
docker compose logs -f salla-orchestrator
```

## Step 6: Verify Data Model Migration

### Check Migration Status

```bash
# Check Twenty CRM logs for migration
docker compose logs twenty-crm | grep -i "migration\|schema"

# Expected output should show:
# ✅ Successfully ran custom schema migration!
```

### Verify Custom Objects

1. Access Twenty CRM: `https://api.wosool.ai`
2. Navigate to Settings → Objects
3. Verify these custom objects exist:
   - Agent Settings
   - Salla Products
   - Salla Orders
   - Salla Carts
   - Voice Calls
   - Workflow Executions
   - Communication Logs

## Step 7: Configure Clerk (During Deployment)

### 1. Create Clerk Application

1. Go to [Clerk Dashboard](https://dashboard.clerk.com)
2. Create new application
3. Copy **Publishable Key** and **Secret Key**

### 2. Update Environment Variables

```bash
# Edit .env file
nano .env

# Update Clerk variables:
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...
CLERK_SECRET_KEY=sk_live_...
CLERK_WEBHOOK_SECRET=whsec_...
CLERK_WEBHOOK_URL=https://api.wosool.ai/api/webhooks/clerk
```

### 3. Configure Clerk Webhooks

1. In Clerk Dashboard → Webhooks
2. Add endpoint: `https://api.wosool.ai/api/webhooks/clerk`
3. Subscribe to events:
   - `organization.created`
   - `organization.updated`
   - `user.created`
   - `user.updated`
4. Copy **Signing Secret** → Update `CLERK_WEBHOOK_SECRET` in `.env`

### 4. Restart Services

```bash
docker compose restart tenant-manager twenty-crm
```

## Step 8: Get Admin Token for Migration

### First-Time Setup

1. Access Twenty CRM: `https://api.wosool.ai`
2. Sign up with first admin user
3. Go to Settings → API Keys
4. Create new API key
5. Copy the token
6. Update `.env`:
   ```bash
   TWENTY_ADMIN_TOKEN=<your-api-key>
   ```
7. Restart Twenty CRM to run migration:
   ```bash
   docker compose restart twenty-crm
   ```

## Troubleshooting

### Services Not Healthy

```bash
# Check logs
docker compose logs <service-name>

# Restart specific service
docker compose restart <service-name>

# Rebuild service
docker compose up -d --build <service-name>
```

### Data Model Migration Failed

1. Check logs: `docker compose logs twenty-crm | grep migration`
2. Verify `TWENTY_ADMIN_TOKEN` is set correctly
3. Ensure server is accessible: `curl http://localhost:3000/health`
4. Check database connection: `docker compose exec tenant-db psql -U postgres -d twenty_tenant_template -c "\dt"`

### Salla Integration Not Working

1. Verify credentials in `.env`
2. Check Salla Orchestrator logs: `docker compose logs salla-orchestrator`
3. Verify redirect URI matches Salla Partner Portal
4. Test OAuth flow: Visit `https://api.wosool.ai/api/salla/install`

### Clerk Authentication Issues

1. Verify keys in `.env`
2. Check webhook endpoint is accessible
3. Verify webhook secret matches Clerk Dashboard
4. Check tenant-manager logs: `docker compose logs tenant-manager | grep clerk`

## Production Checklist

- [ ] All services healthy and running
- [ ] Database migrations completed
- [ ] Custom data model migrated
- [ ] Salla credentials configured
- [ ] Salla OAuth flow tested
- [ ] Clerk credentials configured
- [ ] Clerk webhooks configured and tested
- [ ] Admin token generated and set
- [ ] SSL/TLS certificates configured
- [ ] Firewall rules configured
- [ ] Monitoring (Grafana/Prometheus) accessible
- [ ] Backup strategy in place
- [ ] Log rotation configured

## Service URLs

- **Main Application**: `https://api.wosool.ai`
- **API**: `https://api.wosool.ai/api`
- **Grafana**: `https://api.wosool.ai:3002`
- **PgAdmin**: `https://api.wosool.ai/pgadmin`
- **Prometheus**: `https://api.wosool.ai/prometheus`

## Support

For issues or questions:
1. Check service logs: `docker compose logs -f <service>`
2. Review documentation in project root
3. Check GitHub issues: https://github.com/wosool-ai/enterprise-platform

