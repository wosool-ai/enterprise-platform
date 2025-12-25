#!/bin/bash
# Test multi-tenant functionality

SSH_KEY='-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAVaLMQTFxgSfwsFBmn57FKC1OI+zOJBDCe2fnwX2jB1QAAAKALtgCmC7YA
pgAAAAtzc2gtZWQyNTUxOQAAACAVaLMQTFxgSfwsFBmn57FKC1OI+zOJBDCe2fnwX2jB1Q
AAAEDUmWrbTzOlw2lTTvJc74H8wnqPqzTuN+Ndxu11FPF+qRVosxBMXGBJ/CwUGafnsUoL
U4j7M4kEMJ7Z+fBfaMHVAAAAG3VidW50dUB1YnVudHUtRGVsbC1HMTYtNzYzMAEC
-----END OPENSSH PRIVATE KEY-----'

SSH_KEY_FILE=$(mktemp)
echo "$SSH_KEY" > $SSH_KEY_FILE
chmod 600 $SSH_KEY_FILE

echo "🧪 Testing Multi-Tenant Setup"
echo "=============================="
echo ""

ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no root@167.99.20.94 << 'ENDSSH'
    cd /root/wosool-ai
    
    echo "1️⃣ Checking Clerk Configuration..."
    echo ""
    if grep -q "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" .env; then
        echo "✅ Clerk keys found in .env"
        grep CLERK .env | sed 's/=.*/=***/' | head -4
    else
        echo "❌ Clerk keys not found in .env"
        echo "   Run setup-clerk-on-server.sh first"
    fi
    echo ""
    
    echo "2️⃣ Checking Services Status..."
    echo ""
    docker compose ps twenty-crm tenant-manager | grep -E "NAME|twenty-crm|tenant-manager"
    echo ""
    
    echo "3️⃣ Checking Tenant Registry..."
    echo ""
    docker exec ent-tenant-manager psql "$GLOBAL_DATABASE_URL" -c \
        "SELECT id, slug, name, clerk_org_id, status, plan, created_at 
         FROM tenant_registry 
         ORDER BY created_at DESC 
         LIMIT 5;" 2>/dev/null || echo "⚠️  Could not query tenant registry"
    echo ""
    
    echo "4️⃣ Checking Tenant Databases..."
    echo ""
    docker exec ent-tenant-db psql -U postgres -c \
        "\l" | grep -E "Name|twenty" | head -10 || echo "⚠️  Could not list databases"
    echo ""
    
    echo "5️⃣ Testing Webhook Endpoint..."
    echo ""
    WEBHOOK_TEST=$(curl -s -X POST http://localhost/api/webhooks/clerk \
        -H "Content-Type: application/json" \
        -d '{"type":"test"}' 2>&1)
    if echo "$WEBHOOK_TEST" | grep -q "error\|Error\|404"; then
        echo "⚠️  Webhook endpoint may not be working"
        echo "   Response: $WEBHOOK_TEST"
    else
        echo "✅ Webhook endpoint is accessible"
    fi
    echo ""
    
    echo "6️⃣ Checking Recent Logs for Clerk Activity..."
    echo ""
    docker compose logs --tail=20 tenant-manager | grep -i clerk | tail -5 || echo "No recent Clerk activity"
    echo ""
    
    echo "📋 Summary:"
    echo "  - Access the app at: http://167.99.20.94"
    echo "  - Sign up to create your first tenant"
    echo "  - Create an organization in Clerk to trigger tenant provisioning"
    echo ""
    echo "To view all tenants:"
    echo "  docker exec ent-tenant-manager psql \$GLOBAL_DATABASE_URL -c 'SELECT * FROM tenant_registry;'"
ENDSSH

rm -f $SSH_KEY_FILE

