#!/bin/bash
# Test API endpoints directly

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
    echo "🧪 Testing API endpoints..."
    echo ""
    
    echo "=== Testing Tenant Manager API ==="
    echo "GET /api/health:"
    curl -s http://localhost/api/health || echo "Failed"
    echo ""
    
    echo "GET /api (root):"
    curl -s http://localhost/api | head -5 || echo "Failed"
    echo ""
    
    echo "=== Testing Twenty CRM ==="
    echo "GET /metadata:"
    curl -s http://localhost/metadata | head -5 || echo "Failed"
    echo ""
    
    echo "GET /graphql (with query):"
    curl -s -X POST http://localhost/graphql \
        -H "Content-Type: application/json" \
        -d '{"query":"{ __typename }"}' | head -5 || echo "Failed"
    echo ""
    
    echo "=== Testing Direct Container Access ==="
    echo "Tenant Manager (port 3001):"
    docker exec ent-tenant-manager wget -q -O- http://localhost:3001/health 2>&1 | head -3
    echo ""
    
    echo "Twenty CRM (port 3000):"
    docker exec ent-twenty-crm wget -q -O- http://localhost:3000/metadata 2>&1 | head -3
    echo ""
    
    echo "=== Nginx Routing Test ==="
    echo "Testing if nginx can reach services:"
    docker exec ent-nginx wget -q -O- http://ent-tenant-manager:3001/health 2>&1 | head -3 || echo "Cannot reach tenant-manager"
    docker exec ent-nginx wget -q -O- http://ent-twenty-crm:3000/metadata 2>&1 | head -3 || echo "Cannot reach twenty-crm"
ENDSSH

rm -f $SSH_KEY_FILE

