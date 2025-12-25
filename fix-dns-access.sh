#!/bin/bash
# Fix DNS and access issues

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
    
    echo "🔧 Updating nginx to accept requests from IP address..."
    
    # Update nginx config to accept requests by IP or domain
    sed -i 's/server_name api.wosool.ai;/server_name api.wosool.ai 167.99.20.94 _;/' nginx/conf.d/wosool.conf
    
    # Also add a default server block for IP access
    if ! grep -q "server_name.*167.99.20.94" nginx/conf.d/wosool.conf; then
        echo "Adding IP to server_name..."
        sed -i 's/server_name api.wosool.ai;/server_name api.wosool.ai 167.99.20.94 _;/' nginx/conf.d/wosool.conf
    fi
    
    # Test config
    docker exec ent-nginx nginx -t
    
    # Reload nginx
    docker exec ent-nginx nginx -s reload || docker compose restart nginx
    
    echo ""
    echo "✅ Nginx updated"
    echo ""
    echo "🌐 Test these URLs:"
    echo "  - http://167.99.20.94"
    echo "  - http://138.197.23.213"
    echo "  - http://api.wosool.ai (if DNS is configured)"
    echo ""
    echo "📝 Current server_name:"
    grep "server_name" nginx/conf.d/wosool.conf
ENDSSH

rm -f $SSH_KEY_FILE

