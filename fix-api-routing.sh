#!/bin/bash
# Fix API routing properly

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
    
    echo "🔧 Fixing API routing..."
    
    # Stash local changes and pull
    git stash
    git pull
    git stash pop || true
    
    # Add specific route for /api/health before the general /api/ route
    if ! grep -q "location = /api/health" nginx/conf.d/wosool.conf; then
        echo "Adding /api/health route..."
        # Find the /api/ location block and add /api/health before it
        sed -i '/# Tenant Manager API - \/api\//i\    # Tenant Manager API Health - /api/health\n    location = /api/health {\n        limit_req zone=api_limit burst=20 nodelay;\n        proxy_pass http://tenant_manager/health;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n        proxy_set_header X-Forwarded-Host $host;\n        \n        proxy_http_version 1.1;\n        proxy_set_header Connection "";\n        proxy_read_timeout 60s;\n        proxy_connect_timeout 10s;\n    }\n' nginx/conf.d/wosool.conf
    fi
    
    # Test and reload
    docker exec ent-nginx nginx -t
    docker exec ent-nginx nginx -s reload
    
    echo ""
    echo "✅ Testing /api/health:"
    sleep 2
    curl -s http://localhost/api/health
    echo ""
ENDSSH

rm -f $SSH_KEY_FILE

