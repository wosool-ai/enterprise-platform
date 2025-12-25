#!/bin/bash
# Restart services and check logs

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
    
    echo "🔄 Restarting all services..."
    docker compose down
    docker compose up -d
    
    echo ""
    echo "⏳ Waiting 20 seconds..."
    sleep 20
    
    echo ""
    echo "=== Container Status ==="
    docker compose ps -a
    
    echo ""
    echo "=== Failed Container Logs ==="
    for container in $(docker compose ps -a --format "{{.Name}}" 2>/dev/null); do
        status=$(docker inspect --format='{{.State.Status}}' $container 2>/dev/null)
        if [ "$status" != "running" ] && [ "$status" != "" ]; then
            echo "--- $container (Status: $status) ---"
            docker logs --tail=20 $container 2>&1 || echo "No logs"
            echo ""
        fi
    done
    
    echo ""
    echo "=== Running Containers ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
ENDSSH

rm -f $SSH_KEY_FILE

