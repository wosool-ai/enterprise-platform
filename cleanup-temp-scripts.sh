#!/bin/bash
# Clean up temporary/debug scripts, keeping only essential ones

set -e

cd /home/ubuntu/wosool-ai-enterprise

echo "🧹 Cleaning up temporary scripts..."
echo ""

# Scripts to KEEP (essential for deployment/maintenance)
KEEP_SCRIPTS=(
    "deploy-server.sh"
    "update-server.sh"
    "init-source-db.sh"
    "init-tenant-db.sh"
)

# Identify temporary scripts (fix-, check-, test-, apply-, verify-, resolve- scripts)
TEMP_SCRIPTS=$(find . -maxdepth 1 -name "*.sh" -type f ! -name "deploy-server.sh" ! -name "update-server.sh" ! -name "init-*.sh" | sort)

echo "Scripts to remove:"
echo "$TEMP_SCRIPTS" | while read script; do
    basename "$script"
done

echo ""
read -p "Remove these temporary scripts? (y/n): " confirm

if [ "$confirm" = "y" ]; then
    echo "$TEMP_SCRIPTS" | while read script; do
        echo "Removing: $script"
        rm -f "$script"
    done
    echo "✅ Cleanup complete"
else
    echo "❌ Cleanup cancelled"
    exit 1
fi

