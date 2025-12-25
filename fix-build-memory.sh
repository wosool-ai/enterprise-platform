#!/bin/bash
# Quick fix for build memory issues on 2GB servers

echo "🔧 Fixing build memory issues..."

# Add swap space
if [ ! -f /swapfile ]; then
    echo "Creating 2GB swap file..."
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1024 count=2097152
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "✅ Swap created"
else
    echo "✅ Swap already exists"
    swapon /swapfile 2>/dev/null || true
fi

# Clean up Docker to free memory
echo "Cleaning Docker..."
docker system prune -af --volumes 2>/dev/null || true

# Show current memory
echo ""
echo "Current memory status:"
free -h

echo ""
echo "✅ Ready to build. Run:"
echo "   cd /root/wosool-ai && git pull && ./deploy-server.sh"

