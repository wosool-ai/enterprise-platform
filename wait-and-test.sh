#!/bin/bash
# Wait for service and test

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
    
    echo "⏳ Waiting for twenty-crm to be healthy..."
    timeout 120 bash -c 'until docker compose ps twenty-crm | grep -q "healthy"; do sleep 2; done' || echo "Timeout waiting for healthy status"
    
    echo ""
    echo "✅ Service status:"
    docker compose ps twenty-crm
    
    echo ""
    echo "🧪 Testing endpoints:"
    echo ""
    echo "1. /metadata:"
    curl -s -X POST http://localhost/metadata -H "Content-Type: application/json" -d '{}' | head -3
    echo ""
    echo ""
    echo "2. /client-config:"
    curl -s http://localhost/client-config | head -3
    echo ""
    echo ""
    echo "3. /graphql:"
    curl -s -X POST http://localhost/graphql -H "Content-Type: application/json" -d '{"query":"{ __typename }"}' | head -1
    echo ""
ENDSSH

rm -f $SSH_KEY_FILE

