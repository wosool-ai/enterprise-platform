#!/bin/bash
# Resolve nginx config conflict

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
    
    echo "🔧 Resolving nginx config conflict..."
    
    # Resolve conflict by using the version from git
    git checkout --theirs nginx/conf.d/wosool.conf
    git add nginx/conf.d/wosool.conf
    
    # Now add the /api/health route
    # Find line with "# Tenant Manager API - /api/*" and add health route before it
    sed -i '/# Tenant Manager API - \/api\/* (except \/api\/salla\/*)/i\    # Tenant Manager API Health - /api/health\n    location = /api/health {\n        limit_req zone=api_limit burst=20 nodelay;\n        proxy_pass http://tenant_manager/health;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n        proxy_set_header X-Forwarded-Host $host;\n        \n        proxy_http_version 1.1;\n        proxy_set_header Connection "";\n        proxy_read_timeout 60s;\n        proxy_connect_timeout 10s;\n    }\n' nginx/conf.d/wosool.conf
    
    # Test config
    docker exec ent-nginx nginx -t
    
    # Reload
    docker exec ent-nginx nginx -s reload || docker compose restart nginx
    
    echo ""
    echo "✅ Testing endpoints:"
    sleep 2
    echo "API Health:"
    curl -s http://localhost/api/health
    echo ""
    echo ""
    echo "Root:"
    curl -I http://localhost/ 2>&1 | head -3
ENDSSH

rm -f $SSH_KEY_FILE

