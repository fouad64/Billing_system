-- ============================================================
-- RESET DATABASE (DEVELOPMENT ONLY)
-- WARNING: This file should NEVER be deployed to Railway
-- Use only for local development reset
-- ============================================================

-- Drop all tables (cascade drops FK dependencies)
DROP TABLE IF EXISTS cdr, invoice, bill, ror_contract, contract_consumption, contract_addon, contract, rejected_cdr, rateplan_service_package, service_package, rateplan, msisdn_pool, user_account, file, system_audit_log CASCADE;

-- Drop all types
DROP TYPE IF EXISTS service_type, contract_status, bill_status, user_role CASCADE;

-- Note: After running this, run deploy.sql to recreate the schema
SELECT 'Database reset complete. Run deploy.sql to recreate schema.' AS next_step;