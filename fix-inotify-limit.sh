#!/bin/bash
# Fix inotify file watcher limit for Docker builds

echo "🔧 Fixing inotify file watcher limit..."

# Check current limit
CURRENT_LIMIT=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "unknown")
echo "Current limit: $CURRENT_LIMIT"

# Set new limit (524288 is a good default, but we'll use 1048576 for large builds)
NEW_LIMIT=1048576

echo "Setting inotify limit to $NEW_LIMIT..."

# Set temporarily (for current session)
sysctl -w fs.inotify.max_user_watches=$NEW_LIMIT

# Make it permanent
if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf; then
    echo "fs.inotify.max_user_watches=$NEW_LIMIT" >> /etc/sysctl.conf
    echo "✅ Added to /etc/sysctl.conf (permanent)"
else
    # Update existing value
    sed -i "s/fs.inotify.max_user_watches=.*/fs.inotify.max_user_watches=$NEW_LIMIT/" /etc/sysctl.conf
    echo "✅ Updated /etc/sysctl.conf"
fi

# Verify
VERIFIED=$(cat /proc/sys/fs/inotify/max_user_watches)
echo ""
echo "✅ Inotify limit updated: $VERIFIED"
echo ""
echo "Now try building again:"
echo "  cd /root/wosool-ai && docker compose build twenty-crm"

