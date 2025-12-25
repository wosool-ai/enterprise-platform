#!/bin/bash
# Apply nginx fix and test

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
    
    echo "🔄 Applying nginx fix..."
    git pull
    
    echo ""
    echo "🔄 Reloading nginx..."
    docker exec ent-nginx nginx -t && docker exec ent-nginx nginx -s reload
    
    echo ""
    echo "⏳ Waiting 3 seconds..."
    sleep 3
    
    echo ""
    echo "✅ Testing endpoints:"
    echo ""
    echo "API Health:"
    curl -s http://localhost/api/health | head -3
    echo ""
    echo ""
    echo "Root:"
    curl -s -I http://localhost/ | head -3
ENDSSH

rm -f $SSH_KEY_FILE

