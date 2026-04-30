
-- PRODUCTION GRADE UPGRADE SCRIPT
BEGIN;

-- 1. One-time Fees (SIM swaps, penalties, activation fees)
CREATE TABLE IF NOT EXISTS onetime_fee (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER REFERENCES contract(id),
    fee_type VARCHAR(50) NOT NULL, -- 'SIM_SWAP', 'PENALTY', 'ACTIVATION'
    amount NUMERIC(12,2) NOT NULL,
    description TEXT,
    applied_date DATE DEFAULT CURRENT_DATE,
    bill_id INTEGER REFERENCES bill(id) -- NULL until billed
);

-- 2. Payments (Recording real money inflow)
CREATE TABLE IF NOT EXISTS payment (
    id SERIAL PRIMARY KEY,
    bill_id INTEGER REFERENCES bill(id),
    amount NUMERIC(12,2) NOT NULL,
    payment_method VARCHAR(50), -- 'CASH', 'CREDIT_CARD', 'WALLET'
    payment_date TIMESTAMP DEFAULT NOW(),
    transaction_id VARCHAR(100) UNIQUE
);

-- 3. Bill Table Enhancements
ALTER TABLE bill ADD COLUMN IF NOT EXISTS due_date DATE;
ALTER TABLE bill ADD COLUMN IF NOT EXISTS one_time_fees NUMERIC(12,2) DEFAULT 0.00;
ALTER TABLE bill ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(12,2) DEFAULT 0.00;

-- 4. Audit Log (Tracking system activities)
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    actor VARCHAR(100),
    details TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Update existing bills to have a due date (14 days after billing date)
UPDATE bill SET due_date = billing_date + INTERVAL '14 days' WHERE due_date IS NULL;

-- 5. Updated generate_bill to pick up One-time Fees
CREATE OR REPLACE FUNCTION generate_bill(p_contract_id INTEGER, p_billing_period_start DATE)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
    DECLARE
        v_bill_id INTEGER;
        v_rateplan_id INTEGER;
        v_msisdn VARCHAR;
        v_recurring_fees NUMERIC(12,2);
        v_ror_rate_v NUMERIC(12,4);
        v_ror_rate_d NUMERIC(12,4);
        v_ror_rate_s NUMERIC(12,4);
        v_ror_roaming_v NUMERIC(12,4);
        v_ror_roaming_d NUMERIC(12,4);
        v_ror_roaming_s NUMERIC(12,4);
        v_voice_usage BIGINT;
        v_data_usage BIGINT;
        v_sms_usage BIGINT;
        v_overage_charge NUMERIC(12,2) := 0;
        v_roaming_charge NUMERIC(12,2) := 0;
        v_ot_fees NUMERIC(12,2) := 0;
        v_promo_discount NUMERIC(12,2) := 0;
        v_subtotal NUMERIC(12,2);
        v_taxes NUMERIC(12,2);
        v_total_amount NUMERIC(12,2);
        v_billing_period_end DATE;
        v_due_date DATE;
    BEGIN
        v_billing_period_end := (DATE_TRUNC('month', p_billing_period_start) + INTERVAL '1 month - 1 day')::DATE;
        v_due_date := CURRENT_DATE + INTERVAL '14 days';
        
        SELECT rateplan_id, msisdn INTO v_rateplan_id, v_msisdn FROM contract WHERE id = p_contract_id;
        
        SELECT price, ror_voice, ror_data, ror_sms, ror_roaming_voice, ror_roaming_data, ror_roaming_sms 
        INTO v_recurring_fees, v_ror_rate_v, v_ror_rate_d, v_ror_rate_s, v_ror_roaming_v, v_ror_roaming_d, v_ror_roaming_s
        FROM rateplan WHERE id = v_rateplan_id;

        -- 1. Calculate actual usage
        SELECT 
            COALESCE(SUM(CASE WHEN sp.type::TEXT = 'voice' THEN cc.consumed ELSE 0 END), 0)::BIGINT,
            COALESCE(SUM(CASE WHEN sp.type::TEXT = 'data' THEN cc.consumed ELSE 0 END), 0)::BIGINT,
            COALESCE(SUM(CASE WHEN sp.type::TEXT = 'sms' THEN cc.consumed ELSE 0 END), 0)::BIGINT
        INTO v_voice_usage, v_data_usage, v_sms_usage
        FROM contract_consumption cc JOIN service_package sp ON cc.service_package_id = sp.id
        WHERE cc.contract_id = p_contract_id AND cc.starting_date = p_billing_period_start;

        -- 2. Calculate overages
        SELECT 
            COALESCE(SUM((voice / 60.0 * v_ror_rate_v) + (data / 1073741824.0 * v_ror_rate_d) + (sms * v_ror_rate_s)), 0),
            COALESCE(SUM((roaming_voice / 60.0 * v_ror_roaming_v) + (roaming_data / 1073741824.0 * v_ror_roaming_d) + (roaming_sms * v_ror_roaming_s)), 0)
        INTO v_overage_charge, v_roaming_charge
        FROM ror_contract WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start AND bill_id IS NULL;

        -- 3. Calculate One-time Fees
        SELECT COALESCE(SUM(amount), 0) INTO v_ot_fees FROM onetime_fee WHERE contract_id = p_contract_id AND bill_id IS NULL;

        v_subtotal := (v_recurring_fees + v_overage_charge + v_roaming_charge + v_ot_fees - v_promo_discount);
        v_taxes := ROUND(0.14 * v_subtotal, 2);
        v_total_amount := v_subtotal + v_taxes;

        INSERT INTO bill (
            contract_id, billing_period_start, billing_period_end, billing_date, due_date,
            recurring_fees, voice_usage, data_usage, sms_usage,
            overage_charge, roaming_charge, one_time_fees, promotional_discount, taxes, total_amount, status
        ) VALUES (
            p_contract_id, p_billing_period_start, v_billing_period_end, CURRENT_DATE, v_due_date,
            v_recurring_fees, v_voice_usage, v_data_usage, v_sms_usage,
            v_overage_charge, v_roaming_charge, v_ot_fees, v_promo_discount, v_taxes, v_total_amount, 'issued'
        ) RETURNING id INTO v_bill_id;

        UPDATE ror_contract SET bill_id = v_bill_id WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start AND bill_id IS NULL;
        UPDATE contract_consumption SET bill_id = v_bill_id, is_billed = TRUE WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start;
        UPDATE onetime_fee SET bill_id = v_bill_id WHERE contract_id = p_contract_id AND bill_id IS NULL;

        INSERT INTO audit_log (action, actor, details) VALUES ('BILL_GENERATED', 'SYSTEM', 'Generated bill #' || v_bill_id || ' for MSISDN ' || v_msisdn);

        RETURN v_bill_id;
    END;
$function$;

COMMIT;
