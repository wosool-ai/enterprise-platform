# How to Use Clerk Integration - Step by Step Guide

Clerk is already integrated and configured! This guide shows you how to use it.

## ✅ Current Status

- ✅ Clerk credentials configured
- ✅ Webhook endpoint ready: `http://167.99.20.94/api/clerk/webhooks`
- ✅ Services running with Clerk integration
- ✅ Application accessible at: http://167.99.20.94

## 🚀 Step-by-Step: Using Clerk Multi-Tenant

### Step 1: Configure Webhook in Clerk Dashboard

**This is required for automatic tenant creation!**

1. **Go to Clerk Dashboard**: https://dashboard.clerk.com
2. **Navigate to**: Webhooks → Add Endpoint
3. **Configure**:
   - **Endpoint URL**: `http://167.99.20.94/api/clerk/webhooks`
   - **Signing Secret**: `whsec_e43dYrJxMJVz/8YBe3Lcq078Cx7CYpTm`
   - **Events to listen to**:
     - ✅ `organization.created` (creates tenant automatically)
     - ✅ `user.created` (syncs users)
     - ✅ `user.updated` (updates user info)
     - ✅ `organizationMembership.created` (links users to tenants)
4. **Save** the webhook

### Step 2: Access the Application

1. **Open your browser**: http://167.99.20.94
2. You'll be redirected to `/welcome` (sign-in page)
3. You should see **"Sign in or Create an account"**

### Step 3: Create Your First Account (First Tenant)

1. **Click "Create an account"** or **"Sign up"**
2. **Enter your details**:
   - Email: `admin1@example.com` (or your email)
   - Password: (choose a secure password)
   - Or use social login if configured (Google, etc.)
3. **Verify your email** (if email verification is enabled)
4. **Complete sign-up**

### Step 4: Create Your First Organization (Tenant)

After signing up, you'll be in the application. To create a tenant:

1. **Create an Organization in Clerk**:
   - Look for an "Organization" or "Workspace" option in the UI
   - Or go to Clerk Dashboard → Organizations → Create Organization
   - Name: `Company A` (or your company name)
   - This triggers the `organization.created` webhook
   - **The webhook automatically creates a tenant in your system!**

2. **Verify Tenant Creation**:
   ```bash
   ssh root@167.99.20.94
   docker exec ent-tenant-manager psql $GLOBAL_DATABASE_URL -c \
     "SELECT id, slug, name, clerk_org_id, status, created_at FROM tenant_registry ORDER BY created_at DESC;"
   ```
   You should see your new tenant with the organization name and `clerk_org_id`.

### Step 5: Create Second Tenant (Test Multi-Tenancy)

1. **Sign out** from the first account
2. **Sign up with a different account**:
   - Email: `admin2@example.com`
   - Password: (different password)
3. **Create another organization**:
   - Name: `Company B`
   - This creates a second isolated tenant

### Step 6: Test Tenant Isolation

1. **Login as Company A admin**:
   - Sign in with `admin1@example.com`
   - You should only see Company A's data
   - Each tenant has its own isolated database

2. **Login as Company B admin**:
   - Sign in with `admin2@example.com`
   - You should only see Company B's data
   - Data is completely isolated

## 🔍 Verification Commands

### Check All Tenants

```bash
ssh root@167.99.20.94
cd /root/wosool-ai

# List all tenants
docker exec ent-tenant-manager psql $GLOBAL_DATABASE_URL -c \
  "SELECT id, slug, name, clerk_org_id, status, plan, created_at FROM tenant_registry ORDER BY created_at DESC;"
```

### Check Tenant Databases

```bash
# List all tenant databases
docker exec ent-tenant-db psql -U postgres -c "\l" | grep twenty
```

You should see:
- `twenty_tenant_template` (template database)
- `twenty_tenant_<tenant-id-1>` (Company A)
- `twenty_tenant_<tenant-id-2>` (Company B)

### Check Webhook Logs

```bash
# Check if webhooks are being received
docker compose logs tenant-manager | grep -i "clerk\|webhook\|organization"
```

### Check Clerk Dashboard

1. Go to https://dashboard.clerk.com
2. **Users**: See all registered users
3. **Organizations**: See all organizations (each = one tenant)
4. **Webhooks**: Check webhook delivery status

## 🎯 How It Works

### Automatic Tenant Provisioning Flow

