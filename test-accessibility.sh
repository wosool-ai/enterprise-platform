#!/bin/bash
# Test site accessibility

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
    echo "🌐 Testing site accessibility..."
    echo ""
    
    echo "=== Testing HTTP endpoints ==="
    echo "Root (/):"
    curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost/ || echo "Failed"
    
    echo ""
    echo "API (/api/health):"
    curl -s http://localhost/api/health || echo "Failed"
    
    echo ""
    echo "Health endpoint (/health):"
    curl -s http://localhost/health || echo "Failed"
    
    echo ""
    echo "=== Nginx Status ==="
    docker exec ent-nginx nginx -t 2>&1 | tail -1
    
    echo ""
    echo "=== Active Connections ==="
    ss -tlnp | grep :80
    
    echo ""
    echo "=== Testing from container ==="
    docker exec ent-nginx wget -q -O- http://ent-twenty-crm:3000/metadata 2>&1 | head -3 || echo "Cannot reach twenty-crm"
    
    echo ""
    echo "=== Checking if services are responding ==="
    echo "twenty-crm:"
    docker exec ent-twenty-crm wget -q -O- http://localhost:3000/metadata 2>&1 | head -1 || echo "Not responding"
    
    echo ""
    echo "tenant-manager:"
    docker exec ent-tenant-manager wget -q -O- http://localhost:3001/health 2>&1 | head -1 || echo "Not responding"
ENDSSH

rm -f $SSH_KEY_FILE

