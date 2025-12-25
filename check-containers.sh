#!/bin/bash
# Check all containers status

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
    
    echo "=== All Containers (including stopped) ==="
    docker ps -a
    echo ""
    
    echo "=== Running Containers ==="
    docker ps
    echo ""
    
    echo "=== Docker Compose Status ==="
    docker compose ps
    echo ""
    
    echo "=== Twenty CRM Image ==="
    docker images | grep -E "twenty|REPOSITORY"
    echo ""
    
    echo "=== Recent Logs (last 10 lines each) ==="
    for container in ent-twenty-crm ent-tenant-manager ent-nginx; do
        if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
            echo "--- $container ---"
            docker logs --tail=10 $container 2>&1 || echo "No logs"
            echo ""
        fi
    done
ENDSSH

rm -f $SSH_KEY_FILE

