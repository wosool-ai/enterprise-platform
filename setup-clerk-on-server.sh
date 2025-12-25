#!/bin/bash
# Setup Clerk on server - Interactive script

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

echo "🔐 Clerk Multi-Tenant Setup"
echo "============================"
echo ""
echo "This script will help you configure Clerk on the server."
echo ""
echo "You need:"
echo "  1. Clerk Publishable Key (pk_test_... or pk_live_...)"
echo "  2. Clerk Secret Key (sk_test_... or sk_live_...)"
echo "  3. Clerk Webhook Secret (whsec_...)"
echo ""
read -p "Do you have these keys ready? (y/n): " ready

if [ "$ready" != "y" ]; then
    echo ""
    echo "Please get your keys from:"
    echo "  https://dashboard.clerk.com"
    echo ""
    echo "Then run this script again."
    rm -f $SSH_KEY_FILE
    exit 0
fi

echo ""
read -p "Enter Clerk Publishable Key: " CLERK_PUBLISHABLE_KEY
read -p "Enter Clerk Secret Key: " CLERK_SECRET_KEY
read -p "Enter Clerk Webhook Secret (or press Enter to generate): " CLERK_WEBHOOK_SECRET

if [ -z "$CLERK_WEBHOOK_SECRET" ]; then
    CLERK_WEBHOOK_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo "Generated webhook secret: $CLERK_WEBHOOK_SECRET"
fi

echo ""
echo "🔄 Updating server configuration..."

ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no root@167.99.20.94 << ENDSSH
    cd /root/wosool-ai
    
    # Backup existing .env
    cp .env .env.backup.\$(date +%Y%m%d_%H%M%S)
    
    # Update or add Clerk variables
    if grep -q "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" .env; then
        # Update existing
        sed -i "s|NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=.*|NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=$CLERK_PUBLISHABLE_KEY|" .env
        sed -i "s|CLERK_SECRET_KEY=.*|CLERK_SECRET_KEY=$CLERK_SECRET_KEY|" .env
        sed -i "s|CLERK_WEBHOOK_SECRET=.*|CLERK_WEBHOOK_SECRET=$CLERK_WEBHOOK_SECRET|" .env
        sed -i "s|CLERK_WEBHOOK_URL=.*|CLERK_WEBHOOK_URL=http://167.99.20.94/api/webhooks/clerk|" .env
    else
        # Add new
        echo "" >> .env
        echo "# Clerk Integration" >> .env
        echo "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=$CLERK_PUBLISHABLE_KEY" >> .env
        echo "CLERK_SECRET_KEY=$CLERK_SECRET_KEY" >> .env
        echo "CLERK_WEBHOOK_SECRET=$CLERK_WEBHOOK_SECRET" >> .env
        echo "CLERK_WEBHOOK_URL=http://167.99.20.94/api/webhooks/clerk" >> .env
    fi
    
    echo "✅ Updated .env file"
    echo ""
    echo "Current Clerk configuration:"
    grep CLERK .env | sed 's/=.*/=***/'
    echo ""
    echo "🔄 Restarting services..."
    docker compose restart twenty-crm tenant-manager
    echo ""
    echo "⏳ Waiting 10 seconds for services to start..."
    sleep 10
    echo ""
    echo "✅ Services restarted"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Go to https://dashboard.clerk.com"
    echo "  2. Navigate to Webhooks"
    echo "  3. Add endpoint: http://167.99.20.94/api/webhooks/clerk"
    echo "  4. Select events: organization.created, user.created, user.updated"
    echo "  5. Copy the signing secret and update CLERK_WEBHOOK_SECRET if different"
    echo "  6. Test by accessing: http://167.99.20.94"
ENDSSH

rm -f $SSH_KEY_FILE

echo ""
echo "✅ Setup complete!"
echo ""
echo "Test your setup:"
echo "  1. Visit: http://167.99.20.94"
echo "  2. Sign up with a new account"
echo "  3. Create an organization"
echo "  4. Check if tenant was created in database"

