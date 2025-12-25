#!/bin/bash
# Check and fix nginx config

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
    
    echo "📋 Checking nginx config around /api/ routes..."
    echo ""
    grep -B 5 -A 15 "location.*api" nginx/conf.d/wosool.conf | head -40
    echo ""
    echo "---"
    echo ""
    
    # Direct test of tenant-manager
    echo "🧪 Testing tenant-manager directly:"
    docker exec ent-tenant-manager curl -s http://localhost:3001/health
    echo ""
    echo ""
    
    # Test through nginx internal network
    echo "🧪 Testing through nginx container:"
    docker exec ent-nginx wget -q -O- http://ent-tenant-manager:3001/health 2>&1
    echo ""
ENDSSH

rm -f $SSH_KEY_FILE

