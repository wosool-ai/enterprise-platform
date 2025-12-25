#!/bin/bash
# Verify and fix nginx on server

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
    
    echo "📋 Checking current nginx config for /api/health:"
    grep -A 12 "location.*/api/health" nginx/conf.d/wosool.conf || echo "Route not found!"
    echo ""
    
    # Discard local changes and use the version from git
    echo "🔄 Resetting to git version..."
    git checkout -- nginx/conf.d/wosool.conf
    
    # Verify the route exists
    echo ""
    echo "📋 Verifying route exists:"
    grep -A 12 "location.*/api/health" nginx/conf.d/wosool.conf || echo "Route still not found!"
    echo ""
    
    # Test and reload
    echo "🔄 Testing and reloading nginx..."
    docker exec ent-nginx nginx -t
    docker exec ent-nginx nginx -s reload
    
    echo ""
    echo "⏳ Waiting 2 seconds..."
    sleep 2
    
    echo ""
    echo "✅ Testing /api/health:"
    curl -s http://localhost/api/health
    echo ""
ENDSSH

rm -f $SSH_KEY_FILE

