# Clerk Webhook Setup with ngrok

## ✅ Current Configuration

### Clerk Keys
- **Publishable Key**: `pk_test_Zmx5aW5nLWFyYWNobmlkLTE3LmNsZXJrLmFjY291bnRzLmRldiQ`
- **Secret Key**: `sk_test_dV6XYGT3TJfoP8qyfRgvPXRj0GU62lt0yjK5ke6SKc`

### ngrok Webhook URL
**Webhook Endpoint**: `https://roupily-indefinite-lavona.ngrok-free.dev/api/clerk/webhooks`

⚠️ **Note**: This ngrok URL will change each time you restart ngrok. For production, use a fixed domain.

## 🔧 Configure in Clerk Dashboard

### Step 1: Access Clerk Dashboard
1. Go to [Clerk Dashboard](https://dashboard.clerk.com)
2. Sign in to your account
3. Select your application

### Step 2: Add Webhook Endpoint
1. Navigate to **Webhooks** in the left sidebar
2. Click **Add Endpoint**
3. Enter the webhook URL:
   ```
   https://roupily-indefinite-lavona.ngrok-free.dev/api/clerk/webhooks
   ```
4. Click **Create**

### Step 3: Subscribe to Events
Select these events (required for multi-tenant functionality):
- ✅ `organization.created` - **Critical** - Creates new tenants
- ✅ `organization.updated` - Updates tenant information
- ✅ `organization.deleted` - Handles tenant deletion
- ✅ `organizationMembership.created` - Adds users to tenants
- ✅ `organizationMembership.updated` - Updates user roles
- ✅ `organizationMembership.deleted` - Removes users from tenants
- ✅ `user.created` - Syncs new users
- ✅ `user.updated` - Updates user information
- ✅ `user.deleted` - Handles user deletion

### Step 4: Get Webhook Secret
1. After creating the endpoint, Clerk will show a **Signing Secret**
2. It starts with `whsec_`
3. Copy this secret

### Step 5: Update Environment Variables
Update your `.env` file or `docker-compose.test.yml`:

```bash
CLERK_WEBHOOK_SECRET=whsec_YOUR_SECRET_HERE
CLERK_WEBHOOK_URL=https://roupily-indefinite-lavona.ngrok-free.dev/api/clerk/webhooks
```

### Step 6: Restart Services
```bash
docker compose -f docker-compose.test.yml restart twenty-crm-test
```

## 🧪 Test the Webhook

### Test from Clerk Dashboard
1. In Clerk Dashboard → Webhooks → Your endpoint
2. Click **Send test event**
3. Select event type: `organization.created`
4. Click **Send**
5. Check logs:
   ```bash
   docker compose -f docker-compose.test.yml logs -f tenant-manager | grep -i clerk
   ```

### Test Manually
```bash
curl -X POST https://roupily-indefinite-lavona.ngrok-free.dev/api/clerk/webhooks \
  -H "Content-Type: application/json" \
  -H "svix-id: test-id" \
  -H "svix-timestamp: $(date +%s)" \
  -H "svix-signature: test" \
  -d '{"type":"test"}'
```

## 📋 ngrok Management

### Check ngrok Status
```bash
# View ngrok dashboard
curl http://localhost:4040/api/tunnels

# Or open in browser
# http://localhost:4040
```

### Restart ngrok
```bash
# Stop current ngrok
kill $(cat /tmp/ngrok.pid)

# Start new tunnel
./setup-ngrok-webhook.sh
```

### Get Current Webhook URL
```bash
cat /tmp/ngrok-webhook-url.txt
```

## ⚠️ Important Notes

1. **ngrok Free Tier Limitations**:
   - URL changes on each restart
   - Session timeout after inactivity
   - Rate limits apply

2. **For Production**:
   - Use a fixed domain (not ngrok)
   - Set up SSL/TLS certificate
   - Use production Clerk keys (`pk_live_`, `sk_live_`)
   - Configure proper firewall rules

3. **Security**:
   - Never commit webhook secrets to git
   - Use environment variables
   - Verify webhook signatures in production

## 🔍 Troubleshooting

### Webhook Not Receiving Events
1. Check ngrok is running: `ps aux | grep ngrok`
2. Verify webhook URL in Clerk Dashboard matches ngrok URL
3. Check tenant-manager logs: `docker compose logs tenant-manager`
4. Verify webhook secret matches

### ngrok Connection Issues
1. Check if port 3001 is accessible: `curl http://localhost:3001/health`
2. Verify ngrok is pointing to correct port
3. Check firewall rules

### Clerk Webhook Errors
1. Verify webhook secret in `.env` matches Clerk Dashboard
2. Check tenant-manager is running and healthy
3. Review Clerk Dashboard → Webhooks → Recent Events for errors

## 📚 Related Documentation

- [Clerk Webhooks Documentation](https://clerk.com/docs/integrations/webhooks)
- [ngrok Documentation](https://ngrok.com/docs)
- `PRODUCTION-DEPLOYMENT.md` - Full deployment guide
- `CLERK-SETUP-GUIDE.md` - Clerk setup instructions

## ✅ Current Status

- ✅ ngrok tunnel active
- ✅ Webhook URL: `https://roupily-indefinite-lavona.ngrok-free.dev/api/clerk/webhooks`
- ✅ Services running and healthy
- ✅ Clerk keys configured
- ⏳ Waiting for Clerk Dashboard configuration

