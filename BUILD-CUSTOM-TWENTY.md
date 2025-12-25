# Building Custom Twenty CRM Docker Image

This document describes the process of building a custom Twenty CRM Docker image with extensive customizations for the Wosool Enterprise Platform.

## Overview

We clone the official Twenty CRM repository, apply customizations, build a production-ready Docker image, and publish it to Docker Hub for use in production.

## Prerequisites

- Docker and Docker BuildKit installed
- Docker Hub account/organization (`wosool-ai`)
- Access to clone Twenty CRM repository
- Sufficient disk space (~10GB for build process)

## Step 1: Clone Repository

```bash
cd /home/ubuntu/wosool-ai-enterprise
git clone https://github.com/twentyhq/twenty.git twenty-crm-source
cd twenty-crm-source
```

## Step 2: Apply Customizations

### 2.1 Environment Configuration

Customize environment variable defaults in:
- `packages/twenty-server/src/config/environment/` - Server configuration
- `packages/twenty-front/` - Frontend environment variables

Key customizations:
- Clerk integration settings
- Server URL defaults
- Multi-tenant routing configuration

### 2.2 Routing Customizations

Modify routing in:
- `packages/twenty-front/src/modules/app/components/AppRouter.tsx`
- `packages/twenty-front/src/modules/app/hooks/useCreateAppRouter.tsx`

Customize `/welcome` redirect behavior if needed.

### 2.3 Clerk Integration

Ensure Clerk is properly integrated:
- Check `packages/twenty-front/src/` for Clerk components
- Verify environment variables are properly configured
- Test authentication flow

### 2.4 Build Configuration

The Dockerfile is located at:
- `packages/twenty-docker/twenty/Dockerfile`

Modify if needed for custom build steps.

## Step 3: Build Docker Image

### 3.1 Build Command

```bash
cd /home/ubuntu/wosool-ai-enterprise/twenty-crm-source

# Build with Docker BuildKit
DOCKER_BUILDKIT=1 docker build \
  -f packages/twenty-docker/twenty/Dockerfile \
  -t wosool-ai/twenty-crm:latest \
  -t wosool-ai/twenty-crm:v1.0.0 \
  --build-arg REACT_APP_SERVER_BASE_URL=http://167.99.20.94 \
  --build-arg APP_VERSION=v1.0.0 \
  .
```

### 3.2 Build Process

The build process:
1. Installs dependencies (common-deps stage)
2. Builds backend (twenty-server-build stage)
3. Builds frontend (twenty-front-build stage)
4. Creates final runtime image (twenty stage)

### 3.3 Build Time

Expected build time: 15-30 minutes depending on system resources.

## Step 4: Test Image Locally

```bash
# Test the image
docker run -d \
  --name twenty-test \
  -p 3000:3000 \
  -e PG_DATABASE_URL=postgresql://user:pass@host:5432/db \
  -e SERVER_URL=http://localhost:3000 \
  wosool-ai/twenty-crm:latest

# Check logs
docker logs twenty-test

# Test health endpoint
curl http://localhost:3000/healthz

# Cleanup
docker stop twenty-test && docker rm twenty-test
```

## Step 5: Push to Docker Hub

### 5.1 Login to Docker Hub

```bash
docker login
# Enter your Docker Hub username and password/token
```

### 5.2 Push Image

```bash
# Push all tags
docker push wosool-ai/twenty-crm:latest
docker push wosool-ai/twenty-crm:v1.0.0
```

### 5.3 Verify

Check Docker Hub: https://hub.docker.com/r/wosool-ai/twenty-crm

## Step 6: Update Production Configuration

### 6.1 Update docker-compose.yml

Change the image reference:

```yaml
twenty-crm:
  image: wosool-ai/twenty-crm:latest  # Changed from twentycrm/twenty:latest
  # ... rest of configuration remains the same
```

### 6.2 Deploy

```bash
cd /home/ubuntu/wosool-ai-enterprise
docker compose pull twenty-crm
docker compose up -d twenty-crm
```

## Step 7: Cleanup

After successful build and deployment:

```bash
# Remove cloned repository (saves ~5GB)
rm -rf /home/ubuntu/wosool-ai-enterprise/twenty-crm-source
```

## Customization Checklist

- [ ] Environment variables configured
- [ ] Clerk integration verified
- [ ] Routing customizations applied
- [ ] Build tested locally
- [ ] Image pushed to Docker Hub
- [ ] Production deployment updated
- [ ] Cleanup completed

## Troubleshooting

### Build Fails

- Check disk space: `df -h`
- Check Docker BuildKit: `DOCKER_BUILDKIT=1`
- Review build logs for specific errors

### Image Too Large

- Use multi-stage builds (already implemented)
- Remove unnecessary dependencies
- Optimize layer caching

### Push Fails

- Verify Docker Hub login
- Check image tags are correct
- Ensure organization permissions

## Versioning

- `latest` - Always points to most recent build
- `v1.0.0` - Specific version tag
- `v1.0.0-YYYYMMDD` - Date-based tags for tracking

## Maintenance

To rebuild with updates:

1. Pull latest from Twenty CRM repo
2. Reapply customizations
3. Rebuild and push
4. Update production

## Notes

- The cloned repository (`twenty-crm-source/`) is temporary and should be removed after build
- Keep customization notes for future rebuilds
- Document any breaking changes in customizations