1. **User signs up** → Clerk creates user
2. **User creates organization** → Clerk sends `organization.created` webhook
3. **Webhook received** → Tenant Manager creates:
   - New tenant record in `tenant_registry`
   - New isolated database (`twenty_tenant_<id>`)
   - Links `clerk_org_id` to tenant
4. **User accesses app** → System resolves tenant from Clerk org ID
5. **Data isolation** → Each tenant uses its own database

### Authentication Flow

1. **User visits** → http://167.99.20.94
2. **Redirected to** → `/welcome` (sign-in page)
3. **Signs in with Clerk** → Clerk authenticates
4. **Clerk provides JWT** → Contains `org_id` (organization ID)
5. **System resolves tenant** → From `clerk_org_id` in database
6. **User accesses tenant data** → Isolated database connection

## 🐛 Troubleshooting

### Issue: Organizations not creating tenants

**Check**:
1. Webhook is configured in Clerk Dashboard
2. Webhook URL is correct: `http://167.99.20.94/api/clerk/webhooks`
3. Webhook secret matches: `whsec_e43dYrJxMJVz/8YBe3Lcq078Cx7CYpTm`
4. Webhook events include `organization.created`

**Test webhook**:
```bash
# Test webhook endpoint
curl -X POST http://167.99.20.94/api/clerk/webhooks \
  -H "Content-Type: application/json" \
  -d '{"type":"test"}'
```

**Check logs**:
```bash
docker compose logs tenant-manager | grep -i clerk
```

### Issue: Can't sign up

**Check**:
1. Clerk application is active in dashboard
2. Sign-up is enabled in Clerk settings
3. Email verification settings (if enabled)

**Clerk Dashboard**:
- Go to: https://dashboard.clerk.com
- Check: User & Authentication → Email, Phone, Username
- Ensure sign-up is enabled

### Issue: Users can't access their tenant

**Check**:
1. Organization exists in Clerk
2. User is member of organization
3. Tenant was created (check `tenant_registry` table)
4. `clerk_org_id` matches in both Clerk and database

**Verify**:
```bash
# Check tenant registry
docker exec ent-tenant-manager psql $GLOBAL_DATABASE_URL -c \
  "SELECT name, clerk_org_id, status FROM tenant_registry;"
```

Compare `clerk_org_id` with organization ID in Clerk Dashboard.

## 📋 Quick Reference

### Clerk Dashboard URLs

- **Dashboard**: https://dashboard.clerk.com
- **API Keys**: https://dashboard.clerk.com/apps → Your App → API Keys
- **Webhooks**: https://dashboard.clerk.com/apps → Your App → Webhooks
- **Organizations**: https://dashboard.clerk.com/apps → Your App → Organizations
- **Users**: https://dashboard.clerk.com/apps → Your App → Users

### Current Configuration

- **Publishable Key**: `pk_test_ZW1lcmdpbmctc2tpbmstNzUuY2xlcmsuYWNjb3VudHMuZGV2JA`
- **Secret Key**: `sk_test_kIRXGCc7WeA4MMaAkh6L3d17NbGRB6QkRodqsYHqrm`
- **Webhook Secret**: `whsec_e43dYrJxMJVz/8YBe3Lcq078Cx7CYpTm`
- **Webhook URL**: `http://167.99.20.94/api/clerk/webhooks`
- **Application URL**: `http://167.99.20.94`

## ✅ Checklist

- [ ] Webhook configured in Clerk Dashboard
- [ ] Webhook URL: `http://167.99.20.94/api/clerk/webhooks`
- [ ] Webhook secret matches
- [ ] Events selected: `organization.created`, `user.created`, `user.updated`
- [ ] Can access: http://167.99.20.94
- [ ] Can see sign-in page
- [ ] Can sign up with new account
- [ ] Can create organization
- [ ] Tenant appears in database
- [ ] Can create second tenant
- [ ] Data is isolated between tenants

## 🎉 You're Ready!

Once you configure the webhook in Clerk Dashboard, the multi-tenant system will work automatically:

1. **User signs up** → Clerk handles authentication
2. **User creates org** → Webhook triggers → Tenant created automatically
3. **User accesses app** → System routes to correct tenant database
4. **Complete isolation** → Each tenant has separate data

The integration is complete - you just need to configure the webhook in Clerk Dashboard to enable automatic tenant provisioning!

