#!/bin/bash
# Quick update script for the server

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
    echo "Pulling latest changes..."
    git pull
    
    echo "Updating .env with Clerk variables if missing..."
    if ! grep -q "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" .env; then
        echo "" >> .env
        echo "# Clerk Integration" >> .env
        echo "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=your_clerk_publishable_key" >> .env
        echo "CLERK_SECRET_KEY=your_clerk_secret_key" >> .env
        CLERK_WEBHOOK_SEC=$(openssl rand -base64 32)
        echo "CLERK_WEBHOOK_SECRET=$CLERK_WEBHOOK_SEC" >> .env
    fi
    
    echo "Stopping services..."
    docker-compose down || docker compose down
    
    echo "Starting services..."
    docker-compose up -d || docker compose up -d
    
    echo "Waiting 10 seconds for services to start..."
    sleep 10
    
    echo "Service status:"
    docker-compose ps || docker compose ps
ENDSSH

rm -f $SSH_KEY_FILE

