-- =====================================================
-- Global Tenant Registry Database Schema
-- =====================================================
-- This database stores metadata for all tenants
-- Each tenant has their own isolated database
-- =====================================================

-- Tenant Registry Table
CREATE TABLE IF NOT EXISTS tenant_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    database_name VARCHAR(63) UNIQUE NOT NULL,
    database_url TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended', 'deleted')),
    plan VARCHAR(50) DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'enterprise')),
    admin_user_id UUID,
    encryption_key TEXT,
    salla_store_id VARCHAR(255) UNIQUE,
    salla_access_token TEXT,
    salla_refresh_token TEXT,
    salla_domain VARCHAR(255),
    clerk_org_id VARCHAR(255) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    suspended_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Global Users Table (for cross-tenant authentication)
CREATE TABLE IF NOT EXISTS global_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT,
    tenant_id UUID NOT NULL REFERENCES tenant_registry(id) ON DELETE CASCADE,
    clerk_user_id VARCHAR(255) UNIQUE,
    role VARCHAR(50) DEFAULT 'USER' CHECK (role IN ('USER', 'ADMIN', 'SUPER_ADMIN')),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tenant Settings Table
CREATE TABLE IF NOT EXISTS tenant_settings (
    tenant_id UUID PRIMARY KEY REFERENCES tenant_registry(id) ON DELETE CASCADE,
    settings JSONB DEFAULT '{}'::jsonb,
    widget_config JSONB DEFAULT '{
        "enabled": true,
        "script_url": "/public/widget/wosool-widget.js",
        "tools_url": "/public/widget/tools/",
        "tools_enabled": [
            "contextReader",
            "domManipulator",
            "intentAnalyzer",
            "dataExtractor",
            "enhancedNavigation",
            "navigationController"
        ],
        "elevenlabs_agent_id": null,
        "custom_settings": {}
    }'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tenant Usage Statistics
CREATE TABLE IF NOT EXISTS tenant_usage (
    tenant_id UUID PRIMARY KEY REFERENCES tenant_registry(id) ON DELETE CASCADE,
    database_size_bytes BIGINT DEFAULT 0,
    api_calls_count INTEGER DEFAULT 0,
    api_calls_last_reset TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    active_users_count INTEGER DEFAULT 0,
    workflow_executions_count INTEGER DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_tenant_registry_slug ON tenant_registry(slug);
CREATE INDEX IF NOT EXISTS idx_tenant_registry_status ON tenant_registry(status);
CREATE INDEX IF NOT EXISTS idx_tenant_registry_database_name ON tenant_registry(database_name);
CREATE INDEX IF NOT EXISTS idx_tenant_registry_salla_store_id ON tenant_registry(salla_store_id);
CREATE INDEX IF NOT EXISTS idx_tenant_registry_clerk_org_id ON tenant_registry(clerk_org_id);
CREATE INDEX IF NOT EXISTS idx_global_users_email ON global_users(email);
CREATE INDEX IF NOT EXISTS idx_global_users_clerk_user_id ON global_users(clerk_user_id);
CREATE INDEX IF NOT EXISTS idx_global_users_tenant_id ON global_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_global_users_active ON global_users(is_active) WHERE is_active = true;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_tenant_registry_updated_at 
    BEFORE UPDATE ON tenant_registry 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_global_users_updated_at 
    BEFORE UPDATE ON global_users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tenant_settings_updated_at 
    BEFORE UPDATE ON tenant_settings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tenant_usage_updated_at 
    BEFORE UPDATE ON tenant_usage 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- View for active tenants
CREATE OR REPLACE VIEW active_tenants AS
SELECT 
    tr.id,
    tr.slug,
    tr.name,
    tr.database_name,
    tr.plan,
    tr.created_at,
    tu.database_size_bytes,
    tu.active_users_count,
    tu.last_activity
FROM tenant_registry tr
LEFT JOIN tenant_usage tu ON tr.id = tu.tenant_id
WHERE tr.status = 'active';

-- Comments for documentation
COMMENT ON TABLE tenant_registry IS 'Registry of all tenant organizations with Salla integration';
COMMENT ON TABLE global_users IS 'Global user authentication across all tenants';
COMMENT ON TABLE tenant_settings IS 'Tenant-specific configuration including widget and tools';
COMMENT ON TABLE tenant_usage IS 'Usage statistics and metrics per tenant';
COMMENT ON VIEW active_tenants IS 'View of all active tenants with usage stats';

