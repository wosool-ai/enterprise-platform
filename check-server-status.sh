#!/bin/bash
# Direct server status check

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

echo "🔍 Checking server status..."
echo ""

ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no root@167.99.20.94 << 'ENDSSH'
    cd /root/wosool-ai
    
    echo "=== Docker Images ==="
    docker images | grep -E "wosool-ai|REPOSITORY" | head -10
    echo ""
    
    echo "=== Running Containers ==="
    docker ps -a
    echo ""
    
    echo "=== Docker Compose Status ==="
    docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null || echo "No services running"
    echo ""
    
    echo "=== Build Status ==="
    if docker images | grep -q "wosool-ai-twenty-crm"; then
        echo "✅ twenty-crm image exists"
    else
        echo "❌ twenty-crm image not found"
    fi
    
    if docker images | grep -q "wosool-ai-tenant-manager"; then
        echo "✅ tenant-manager image exists"
    else
        echo "❌ tenant-manager image not found"
    fi
    
    if docker images | grep -q "wosool-ai-salla-orchestrator"; then
        echo "✅ salla-orchestrator image exists"
    else
        echo "❌ salla-orchestrator image not found"
    fi
    echo ""
    
    echo "=== Memory Status ==="
    free -h
    echo ""
    
    echo "=== Disk Space ==="
    df -h / | tail -1
ENDSSH

rm -f $SSH_KEY_FILE

