-- ============================================================
-- TELECOM BILLING SCHEMA - TABLES
-- Must be loaded AFTER 00-types.sql
-- ============================================================

-- ------------------------------------------------------------
-- FILE (raw CDR file ingestion tracker)
-- ------------------------------------------------------------
CREATE TABLE file (
    id SERIAL PRIMARY KEY,
    parsed_flag BOOLEAN NOT NULL DEFAULT FALSE,
    file_path TEXT NOT NULL
);

-- ------------------------------------------------------------
-- USER ACCOUNT
-- ------------------------------------------------------------
CREATE TABLE user_account (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(30) NOT NULL,
    role user_role NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    address TEXT,
    birthdate DATE
);

-- ------------------------------------------------------------
-- MSISDN POOL
-- ------------------------------------------------------------
CREATE TABLE msisdn_pool (
    id SERIAL PRIMARY KEY,
    msisdn VARCHAR(20) NOT NULL UNIQUE,
    is_available BOOLEAN NOT NULL DEFAULT TRUE
);

-- ------------------------------------------------------------
-- RATEPLAN
-- ------------------------------------------------------------
CREATE TABLE rateplan (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    ror_data NUMERIC(15,2) NOT NULL,
    ror_voice NUMERIC(15,2) NOT NULL,
    ror_sms NUMERIC(15,2) NOT NULL,
    ror_roaming_data NUMERIC(15,2) NOT NULL DEFAULT 0.50,
    ror_roaming_voice NUMERIC(15,2) NOT NULL DEFAULT 1.00,
    ror_roaming_sms NUMERIC(15,2) NOT NULL DEFAULT 0.20,
    price NUMERIC(15,2) NOT NULL,
    type billing_type NOT NULL DEFAULT 'POSTPAID'
);

-- ------------------------------------------------------------
-- SERVICE PACKAGE
-- ------------------------------------------------------------
CREATE TABLE service_package (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    type service_type NOT NULL,
    amount BIGINT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 1,
    price NUMERIC(12,2),
    is_roaming BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT
);

-- ------------------------------------------------------------
-- RATEPLAN SERVICE PACKAGES
-- ------------------------------------------------------------
CREATE TABLE rateplan_service_package (
    rateplan_id INTEGER NOT NULL REFERENCES rateplan(id),
    service_package_id INTEGER NOT NULL REFERENCES service_package(id),
    PRIMARY KEY (rateplan_id, service_package_id)
);

-- ------------------------------------------------------------
-- CONTRACT
-- ------------------------------------------------------------
CREATE TABLE contract (
    id SERIAL PRIMARY KEY,
    user_account_id INTEGER NOT NULL REFERENCES user_account(id),
    rateplan_id INTEGER NOT NULL REFERENCES rateplan(id),
    msisdn VARCHAR(20) UNIQUE NOT NULL,
    status contract_status NOT NULL DEFAULT 'active',
    credit_limit NUMERIC(15,2) NOT NULL,
    available_credit NUMERIC(15,2) NOT NULL,
    balance NUMERIC(15,2) NOT NULL DEFAULT 0.00
);

-- ------------------------------------------------------------
-- CONTRACT CONSUMPTION
-- ------------------------------------------------------------
CREATE TABLE contract_consumption (
    contract_id INTEGER NOT NULL REFERENCES contract(id),
    service_package_id INTEGER NOT NULL REFERENCES service_package(id),
    rateplan_id INTEGER NOT NULL REFERENCES rateplan(id),
    starting_date DATE NOT NULL,
    ending_date DATE NOT NULL,
    consumed BIGINT NOT NULL DEFAULT 0,
    quota_limit BIGINT NOT NULL DEFAULT 0,
    is_billed BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (contract_id, service_package_id, rateplan_id, starting_date, ending_date)
);

-- ------------------------------------------------------------
-- ROR CONTRACT (Rate Overage Record)
-- ------------------------------------------------------------
CREATE TABLE ror_contract (
    contract_id INTEGER NOT NULL REFERENCES contract(id),
    rateplan_id INTEGER NOT NULL REFERENCES rateplan(id),
    starting_date DATE NOT NULL DEFAULT DATE_TRUNC('month', CURRENT_DATE)::DATE,
    voice BIGINT DEFAULT 0,
    data BIGINT DEFAULT 0,
    sms BIGINT DEFAULT 0,
    roaming_voice BIGINT DEFAULT 0,
    roaming_data BIGINT DEFAULT 0,
    roaming_sms BIGINT DEFAULT 0,
    PRIMARY KEY (contract_id, rateplan_id, starting_date)
);

