#!/bin/bash
# Switch to pre-built image and start services

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
    
    echo "🔄 Switching to pre-built Docker image..."
    echo ""
    
    # Kill any running build process
    BUILD_PID=$(pgrep -f "docker.*build" | head -1)
    if [ -n "$BUILD_PID" ]; then
        echo "Stopping build process (PID: $BUILD_PID)..."
        kill $BUILD_PID 2>/dev/null || true
        sleep 2
    fi
    
    # Pull latest changes
    echo "Pulling latest configuration..."
    git pull
    
    # Pull the pre-built image
    echo "Pulling twentycrm/twenty:latest image..."
    docker pull twentycrm/twenty:latest
    
    # Clean up to free memory
    echo "Cleaning up Docker..."
    docker system prune -f
    
    # Start all services
    echo ""
    echo "Starting all services..."
    docker compose up -d
    
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
    echo "✅ Done! Services should be running now."
ENDSSH

rm -f $SSH_KEY_FILE

