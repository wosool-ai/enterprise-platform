#!/bin/bash
# Start available services and check twenty-crm build

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

ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no root@167.99.20.94 << 'ENDSSH'
    cd /root/wosool-ai
    
    echo "🔍 Checking build status..."
    
    # Check if build process is running
    if pgrep -f "docker.*build" > /dev/null; then
        echo "⚠️  Build process is still running"
    else
        echo "✅ No build process running"
    fi
    
    echo ""
    echo "📦 Starting available services (without twenty-crm)..."
    
    # Comment out twenty-crm temporarily in docker-compose.yml
    if ! grep -q "# twenty-crm:" docker-compose.yml; then
        echo "Temporarily disabling twenty-crm service..."
        sed -i 's/^  twenty-crm:/  # twenty-crm:/' docker-compose.yml
        sed -i 's/^      - twenty-crm$/      # - twenty-crm/' docker-compose.yml
    fi
    
    # Start services
    docker compose up -d
    
    echo ""
    echo "⏳ Waiting 10 seconds..."
    sleep 10
    
    echo ""
    echo "📊 Service Status:"
    docker compose ps
    
    echo ""
    echo "💾 Memory Status:"
    free -h
    
    echo ""
    echo "📝 Recent logs:"
    docker compose logs --tail=20 2>/dev/null || echo "No logs yet"
ENDSSH

rm -f $SSH_KEY_FILE

