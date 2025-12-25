#!/bin/bash
# Final nginx fix and verification

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
    
    echo "🔧 Verifying nginx configuration..."
    
    # Check if config file has the fix
    if grep -q "ent-ent-twenty-crm" nginx/conf.d/wosool.conf; then
        echo "⚠️  Config still has old names, fixing..."
        sed -i 's/ent-ent-twenty-crm/ent-twenty-crm/g' nginx/conf.d/wosool.conf
        sed -i 's/ent-ent-tenant-manager/ent-tenant-manager/g' nginx/conf.d/wosool.conf
        sed -i 's/ent-ent-salla-orchestrator/ent-salla-orchestrator/g' nginx/conf.d/wosool.conf
        echo "✅ Config fixed"
    else
        echo "✅ Config looks good"
    fi
    
    # Test nginx config
    echo ""
    echo "Testing nginx configuration..."
    docker exec ent-nginx nginx -t 2>&1
    
    # Restart nginx
    echo ""
    echo "🔄 Restarting nginx..."
    docker compose restart nginx
    
    echo ""
    echo "⏳ Waiting 5 seconds..."
    sleep 5
    
    # Test connection
    echo ""
    echo "🌐 Testing connections..."
    echo "Local (127.0.0.1):"
    curl -I http://127.0.0.1 2>&1 | head -3
    echo ""
    echo "External IP (138.197.23.213):"
    curl -I http://138.197.23.213 2>&1 | head -3
    echo ""
    echo "Container IP test:"
    docker exec ent-nginx curl -I http://ent-twenty-crm:3000/metadata 2>&1 | head -3 || echo "Cannot reach twenty-crm from nginx"
    
    echo ""
    echo "📊 Final Status:"
    docker compose ps nginx twenty-crm tenant-manager
ENDSSH

rm -f $SSH_KEY_FILE

