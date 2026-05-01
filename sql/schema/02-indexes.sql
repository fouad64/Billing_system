-- ============================================================
-- TELECOM BILLING SCHEMA - INDEXES
-- Must be loaded AFTER 01-tables.sql
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_cdr_rated_flag ON cdr(rated_flag);
CREATE INDEX IF NOT EXISTS idx_cdr_file_id ON cdr(file_id);
CREATE INDEX IF NOT EXISTS idx_cdr_dial_a ON cdr(dial_a);
CREATE INDEX IF NOT EXISTS idx_cdr_start_time ON cdr(start_time);

-- Idempotency Guard: Prevents duplicate CDR ingestion
CREATE UNIQUE INDEX IF NOT EXISTS idx_cdr_unique_ingestion ON cdr(dial_a, dial_b, start_time, duration);

-- Unique index for active contracts (allows reuse after termination)
CREATE UNIQUE INDEX IF NOT EXISTS contract_msisdn_active_idx 
ON contract (msisdn) WHERE (status != 'terminated');

CREATE INDEX IF NOT EXISTS idx_contract_user_account ON contract(user_account_id);
CREATE INDEX IF NOT EXISTS idx_contract_rateplan ON contract(rateplan_id);
CREATE INDEX IF NOT EXISTS idx_bill_contract ON bill(contract_id);
CREATE INDEX IF NOT EXISTS idx_bill_billing_date ON bill(billing_date);
CREATE INDEX IF NOT EXISTS idx_bill_period ON bill(billing_period_start, billing_period_end);
CREATE INDEX IF NOT EXISTS idx_invoice_bill ON invoice(bill_id);
CREATE INDEX IF NOT EXISTS idx_addon_contract ON contract_addon(contract_id);
CREATE INDEX IF NOT EXISTS idx_addon_active ON contract_addon(contract_id, is_active);
CREATE INDEX IF NOT EXISTS idx_contract_consumption_contract ON contract_consumption(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_consumption_period ON contract_consumption(starting_date);
CREATE INDEX IF NOT EXISTS idx_ror_contract_contract ON ror_contract(contract_id);
CREATE INDEX IF NOT EXISTS idx_ror_contract_period ON ror_contract(starting_date);
CREATE INDEX IF NOT EXISTS idx_audit_action ON system_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_performed_at ON system_audit_log(performed_at);