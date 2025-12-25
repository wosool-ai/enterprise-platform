#!/bin/bash
# Check twenty-crm build error

echo "🔍 Checking twenty-crm build error..."
echo ""

cd /root/wosool-ai

# Check if twenty directory exists
if [ ! -d "/root/twenty" ]; then
    echo "❌ /root/twenty directory not found!"
    echo "   The twenty-crm service requires the Twenty CRM repository at /root/twenty"
    exit 1
fi

# Check Docker build logs
echo "Checking recent Docker build logs..."
docker compose logs --tail=50 2>/dev/null || docker-compose logs --tail=50 2>/dev/null

echo ""
echo "Checking memory..."
free -h

echo ""
echo "To see full build error, run:"
echo "  docker compose build --progress=plain twenty-crm 2>&1 | tail -100"

