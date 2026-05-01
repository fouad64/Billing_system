-- ============================================================
-- MASTER DEPLOYMENT SCRIPT
-- Run in explicit order (NOT alphabetical)
-- Usage: psql -d database -f deploy.sql
-- ============================================================

-- Set environment guard
DO $$
BEGIN
    -- For development, use 'development'
    -- For production (Railway), this should be set externally
    IF current_setting('app.environment', TRUE) = '' THEN
        PERFORM set_config('app.environment', 'development', TRUE);
    END IF;
END
$$;

-- Schema files (in dependency order)
\i sql/schema/00-types.sql
\i sql/schema/01-tables.sql
\i sql/schema/02-indexes.sql
\i sql/schema/03-functions.sql
\i sql/schema/04-triggers.sql
\i sql/schema/05-reference-data.sql

-- Deployment complete
SELECT 
    'Deployment complete!' AS status,
    current_setting('app.environment') AS environment,
    NOW() AS deployed_at;