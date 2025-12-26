#!/bin/bash
# Setup ngrok tunnel for Clerk webhook

set -e

NGROK_BIN="$HOME/ngrok"
WEBHOOK_PORT=3001  # Tenant Manager port

echo "🔧 Setting up ngrok tunnel for Clerk webhook..."
echo ""

# Check if ngrok is installed
if [ ! -f "$NGROK_BIN" ]; then
    echo "❌ ngrok not found. Installing..."
    cd ~
    curl -o ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar -xzf ngrok.tgz
    chmod +x ngrok
    rm ngrok.tgz
    echo "✅ ngrok installed"
fi

# Check if services are running
if ! docker ps | grep -q "ent-tenant-manager\|twenty-crm-test"; then
    echo "⚠️  Warning: Tenant Manager or Twenty CRM not running"
    echo "   Starting test environment..."
    cd /home/ubuntu/wosool-ai-enterprise
    docker compose -f docker-compose.test.yml up -d twenty-crm-test 2>/dev/null || echo "   Please start services first"
fi

echo ""
echo "🚀 Starting ngrok tunnel on port $WEBHOOK_PORT..."
echo ""

# Start ngrok in background
$NGROK_BIN http $WEBHOOK_PORT > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 3

# Get the public URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL. Checking logs..."
    cat /tmp/ngrok.log
    kill $NGROK_PID 2>/dev/null
    exit 1
fi

WEBHOOK_URL="${NGROK_URL}/api/clerk/webhooks"

echo "✅ ngrok tunnel established!"
echo ""
echo "📋 Webhook Configuration:"
echo "   Public URL: $NGROK_URL"
echo "   Webhook URL: $WEBHOOK_URL"
echo ""
echo "🔗 Configure this in Clerk Dashboard:"
echo "   1. Go to https://dashboard.clerk.com"
echo "   2. Navigate to Webhooks"
echo "   3. Add endpoint: $WEBHOOK_URL"
echo "   4. Subscribe to events: organization.created, user.created, etc."
echo ""
echo "💾 To save this URL, update .env:"
echo "   CLERK_WEBHOOK_URL=$WEBHOOK_URL"
echo ""
echo "⚠️  Note: This tunnel will close when you stop ngrok (Ctrl+C)"
echo "   PID: $NGROK_PID"
echo ""
echo "To stop ngrok: kill $NGROK_PID"
echo ""

# Save PID and URL to file
echo "$NGROK_PID" > /tmp/ngrok.pid
echo "$WEBHOOK_URL" > /tmp/ngrok-webhook-url.txt

echo "✅ Webhook URL saved to /tmp/ngrok-webhook-url.txt"
echo ""
echo "🌐 Access ngrok dashboard: http://localhost:4040"

