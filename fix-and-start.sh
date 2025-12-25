#!/bin/bash
# Fix docker-compose.yml and start services

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
    
    echo "🔧 Fixing docker-compose.yml..."
    
    # Restore from git if broken
    git checkout docker-compose.yml 2>/dev/null || git restore docker-compose.yml 2>/dev/null || {
        echo "⚠️  Git restore failed, checking file..."
        if ! docker compose config > /dev/null 2>&1; then
            echo "❌ docker-compose.yml is broken, pulling fresh copy..."
            git pull
        fi
    }
    
    echo ""
    echo "🔍 Checking if build is still running..."
    BUILD_PID=$(pgrep -f "docker.*build" | head -1)
    if [ -n "$BUILD_PID" ]; then
        echo "⚠️  Build process (PID: $BUILD_PID) is still running"
        echo "   Memory is at 94%, build may be slow or stuck"
        echo "   You can wait for it to finish or kill it with: kill $BUILD_PID"
    else
        echo "✅ No build process running"
    fi
    
    echo ""
    echo "📦 Starting services (will skip twenty-crm if image doesn't exist)..."
    
    # Start services - docker-compose will skip services without images
    docker compose up -d 2>&1 | head -20
    
    echo ""
    echo "⏳ Waiting 15 seconds for services to start..."
    sleep 15
    
    echo ""
    echo "📊 Service Status:"
    docker compose ps
    
    echo ""
    echo "💾 Memory Status:"
    free -h
    
    echo ""
    echo "📝 Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
ENDSSH

rm -f $SSH_KEY_FILE

