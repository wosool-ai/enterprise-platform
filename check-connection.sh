#!/bin/bash
# Check why connection is refused

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
    echo "🔍 Checking connection issues..."
    echo ""
    
    echo "=== Port 80 Status ==="
    netstat -tlnp | grep :80 || ss -tlnp | grep :80
    echo ""
    
    echo "=== Nginx Container Status ==="
    docker ps | grep nginx
    echo ""
    
    echo "=== Nginx Logs (last 20 lines) ==="
    docker logs --tail=20 ent-nginx 2>&1
    echo ""
    
    echo "=== Testing local connection ==="
    curl -I http://localhost 2>&1 | head -5 || echo "Local connection failed"
    echo ""
    
    echo "=== Firewall Status ==="
    ufw status 2>/dev/null || iptables -L -n | grep -E "80|443" | head -5 || echo "No firewall rules found"
    echo ""
    
    echo "=== Docker Network ==="
    docker network inspect wosool-ai_ent-network 2>/dev/null | grep -A 5 "Containers" | head -10 || echo "Network not found"
    echo ""
    
    echo "=== Testing services directly ==="
    echo "Testing tenant-manager:"
    curl -I http://localhost:3001/health 2>&1 | head -3 || echo "Failed"
    echo ""
    echo "Testing twenty-crm:"
    curl -I http://localhost:3000/metadata 2>&1 | head -3 || echo "Failed"
ENDSSH

rm -f $SSH_KEY_FILE

