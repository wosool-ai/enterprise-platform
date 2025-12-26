# Clerk Provider Fix Summary

## Problem
Error: `@clerk/clerk-react: useAuth can only be used within the <ClerkProvider /> component`

## Root Cause
1. `ClerkProvider` was returning early (without `ClerkProviderBase`) if the publishable key wasn't found
2. `ClerkAuthGuard` and other components were using `useAuth()` hook
3. Since `ClerkProviderBase` wasn't wrapping the app, `useAuth()` threw an error

## Solution

### 1. Fixed ClerkProvider (`packages/twenty-front/src/modules/auth/components/ClerkProvider.tsx`)
- **Always wraps with `ClerkProviderBase`**, even if key is missing
- Uses placeholder key if real key not found (prevents errors)
- Improved environment variable reading:
  - Checks `window._env_` (runtime injected)
  - Checks `import.meta.env.VITE_CLERK_PUBLISHABLE_KEY` (build time)
  - Checks `import.meta.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` (build time)

### 2. Updated Runtime Env Injection (`packages/twenty-front/scripts/inject-runtime-env.sh`)
- Added `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` to injected config
- Now injects both `REACT_APP_SERVER_BASE_URL` and Clerk key

### 3. Updated Dockerfile (`packages/twenty-docker/twenty/Dockerfile`)
- Added `ARG NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
- Set as `ENV` variables for build process
- Ensures key is available during build and runtime injection

### 4. Fixed ClerkAuthGuard (`packages/twenty-front/src/modules/auth/components/ClerkAuthGuard.tsx`)
- Removed try-catch (React hooks must be called unconditionally)
- Now safely uses `useAuth()` since `ClerkProviderBase` always wraps

## Environment Variable Priority

1. **Runtime** (injected via `inject-runtime-env.sh`): `window._env_.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
2. **Build time** (Vite): `import.meta.env.VITE_CLERK_PUBLISHABLE_KEY`
3. **Build time** (Next.js style): `import.meta.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`

## Testing

To test the fix:
1. Build with Clerk key: `--build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=your-key`
2. Or set at runtime via `docker-compose.test.yml` environment variables
3. Access http://localhost:3000
4. Should no longer see "useAuth can only be used within ClerkProvider" error

## Files Modified

- `twenty-crm-source/packages/twenty-front/src/modules/auth/components/ClerkProvider.tsx`
- `twenty-crm-source/packages/twenty-front/src/modules/auth/components/ClerkAuthGuard.tsx`
- `twenty-crm-source/packages/twenty-front/scripts/inject-runtime-env.sh`
- `twenty-crm-source/packages/twenty-docker/twenty/Dockerfile`

