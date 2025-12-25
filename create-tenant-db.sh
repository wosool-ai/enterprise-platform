#!/bin/bash
# Create the tenant template database

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
    
    echo "🗄️  Creating tenant template database..."
    
    # Get password from .env
    if [ -f .env ]; then
        export $(grep POSTGRES_PASSWORD .env | xargs)
    else
        echo "❌ .env file not found!"
        exit 1
    fi
    
    # Create the database
    docker exec ent-tenant-db psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname = 'twenty_tenant_template'" | grep -q 1 || \
    docker exec ent-tenant-db psql -U postgres -c "CREATE DATABASE twenty_tenant_template;"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database 'twenty_tenant_template' created successfully!"
    else
        echo "⚠️  Database may already exist or creation failed"
    fi
    
    echo ""
    echo "🔄 Restarting twenty-crm container..."
    docker compose restart twenty-crm
    
    echo ""
    echo "⏳ Waiting 10 seconds..."
    sleep 10
    
    echo ""
    echo "📊 twenty-crm status:"
    docker compose ps twenty-crm
    
    echo ""
    echo "📝 Recent logs:"
    docker compose logs --tail=20 twenty-crm
ENDSSH

rm -f $SSH_KEY_FILE

