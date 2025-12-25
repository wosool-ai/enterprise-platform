#!/bin/bash
# Fix backend URL configuration

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
    
    echo "🔄 Pulling latest changes..."
    git stash
    git pull
    git stash pop || true
    
    echo ""
    echo "🔄 Restarting twenty-crm service with new environment variables..."
    docker compose stop twenty-crm
    docker compose up -d twenty-crm
    
    echo ""
    echo "⏳ Waiting 10 seconds for service to start..."
    sleep 10
    
    echo ""
    echo "✅ Checking service status:"
    docker compose ps twenty-crm
    
    echo ""
    echo "✅ Checking logs:"
    docker compose logs --tail=20 twenty-crm
ENDSSH

rm -f $SSH_KEY_FILE

