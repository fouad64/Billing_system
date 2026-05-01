-- ============================================================
-- TELECOM BILLING SCHEMA - TYPES
-- Must be loaded FIRST (tables depend on these)
-- ============================================================

-- Service type for bundles
CREATE TYPE service_type AS ENUM ('voice', 'data', 'sms', 'free_units');

-- Contract status
CREATE TYPE contract_status AS ENUM ('active', 'suspended', 'suspended_debt', 'terminated');

-- Bill status
CREATE TYPE bill_status AS ENUM ('draft', 'issued', 'paid', 'overdue', 'cancelled');

-- User role
CREATE TYPE user_role AS ENUM ('admin', 'customer');

-- Billing type
CREATE TYPE billing_type AS ENUM ('POSTPAID', 'PREPAID');