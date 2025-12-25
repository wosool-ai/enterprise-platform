# Production-Ready Twenty CRM Dockerfile
# Extends the official Twenty CRM image with custom migration support
# Follows Docker best practices for production deployments

FROM twentycrm/twenty:latest

# ============================================================================
# METADATA
# ============================================================================

LABEL maintainer="DevOps Team"
LABEL description="Twenty CRM with custom schema migration support"
LABEL version="1.0"

# ============================================================================
# SYSTEM DEPENDENCIES
# ============================================================================

# Install required system packages
# Try multiple package managers for compatibility across base images
RUN set -eux; \
    (apk add --no-cache \
        nodejs \
        npm \
        curl \
        postgresql-client \
        bash \
        ca-certificates \
        2>/dev/null) || \
    (apt-get update && \
     apt-get install -y --no-install-recommends \
        curl \
        postgresql-client \
        nodejs \
        npm \
        bash \
        ca-certificates && \
     apt-get clean && \
     rm -rf /var/lib/apt/lists/* \
     2>/dev/null) || \
    (yum install -y \
        curl \
        postgresql \
        nodejs \
        npm \
        bash \
        ca-certificates && \
     yum clean all \
     2>/dev/null) || \
    echo "Warning: Could not install all dependencies"

# ============================================================================
# APPLICATION SETUP
# ============================================================================

# Set working directory for migration scripts
WORKDIR /app/scripts

# Copy migration scripts and dependencies
COPY scripts/package.json scripts/migrate-schema.ts ./

# Install migration script dependencies
# Use --production to minimize image size
# Disable audit and fund messages for cleaner output
RUN npm install --production --no-audit --no-fund || \
    echo "Warning: npm install failed - migration may not work"

# Create migration marker directory
RUN mkdir -p /app/.migration && \
    chmod 755 /app/.migration

# ============================================================================
# ENTRYPOINT SETUP
# ============================================================================

# Copy custom entrypoint script with explicit permissions
# Using standard /entrypoint.sh path for maximum compatibility
COPY --chmod=755 scripts/docker-entrypoint.sh /entrypoint.sh

# Verify entrypoint is executable
RUN test -x /entrypoint.sh || \
    (echo "ERROR: Entrypoint script is not executable" && exit 1)

# Set working directory back to monorepo root
# This is critical for Nx workspace resolution
WORKDIR /app

# ============================================================================
# RUNTIME CONFIGURATION
# ============================================================================

# Expose application port
EXPOSE 3000

# Set environment variables for better Node.js behavior in containers
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=2048"

# Health check to ensure service is responding
# This allows Docker/Kubernetes to detect unhealthy containers
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || \
        curl -f http://localhost:3000/ || \
        exit 1

# Override entrypoint - use /bin/sh (more compatible) or ensure bash is installed
# Try with /bin/sh first, which is available in all Linux containers
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]

# Default command (can be overridden in docker-compose.yml)
CMD []
