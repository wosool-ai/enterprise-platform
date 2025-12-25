# Custom Twenty CRM - Clerk Integration & Data Model Migration Plan

## Overview

This plan covers:
1. **Migrating custom data model** into the cloned Twenty CRM repository
2. **Integrating Clerk authentication** to replace/bypass the initial sign-in flow
3. **Modifying routing** to redirect authenticated Clerk users directly to workspace creation/dashboard
4. **Building and deploying** the customized image

## Phase 1: Migrate Custom Data Model

### 1.1 Copy Migration Script

Copy the custom data model migration script to the cloned repository:

**Source**: `services/twenty-crm/scripts/migrate-schema.ts`
**Destination**: `twenty-crm-source/packages/twenty-server/scripts/migrate-schema.ts`

This script creates:
- 7 Custom Objects (Agent Settings, Salla Products, Orders, Carts, Voice Calls, Workflow Executions, Communication Logs)
- Extended fields on 3 existing objects (Person, Opportunity, Workflow)
- 6 Relationships between objects

### 1.2 Integrate Migration into Build

Modify the Dockerfile or entrypoint to run migration automatically:
- Add migration script to the build
- Run migration on container startup (after server is ready)
- Make it idempotent (safe to run multiple times)

## Phase 2: Clerk Authentication Integration

### 2.1 Install Clerk Dependencies

Add Clerk packages to Twenty CRM frontend:

```bash
cd twenty-crm-source/packages/twenty-front
yarn add @clerk/clerk-react
```

### 2.2 Create Clerk Provider Wrapper

Create a Clerk provider component that wraps the app:

**File**: `twenty-crm-source/packages/twenty-front/src/modules/auth/components/ClerkProvider.tsx`

This will:
- Initialize Clerk with publishable key from environment
- Handle Clerk authentication state
- Sync Clerk user with Twenty CRM user system
- Redirect unauthenticated users to Clerk sign-in

### 2.3 Modify AppRouterProviders

Update `AppRouterProviders.tsx` to include ClerkProvider:

```tsx
<ClerkProvider>
  <ApolloProvider>
    {/* existing providers */}
  </ApolloProvider>
</ClerkProvider>
```

### 2.4 Create Clerk Auth Hook

Create a hook to check Clerk authentication and sync with Twenty CRM:

**File**: `twenty-crm-source/packages/twenty-front/src/modules/auth/hooks/useClerkAuth.ts`

This hook will:
- Check if user is authenticated via Clerk
- If authenticated, check if user exists in Twenty CRM
- If new user, create workspace automatically (via webhook)
- Redirect to dashboard/workspace after authentication

### 2.5 Modify SignInUp Component

Update `SignInUp.tsx` to:
- Check Clerk authentication first
- If Clerk authenticated, skip sign-in form
- Show only workspace creation/data initialization steps
- Redirect to dashboard after workspace setup

### 2.6 Modify Routing Logic

Update `useCreateAppRouter.tsx` to:
- Check Clerk authentication on root path (`/`)
- If not authenticated, redirect to Clerk sign-in
- If authenticated but no workspace, redirect to workspace creation
- If authenticated with workspace, redirect to dashboard

## Phase 3: Backend Integration

### 3.1 Clerk Webhook Handler

The webhook handler already exists in `tenant-manager`. Ensure it:
- Creates tenant when organization is created
- Links Clerk user to Twenty CRM user
- Creates workspace automatically

### 3.2 Sync Clerk User to Twenty CRM

Create backend endpoint or modify existing auth to:
- Accept Clerk JWT token
- Verify token with Clerk
- Create/update user in Twenty CRM
- Link to tenant/workspace

## Phase 4: Environment Configuration

### 4.1 Update Environment Variables

Ensure these are set in the Docker image:
- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
- `CLERK_SECRET_KEY`
- `CLERK_WEBHOOK_SECRET`
- `CLERK_WEBHOOK_URL`
- `SERVER_URL` (for API calls)

### 4.2 Update Dockerfile

Modify the Dockerfile to:
- Include migration script
- Set environment variable defaults
- Configure Clerk settings

## Phase 5: Build & Deploy

### 5.1 Build Custom Image

```bash
cd twenty-crm-source
DOCKER_BUILDKIT=1 docker build \
  -f packages/twenty-docker/twenty/Dockerfile \
  -t wosool-ai/twenty-crm:latest \
  --build-arg REACT_APP_SERVER_BASE_URL=http://167.99.20.94 \
  .
```

### 5.2 Push to Docker Hub

```bash
docker push wosool-ai/twenty-crm:latest
```

### 5.3 Update docker-compose.yml

Change image reference to use custom image.

## Implementation Details

### Authentication Flow

```
User visits http://167.99.20.94
    ↓
ClerkProvider checks authentication
    ↓
Not authenticated → Redirect to Clerk sign-in
    ↓
Authenticated via Clerk
    ↓
Check if user exists in Twenty CRM
    ↓
New user → Create workspace (via webhook) → Show workspace setup
Existing user → Redirect to dashboard
```

### Routing Changes

1. **Root path (`/`)**:
   - Check Clerk authentication
   - If not authenticated: redirect to Clerk
   - If authenticated: check workspace status
   - Redirect accordingly

2. **Sign-in page (`/sign-in-up`)**:
   - If Clerk authenticated: skip sign-in form
   - Show only workspace creation steps
   - Auto-complete user data from Clerk

3. **Workspace creation**:
   - Pre-fill with Clerk user data
   - Auto-create if organization exists in Clerk
   - Link to tenant via webhook

### Data Model Migration

The migration script will:
1. Run automatically on container startup
2. Wait for server to be ready
3. Create all custom objects and fields
4. Verify migration success
5. Continue normal startup

## Files to Create/Modify

### New Files
1. `twenty-crm-source/packages/twenty-front/src/modules/auth/components/ClerkProvider.tsx`
2. `twenty-crm-source/packages/twenty-front/src/modules/auth/hooks/useClerkAuth.ts`
3. `twenty-crm-source/packages/twenty-server/scripts/migrate-schema.ts`
4. `twenty-crm-source/packages/twenty-server/src/auth/clerk/clerk-auth.service.ts` (backend)

### Modified Files
1. `twenty-crm-source/packages/twenty-front/src/modules/app/components/AppRouterProviders.tsx` - Add ClerkProvider
2. `twenty-crm-source/packages/twenty-front/src/modules/app/hooks/useCreateAppRouter.tsx` - Modify routing logic
3. `twenty-crm-source/packages/twenty-front/src/pages/auth/SignInUp.tsx` - Bypass sign-in for Clerk users
4. `twenty-crm-source/packages/twenty-front/package.json` - Add @clerk/clerk-react
5. `twenty-crm-source/packages/twenty-docker/twenty/Dockerfile` - Include migration script
6. `twenty-crm-source/packages/twenty-docker/twenty/entrypoint.sh` - Run migration on startup

## Testing Checklist

- [ ] Clerk authentication works
- [ ] Unauthenticated users redirect to Clerk
- [ ] Authenticated users skip sign-in
- [ ] Workspace creation works for new users
- [ ] Existing users go to dashboard
- [ ] Data model migration runs successfully
- [ ] Multi-tenant isolation works
- [ ] Webhook creates tenants automatically

## Next Steps

1. Copy migration script to cloned repo
2. Install Clerk dependencies
3. Create ClerkProvider component
4. Modify routing logic
5. Update SignInUp component
6. Test authentication flow
7. Build and deploy