-- ------------------------------------------------------------
-- BILL
-- ------------------------------------------------------------
CREATE TABLE bill (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER NOT NULL REFERENCES contract(id),
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    billing_date DATE NOT NULL,
    recurring_fees NUMERIC(15,2) NOT NULL,
    one_time_fees NUMERIC(15,2) NOT NULL DEFAULT 0,
    voice_usage BIGINT NOT NULL DEFAULT 0,
    data_usage BIGINT NOT NULL DEFAULT 0,
    sms_usage BIGINT NOT NULL DEFAULT 0,
    ror_charge NUMERIC(12,2) NOT NULL DEFAULT 0,
    overage_charge NUMERIC(15,2) NOT NULL DEFAULT 0,
    roaming_charge NUMERIC(15,2) NOT NULL DEFAULT 0,
    promotional_discount NUMERIC(15,2) NOT NULL DEFAULT 0,
    taxes NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(15,2) NOT NULL,
    subtotal NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_total NUMERIC(15,2) NOT NULL DEFAULT 0,
    overage_total NUMERIC(15,2) NOT NULL DEFAULT 0,
    roaming_total NUMERIC(15,2) NOT NULL DEFAULT 0,
    status bill_status NOT NULL DEFAULT 'draft',
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (contract_id, billing_period_start)
);

-- ------------------------------------------------------------
-- INVOICE
-- ------------------------------------------------------------
CREATE TABLE invoice (
    id SERIAL PRIMARY KEY,
    bill_id INTEGER NOT NULL UNIQUE REFERENCES bill(id),
    pdf_path TEXT,
    generation_date TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- REJECTED CDR
-- ------------------------------------------------------------
CREATE TABLE rejected_cdr (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES file(id),
    dial_a VARCHAR(20),
    dial_b VARCHAR(20),
    start_time TIMESTAMP,
    duration BIGINT,
    service_id INTEGER,
    rejection_reason VARCHAR(255),
    rejected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- CDR (Call Detail Record)
-- ------------------------------------------------------------
CREATE TABLE cdr (
    id SERIAL PRIMARY KEY,
    file_id INTEGER NOT NULL REFERENCES file(id),
    dial_a VARCHAR(20) NOT NULL,
    dial_b VARCHAR(20) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    duration BIGINT NOT NULL DEFAULT 0,
    service_id INTEGER REFERENCES service_package(id),
    hplmn VARCHAR(20),
    vplmn VARCHAR(20),
    external_charges NUMERIC(12,2) NOT NULL DEFAULT 0,
    rated_flag BOOLEAN NOT NULL DEFAULT FALSE,
    rated_service_id INTEGER,
    cost NUMERIC(15,4) NOT NULL DEFAULT 0.0000,
    usage_type VARCHAR(20),
    bill_id INTEGER REFERENCES bill(id)
);

-- ------------------------------------------------------------
-- CONTRACT ADDON
-- ------------------------------------------------------------
CREATE TABLE contract_addon (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER NOT NULL REFERENCES contract(id),
    service_package_id INTEGER NOT NULL REFERENCES service_package(id),
    purchased_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    price_paid NUMERIC(12,2) NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- SYSTEM AUDIT LOG (NEW)
-- ------------------------------------------------------------
CREATE TABLE system_audit_log (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    table_affected VARCHAR(50),
    records_affected INTEGER DEFAULT 0,
    performed_by VARCHAR(255),
    performed_at TIMESTAMP DEFAULT NOW(),
    details JSONB
);

CREATE TABLE onetime_fee (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER NOT NULL REFERENCES contract(id),
    fee_type VARCHAR(50) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    description TEXT,
    applied_date DATE DEFAULT CURRENT_DATE,
    bill_id INTEGER REFERENCES bill(id)
);

CREATE TABLE payment (
    id SERIAL PRIMARY KEY,
    bill_id INTEGER REFERENCES bill(id),
    amount NUMERIC(12,2) NOT NULL,
    payment_method VARCHAR(50),
    payment_date TIMESTAMP DEFAULT NOW(),
    transaction_id VARCHAR(100)
);

-- Add FK constraints for bill_id references
ALTER TABLE ror_contract ADD COLUMN bill_id INTEGER REFERENCES bill(id);
ALTER TABLE contract_consumption ADD COLUMN bill_id INTEGER REFERENCES bill(id);