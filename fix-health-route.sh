#!/bin/bash
# Fix health route properly

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
    
    echo "🔧 Fixing /api/health route..."
    
    # Check current config
    echo "Current /api/health location:"
    grep -A 10 "location.*/api/health" nginx/conf.d/wosool.conf || echo "Not found"
    echo ""
    
    # Remove any existing /api/health location
    sed -i '/location = \/api\/health/,/^    }$/d' nginx/conf.d/wosool.conf
    
    # Add the correct /api/health route BEFORE the general /api/ route
    # Find the line with "# Tenant Manager API - /api/*" and insert before it
    sed -i '/# Tenant Manager API - \/api\/* (except \/api\/salla\/*)/i\
    # Tenant Manager API Health - /api/health\
    location = /api/health {\
        limit_req zone=api_limit burst=20 nodelay;\
        proxy_pass http://tenant_manager/health;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
        proxy_set_header X-Forwarded-Host $host;\
        \
        proxy_http_version 1.1;\
        proxy_set_header Connection "";\
        proxy_read_timeout 60s;\
        proxy_connect_timeout 10s;\
    }\
' nginx/conf.d/wosool.conf
    
    # Test config
    echo "Testing nginx config..."
    docker exec ent-nginx nginx -t
    
    # Reload
    echo "Reloading nginx..."
    docker exec ent-nginx nginx -s reload
    
    echo ""
    echo "⏳ Waiting 2 seconds..."
    sleep 2
    
    echo ""
    echo "✅ Testing /api/health:"
    curl -s http://localhost/api/health | jq . || curl -s http://localhost/api/health
    echo ""
ENDSSH

rm -f $SSH_KEY_FILE

