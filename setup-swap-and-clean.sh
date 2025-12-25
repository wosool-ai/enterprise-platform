#!/bin/bash
# Quick setup: Add swap and clean Docker

set -e

echo "🔧 Setting up swap space and cleaning Docker..."

# Add swap space
if [ ! -f /swapfile ]; then
    echo "Creating 2GB swap file..."
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1024 count=2097152
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "✅ Swap space created and activated"
else
    echo "Swap file exists, activating..."
    swapon /swapfile 2>/dev/null || true
    echo "✅ Swap activated"
fi

# Clean Docker build cache
echo ""
echo "Cleaning Docker build cache (10.27GB)..."
docker builder prune -af
echo "✅ Docker build cache cleaned"

# Show updated status
echo ""
echo "Updated status:"
echo "Memory:"
free -h
echo ""
echo "Docker:"
docker system df

echo ""
echo "✅ Ready to build! Run:"
echo "   cd /root/wosool-ai && ./deploy-server.sh"

