# Access Instructions

## ✅ Server Status

All services are running successfully on **167.99.20.94** (138.197.23.213).

## 🌐 How to Access

### Option 1: Direct IP Access (Works Now)
- **Main Application**: http://167.99.20.94
- **API**: http://167.99.20.94/api
- **Health Check**: http://167.99.20.94/health
- **Grafana**: http://167.99.20.94:3002 (admin/admin)
- **Prometheus**: http://167.99.20.94:9092

### Option 2: Domain Access (Requires DNS Setup)
If you want to use `api.wosool.ai`, you need to:

1. **Point DNS to the server**:
   - Add an A record: `api.wosool.ai` → `167.99.20.94`
   - Or use CNAME: `api.wosool.ai` → `167.99.20.94`

2. **Wait for DNS propagation** (5-30 minutes)

3. **Then access**: http://api.wosool.ai

## 🔍 Troubleshooting Connection Issues

### If you get "ERR_CONNECTION_REFUSED":

1. **Check if you're using the correct URL**:
   - ✅ Use: `http://167.99.20.94`
   - ❌ Don't use: `https://` (SSL not configured yet)
   - ❌ Don't use: `api.wosool.ai` (unless DNS is configured)

2. **Check DNS** (if using domain):
   ```bash
   nslookup api.wosool.ai
   # Should return: 167.99.20.94
   ```

3. **Test from server**:
   ```bash
   curl -I http://167.99.20.94
   # Should return: HTTP/1.1 200 OK
   ```

## 📊 Service Endpoints

- **Tenant Manager API**: http://167.99.20.94/api
- **Twenty CRM**: http://167.99.20.94 (frontend)
- **GraphQL**: http://167.99.20.94/graphql
- **REST API**: http://167.99.20.94/rest
- **Salla Webhooks**: http://167.99.20.94/api/salla/webhooks

## 🔐 Default Credentials

- **Grafana**: admin / admin
- **PgAdmin**: admin@example.com / admin
- **Redis Commander**: No authentication required

## ✅ Verification

All services are healthy:
- ✅ ent-tenant-db (PostgreSQL)
- ✅ ent-global-db (PostgreSQL)
- ✅ ent-redis (Cache)
- ✅ ent-tenant-manager (API)
- ✅ ent-twenty-crm (CRM)
- ✅ ent-salla-orchestrator (Salla Integration)
- ✅ ent-nginx (Reverse Proxy)
- ✅ ent-prometheus (Monitoring)
- ✅ ent-grafana (Dashboards)
- ✅ ent-pgadmin (Database Management)
- ✅ ent-redis-commander (Redis Management)

