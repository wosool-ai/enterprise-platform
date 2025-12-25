#!/bin/sh
# Production-ready entrypoint for Twenty CRM with proper error handling
# Follows industry best practices for Docker container initialization

set -eu

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly MONOREPO_ROOT="/app"
readonly SERVER_PACKAGE_DIR="${MONOREPO_ROOT}/packages/twenty-server"
readonly MIGRATION_SCRIPTS_DIR="${MONOREPO_ROOT}/scripts"
readonly MIGRATION_MARKER_FILE="${MONOREPO_ROOT}/.migration/.migrated"
readonly LOG_FILE="/tmp/twenty.log"
readonly MAX_STARTUP_WAIT=300
readonly HEALTH_CHECK_INTERVAL=5

# ============================================================================
# LOGGING UTILITIES
# ============================================================================

log_info() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

log_success() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
}

log_section() {
  echo ""
  echo "========================================================================"
  echo "$*"
  echo "========================================================================"
}

# ============================================================================
# DATABASE MIGRATION FUNCTIONS
# ============================================================================

ensure_database_exists() {
  log_info "Ensuring database exists..."
  
  # Extract database name from PG_DATABASE_URL
  # Format: postgresql://user:pass@host:port/dbname
  local db_url="${PG_DATABASE_URL}"
  
  # Use a more robust parsing approach
  # Remove protocol and query params
  local db_part
  db_part=$(echo "$db_url" | sed 's|postgresql://||' | sed 's|?.*||')
  
  # Extract database name (everything after last /)
  local db_name
  db_name=$(echo "$db_part" | sed 's|.*/||')
  
  # Extract host:port (everything between @ and /)
  local host_part
  host_part=$(echo "$db_part" | sed 's|.*@||' | sed 's|/.*||')
  local db_host
  db_host=$(echo "$host_part" | cut -d: -f1)
  local db_port
  db_port=$(echo "$host_part" | cut -d: -f2)
  db_port=${db_port:-5432}
  
  # Extract user:password (everything before @)
  local auth_part
  auth_part=$(echo "$db_part" | sed 's|@.*||')
  local db_user
  db_user=$(echo "$auth_part" | cut -d: -f1)
  local db_pass
  db_pass=$(echo "$auth_part" | cut -d: -f2-)
  
  if [ -z "$db_name" ]; then
    log_error "Could not parse database name from PG_DATABASE_URL"
    return 1
  fi
  
  if [ -z "$db_host" ] || [ -z "$db_user" ]; then
    log_error "Could not parse host or user from PG_DATABASE_URL"
    return 1
  fi
  
  log_info "Target database: $db_name on host: $db_host:$db_port"
  
  # Wait for database server to be ready
  log_info "Waiting for database server to be ready..."
  local retries=30
  local count=0
  while [ $count -lt $retries ]; do
    if PGPASSWORD="$db_pass" psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
      log_success "Database server is ready"
      break
    fi
    count=$((count + 1))
    if [ $count -eq $retries ]; then
      log_error "Database server not ready after $retries attempts"
      return 1
    fi
    log_info "Waiting for database... ($count/$retries)"
    sleep 2
  done
  
  # Check if database exists, create if not
  local db_exists
  db_exists=$(PGPASSWORD="$db_pass" psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" 2>/dev/null || echo "")
  
  if [ -z "$db_exists" ] || [ "$db_exists" != "1" ]; then
    log_info "Database '$db_name' does not exist. Creating..."
    PGPASSWORD="$db_pass" psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "CREATE DATABASE \"$db_name\";" 2>&1 || {
      log_error "Failed to create database '$db_name'"
      return 1
    }
    log_success "Database '$db_name' created successfully"
  else
    log_info "Database '$db_name' already exists"
  fi
  
  return 0
}

run_database_migrations() {
  log_section "Running Database Migrations"
  
  # Change to server package directory for migrations
  cd "${SERVER_PACKAGE_DIR}" || {
    log_error "Failed to change to server package directory: ${SERVER_PACKAGE_DIR}"
    return 1
  }
  
  if [ "${DISABLE_DB_MIGRATIONS:-false}" = "true" ]; then
    log_info "Database migrations disabled via DISABLE_DB_MIGRATIONS flag"
    return 0
  fi
  
  # Ensure database exists before attempting migrations
  if ! ensure_database_exists; then
    log_error "Failed to ensure database exists"
    return 1
  fi
  
  log_info "Checking database schema status..."
  
  # Check if core schema exists
  local has_schema
  has_schema=$(psql -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'core')" "${PG_DATABASE_URL}" 2>/dev/null || echo "f")
  
  if [ "$has_schema" = "f" ]; then
    log_info "Database appears to be empty. Running initial setup..."
    
    # Run database setup with memory limits
    log_info "Running database setup script..."
    NODE_OPTIONS="--max-old-space-size=1500" tsx ./scripts/setup-db.ts 2>&1 | head -20 || {
      log_error "Database setup failed"
      return 1
    }
    
    # Run production migrations
    log_info "Running production migrations..."
    yarn database:migrate:prod 2>&1 | tail -10 || {
      log_error "Database migrations failed"
      return 1
    }
  else
    log_info "Core schema exists. Running upgrade command..."
  fi
  
  # Run upgrade command
  log_info "Running upgrade command..."
  yarn command:prod upgrade 2>&1 | tail -5 || {
    log_error "Upgrade command failed"
    return 1
  }
  
  log_success "Database migrations completed successfully"
  return 0
}

# ============================================================================
# BACKGROUND JOBS REGISTRATION
# ============================================================================

register_background_jobs() {
  log_section "Registering Background Jobs"
  
  if [ "${DISABLE_CRON_JOBS_REGISTRATION:-false}" = "true" ]; then
    log_info "Background jobs registration disabled via DISABLE_CRON_JOBS_REGISTRATION flag"
    return 0
  fi
  
  # Change to server package directory for cron registration
  cd "${SERVER_PACKAGE_DIR}" || {
    log_error "Failed to change to server package directory: ${SERVER_PACKAGE_DIR}"
    return 1
  }
  
  log_info "Registering all background sync jobs..."
  yarn command:prod cron:register:all 2>&1 | tail -5 || {
    log_error "Background jobs registration failed"
    return 1
  }
  
  log_success "Background jobs registered successfully"
  return 0
}

# ============================================================================
# APPLICATION STARTUP
# ============================================================================

start_application() {
  log_section "Starting Twenty CRM Application"
  
  # CRITICAL: Change to monorepo root for Nx workspace context
  cd "${MONOREPO_ROOT}" || {
    log_error "Failed to change to monorepo root: ${MONOREPO_ROOT}"
    exit 1
  }
  
  log_info "Working directory: $(pwd)"
  
  # Check if node_modules exists, if not install dependencies
  if [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/nx" ]; then
    log_info "Dependencies not found, installing..."
    # Yarn v4 uses --immutable instead of --frozen-lockfile
    yarn install --immutable || {
      log_error "Failed to install dependencies"
      exit 1
    }
    log_success "Dependencies installed"
  else
    log_info "Dependencies already installed"
  fi
  
  log_info "Starting application server..."
  
  # Start the application with proper logging
  # Output goes to both stdout (for Docker logs) and log file
  if [ $# -eq 0 ]; then
    log_info "Using default start command: yarn start"
    exec yarn start 2>&1 | tee "${LOG_FILE}"
  else
    log_info "Using custom command: $*"
    exec "$@" 2>&1 | tee "${LOG_FILE}"
  fi
}

# ============================================================================
# SCHEMA MIGRATION FUNCTIONS (One-Time Setup)
# ============================================================================

check_migration_marker() {
  [ -f "${MIGRATION_MARKER_FILE}" ]
}

mark_migration_complete() {
  local marker_dir
  marker_dir=$(dirname "${MIGRATION_MARKER_FILE}")
  
  mkdir -p "${marker_dir}"
  {
    echo "Migration completed at: $(date -Iseconds)"
    echo "Container: $(hostname)"
  } > "${MIGRATION_MARKER_FILE}"
  
  log_success "Migration marked as complete"
}

load_environment_variables() {
  log_info "Loading environment variables from .env files..."
  
  # Try multiple .env file locations (sh-compatible, no arrays)
  for env_file in "${MONOREPO_ROOT}/.env" "/opt/twenty-crm-production/.env" "../../.env"; do
    if [ -f "$env_file" ]; then
      log_info "Found .env file at: $env_file"
      
      # Load TWENTY_ADMIN_TOKEN if not set
      if [ -z "${TWENTY_ADMIN_TOKEN:-}" ] || [ ${#TWENTY_ADMIN_TOKEN} -lt 20 ]; then
        local token
        token=$(grep "^TWENTY_ADMIN_TOKEN=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "")
        if [ -n "$token" ] && [ ${#token} -gt 20 ]; then
          export TWENTY_ADMIN_TOKEN="$token"
          log_success "Loaded TWENTY_ADMIN_TOKEN from $env_file (length: ${#token})"
        fi
      fi
      
      # Load BOOTSTRAP_SECRET if not set
      if [ -z "${BOOTSTRAP_SECRET:-}" ]; then
        local secret
        secret=$(grep "^BOOTSTRAP_SECRET=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "")
        if [ -n "$secret" ]; then
          export BOOTSTRAP_SECRET="$secret"
          log_success "Loaded BOOTSTRAP_SECRET from $env_file"
        fi
      fi
    fi
  done
  
  # Set fallback values
  export TWENTY_API_KEY="${TWENTY_API_KEY:-${APP_SECRET:-}}"
  export TWENTY_BASE_URL="${TWENTY_BASE_URL:-http://localhost:3000}"
}

validate_migration_environment() {
  log_info "Validating migration environment..."
  
  local validation_failed=0
  
  if [ -n "${TWENTY_ADMIN_TOKEN:-}" ] && [ ${#TWENTY_ADMIN_TOKEN} -gt 20 ]; then
    log_success "TWENTY_ADMIN_TOKEN: SET (${#TWENTY_ADMIN_TOKEN} chars)"
  else
    log_error "TWENTY_ADMIN_TOKEN: NOT SET or too short"
    validation_failed=1
  fi
  
  if [ -n "${BOOTSTRAP_SECRET:-}" ]; then
    log_success "BOOTSTRAP_SECRET: SET"
  else
    log_error "BOOTSTRAP_SECRET: NOT SET"
  fi
  
  log_info "TWENTY_BASE_URL: ${TWENTY_BASE_URL}"
  
  return $validation_failed
}

run_schema_migration() {
  log_section "Running Schema Migration (One-Time Setup)"
  
  # Check if already migrated
  if check_migration_marker; then
    log_success "Migration already completed (marker found at ${MIGRATION_MARKER_FILE})"
    log_info "Skipping migration - objects should already exist"
    return 0
  fi
  
  # Change to migration scripts directory
  cd "${MIGRATION_SCRIPTS_DIR}" || {
    log_error "Failed to change to migration scripts directory: ${MIGRATION_SCRIPTS_DIR}"
    return 1
  }
  
  # Load environment variables
  load_environment_variables
  
  # Validate environment
  if ! validate_migration_environment; then
    log_error "Migration environment validation failed"
    return 1
  fi
  
  # Run migration with explicit environment variables
  log_info "Executing schema migration script..."
  if env \
    TWENTY_ADMIN_TOKEN="${TWENTY_ADMIN_TOKEN}" \
    BOOTSTRAP_SECRET="${BOOTSTRAP_SECRET}" \
    TWENTY_API_KEY="${TWENTY_API_KEY}" \
    TWENTY_BASE_URL="${TWENTY_BASE_URL}" \
    npx ts-node migrate-schema.ts 2>&1; then
    
    log_success "Schema migration completed successfully"
    mark_migration_complete
    return 0
  else
    log_error "Schema migration failed"
    return 1
  fi
}

wait_for_server_ready() {
  log_section "Waiting for Twenty CRM Server to be Ready"
  
  local wait_count=0
  
  while [ $wait_count -lt $MAX_STARTUP_WAIT ]; do
    # Try each endpoint (sh-compatible, no arrays)
    for endpoint in "http://localhost:3000/health" "http://localhost:3000/" "http://localhost:3000/metadata"; do
      if curl -f -s "$endpoint" > /dev/null 2>&1; then
        log_success "Server is ready at $endpoint"
        return 0
      fi
    done
    
    sleep $HEALTH_CHECK_INTERVAL
    wait_count=$((wait_count + HEALTH_CHECK_INTERVAL))
    
    # Log progress every 30 seconds
    if [ $((wait_count % 30)) -eq 0 ]; then
      log_info "Still waiting for server... (${wait_count}/${MAX_STARTUP_WAIT}s)"
    fi
  done
  
  log_error "Server not ready after ${MAX_STARTUP_WAIT} seconds"
  return 1
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  log_section "Twenty CRM Container Initialization"
  log_info "Container: $(hostname)"
  log_info "Monorepo root: ${MONOREPO_ROOT}"
  log_info "Server package: ${SERVER_PACKAGE_DIR}"
  
  # Step 1: Run database migrations from server package directory
  if ! run_database_migrations; then
    log_error "Database migration failed. Exiting."
    exit 1
  fi
  
  # Step 2: Register background jobs
  if ! register_background_jobs; then
    log_error "Background jobs registration failed. Continuing anyway..."
  fi
  
  # Step 3: Start the application from monorepo root
  # This is critical - the application MUST start from /app for Nx to work
  log_section "Starting Application Server"
  log_info "Starting server from monorepo root: ${MONOREPO_ROOT}"
  
  # Start application in foreground (exec replaces shell process)
  # This ensures proper signal handling and PID 1 behavior
  start_application "$@"
}

# ============================================================================
# ENTRY POINT
# ============================================================================

# Trap signals for graceful shutdown
trap 'log_info "Received termination signal. Shutting down..."; exit 143' TERM
trap 'log_info "Received interrupt signal. Shutting down..."; exit 130' INT

# Execute main function
main "$@"
