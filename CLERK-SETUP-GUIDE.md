# Clerk Multi-Tenant Setup Guide

This guide will help you set up Clerk authentication and test multi-tenant functionality.

## 📋 Prerequisites

1. A Clerk account (sign up at https://clerk.com)
2. Access to the server at `167.99.20.94`
3. The application should already have Clerk keys configured (check `.env` file)

## 🔧 Step 1: Get Your Clerk Keys

### Option A: Use Existing Test Keys (Already Configured)

The deployment script already includes test keys. Check if they're in your `.env` file:

```bash
# On the server
cd /root/wosool-ai
grep CLERK .env
```

### Option B: Create New Clerk Application

1. **Sign up/Login to Clerk**: https://dashboard.clerk.com
2. **Create a new application**:
   - Click "Create Application"
   - Name: `Wosool Enterprise Platform`
   - Choose authentication methods (Email, Google, etc.)
3. **Get your keys**:
   - Go to **API Keys** in the sidebar
   - Copy:
     - **Publishable Key** (starts with `pk_test_` or `pk_live_`)
     - **Secret Key** (starts with `sk_test_` or `sk_live_`)

## 🔧 Step 2: Configure Clerk on Server

### Update .env File

SSH into your server and update the `.env` file:

```bash
ssh root@167.99.20.94
cd /root/wosool-ai

# Edit .env file
nano .env
```

Add or update these variables:

```bash
# Clerk Integration
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_YOUR_PUBLISHABLE_KEY
CLERK_SECRET_KEY=sk_test_YOUR_SECRET_KEY
CLERK_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET
CLERK_WEBHOOK_URL=http://167.99.20.94/api/clerk/webhooks
```

**Note**: For `CLERK_WEBHOOK_SECRET`, you'll get this when setting up webhooks (Step 3).

### Restart Services

After updating `.env`, restart the services:

```bash
docker compose restart twenty-crm tenant-manager
```

## 🔧 Step 3: Set Up Clerk Webhooks

Webhooks allow Clerk to automatically create tenants when organizations are created.

### 3.1 Get Webhook Secret

1. In Clerk Dashboard, go to **Webhooks**
2. Click **Add Endpoint**
3. Enter endpoint URL: `http://167.99.20.94/api/clerk/webhooks`
   - **Note**: For production, use HTTPS with a domain
4. Select events to listen to:
   - ✅ `organization.created`
   - ✅ `user.created`
   - ✅ `user.updated`
5. Copy the **Signing Secret** (starts with `whsec_`)
6. Update your `.env` file with this secret:
   ```bash
   CLERK_WEBHOOK_SECRET=whsec_YOUR_COPIED_SECRET
   ```
7. Restart services:
   ```bash
   docker compose restart tenant-manager
   ```

### 3.2 Test Webhook (Optional)

You can test the webhook endpoint:

```bash
curl -X POST http://167.99.20.94/api/webhooks/clerk \
  -H "Content-Type: application/json" \
  -d '{"type":"test"}'
```

## 🧪 Step 4: Test Multi-Tenant Functionality

### 4.1 Access the Application

1. Open your browser: http://167.99.20.94
2. You should see the Twenty CRM login/signup page
3. Click **Sign Up** or **Sign In**

### 4.2 Create First Organization (Tenant)

1. **Sign up** with a new account:
   - Email: `admin1@example.com`
   - Password: (your choice)
2. **Create an Organization**:
   - After signing up, Clerk will prompt you to create an organization
   - Name: `Company A`
   - This will trigger the webhook and create a tenant in your system

### 4.3 Verify Tenant Creation

Check if the tenant was created:

```bash
# On the server
docker exec ent-tenant-manager node -e "
const { Pool } = require('pg');
const db = new Pool({ connectionString: process.env.GLOBAL_DATABASE_URL });
db.query('SELECT id, slug, name, clerk_org_id, status FROM tenant_registry')
  .then(r => { console.log(JSON.stringify(r.rows, null, 2)); process.exit(0); });
"
```

Or use the admin API:

```bash
curl -H "X-Admin-Key: your-admin-key" \
  http://167.99.20.94/api/admin/tenants
```

### 4.4 Create Second Organization (Second Tenant)

1. **Sign out** from the first account
2. **Sign up** with a different account:
   - Email: `admin2@example.com`
   - Password: (your choice)
3. **Create another Organization**:
   - Name: `Company B`
   - This creates a second tenant

### 4.5 Test Tenant Isolation

1. **Login as Company A admin**:
   - Sign in with `admin1@example.com`
   - You should only see Company A's data
2. **Login as Company B admin**:
   - Sign in with `admin2@example.com`
   - You should only see Company B's data
3. **Verify data isolation**:
   - Data from Company A should not be visible to Company B
   - Each organization has its own isolated database

## 🔍 Step 5: Verify Multi-Tenant Setup

### Check Tenant Registry

```bash
# List all tenants
docker exec ent-tenant-manager psql $GLOBAL_DATABASE_URL -c \
  "SELECT id, slug, name, clerk_org_id, status, plan FROM tenant_registry;"
```

### Check Database Isolation

Each tenant should have its own database:

```bash
# List all databases
docker exec ent-tenant-db psql -U postgres -c "\l" | grep twenty
```

You should see databases like:
- `twenty_tenant_template` (template)
- `twenty_tenant_<tenant-id-1>` (Company A)
- `twenty_tenant_<tenant-id-2>` (Company B)

### Test API with Tenant Context

```bash
# Get a token from Clerk (after logging in)
# Then use it to access tenant-specific endpoints

curl -H "Authorization: Bearer YOUR_CLERK_TOKEN" \
  -H "X-Tenant-Slug: company-a" \
  http://167.99.20.94/api/...
```

## 🐛 Troubleshooting

### Issue: "Unable to Reach Back-end"

**Solution**: The backend connection is fixed. If you still see this:
1. Clear browser cache
2. Hard refresh (Ctrl+Shift+R)
3. Check browser console for errors

### Issue: Clerk Authentication Not Working

**Check**:
1. Clerk keys are in `.env` file
2. Services restarted after updating `.env`
3. Clerk dashboard shows your application is active

```bash
# Verify environment variables
docker exec ent-twenty-crm env | grep CLERK
```

### Issue: Webhooks Not Creating Tenants

**Check**:
1. Webhook URL is correct in Clerk dashboard
2. Webhook secret matches in `.env`
3. Webhook endpoint is accessible:

```bash
# Test webhook endpoint
curl -X POST http://167.99.20.94/api/webhooks/clerk \
  -H "Content-Type: application/json" \
  -d '{"type":"test"}'
```

4. Check tenant-manager logs:

```bash
docker compose logs tenant-manager | grep -i clerk
```

### Issue: Can't See Organizations

**Solution**:
1. Make sure you're signed in to Clerk
2. Check if organizations are created in Clerk dashboard
3. Verify webhook created tenant in database

### Issue: Data Not Isolated

**Check**:
1. Each organization has a unique `clerk_org_id`
2. Each tenant has its own database
3. Tenant resolution is working correctly

## 📚 Additional Resources

- **Clerk Documentation**: https://clerk.com/docs
- **Clerk Dashboard**: https://dashboard.clerk.com
- **Twenty CRM Docs**: https://docs.twenty.com

## ✅ Quick Test Checklist

- [ ] Clerk keys configured in `.env`
- [ ] Services restarted
- [ ] Can access http://167.99.20.94
- [ ] Can sign up with Clerk
- [ ] Can create organization
- [ ] Tenant created in database
- [ ] Can create second organization
- [ ] Data is isolated between tenants
- [ ] Webhooks are working

## 🚀 Next Steps

1. **Set up a domain** (optional):
   - Point `api.wosool.ai` to `167.99.20.94`
   - Update `CLERK_WEBHOOK_URL` to use domain
   - Set up SSL certificate

2. **Configure production keys**:
   - Switch from `pk_test_` to `pk_live_` keys
   - Update webhook URL to production domain

3. **Set up monitoring**:
   - Monitor tenant creation
   - Set up alerts for failed webhooks
   - Track tenant usage

