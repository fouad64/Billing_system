CREATE OR REPLACE FUNCTION generate_bill(p_contract_id INTEGER, p_billing_period_start DATE)
RETURNS INTEGER AS $$
DECLARE
    v_billing_period_end DATE;
    v_recurring_fees NUMERIC(12,2);
    v_voice_usage BIGINT;
    v_data_usage BIGINT;
    v_sms_usage BIGINT;
    v_overage_charge NUMERIC(12,2);
    v_roaming_charge NUMERIC(12,2);
    v_promo_discount NUMERIC(12,2) := 0;
    v_taxes NUMERIC(12,2);
    v_subtotal NUMERIC(12,2);
    v_total_amount NUMERIC(12,2);
    v_rateplan_id INTEGER;
    v_bill_id INTEGER;
    v_msisdn VARCHAR;
    v_ror_rate_v NUMERIC;
    v_ror_rate_d NUMERIC;
    v_ror_rate_s NUMERIC;
    v_ror_roaming_v NUMERIC;
    v_ror_roaming_d NUMERIC;
    v_ror_roaming_s NUMERIC;
BEGIN
    v_billing_period_end := (DATE_TRUNC('month', p_billing_period_start) + INTERVAL '1 month - 1 day')::DATE;
    SELECT rateplan_id, msisdn INTO v_rateplan_id, v_msisdn FROM contract WHERE id = p_contract_id;
    
    SELECT price, ror_voice, ror_data, ror_sms, ror_roaming_voice, ror_roaming_data, ror_roaming_sms 
    INTO v_recurring_fees, v_ror_rate_v, v_ror_rate_d, v_ror_rate_s, v_ror_roaming_v, v_ror_roaming_d, v_ror_roaming_s 
    FROM rateplan WHERE id = v_rateplan_id;

    SELECT
        COALESCE(SUM(CASE WHEN sp.type::TEXT = 'voice' THEN cc.consumed ELSE 0 END), 0)::BIGINT,
        COALESCE(SUM(CASE WHEN sp.type::TEXT = 'data' THEN cc.consumed ELSE 0 END), 0)::BIGINT,
        COALESCE(SUM(CASE WHEN sp.type::TEXT = 'sms' THEN cc.consumed ELSE 0 END), 0)::BIGINT
    INTO v_voice_usage, v_data_usage, v_sms_usage
    FROM contract_consumption cc
    JOIN service_package sp ON cc.service_package_id = sp.id
    WHERE cc.contract_id = p_contract_id AND cc.starting_date = p_billing_period_start;

    -- Add domestic and roaming overage to the total bill counts
    SELECT 
        v_voice_usage + COALESCE(SUM(voice + roaming_voice), 0),
        v_data_usage + COALESCE(SUM(data + roaming_data), 0),
        v_sms_usage + COALESCE(SUM(sms + roaming_sms), 0)
    INTO v_voice_usage, v_data_usage, v_sms_usage
    FROM ror_contract
    WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start AND bill_id IS NULL;

    -- Calculate overage and roaming charges directly from the CDR table for accuracy
    SELECT 
        COALESCE(SUM(CASE WHEN (vplmn IS NOT NULL AND vplmn != '') THEN cost ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN (vplmn IS NULL OR vplmn = '') THEN cost ELSE 0 END), 0)
    INTO v_roaming_charge, v_overage_charge
    FROM cdr 
    WHERE dial_a = v_msisdn 
      AND DATE_TRUNC('month', start_time)::DATE = p_billing_period_start
      AND bill_id IS NULL
      AND rated_flag = TRUE;

    v_overage_charge := COALESCE(v_overage_charge, 0);
    v_roaming_charge := COALESCE(v_roaming_charge, 0);

    v_subtotal := (v_recurring_fees + v_overage_charge + v_roaming_charge - v_promo_discount);
    v_taxes := 0.14 * v_subtotal;
    v_total_amount := v_subtotal + v_taxes;

    INSERT INTO bill (
        contract_id, billing_period_start, billing_period_end, billing_date,
        recurring_fees, voice_usage, data_usage, sms_usage,
        overage_charge, roaming_charge, promotional_discount, taxes, total_amount, status
    ) VALUES (
        p_contract_id, p_billing_period_start, v_billing_period_end, CURRENT_DATE,
        v_recurring_fees, v_voice_usage, v_data_usage, v_sms_usage,
        v_overage_charge, v_roaming_charge, v_promo_discount, v_taxes, v_total_amount, 'issued'
    ) RETURNING id INTO v_bill_id;

    UPDATE ror_contract SET bill_id = v_bill_id WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start AND bill_id IS NULL;
    UPDATE cdr SET bill_id = v_bill_id WHERE dial_a = v_msisdn AND DATE_TRUNC('month', start_time)::DATE = p_billing_period_start AND bill_id IS NULL AND rated_flag = TRUE;
    UPDATE contract_consumption SET bill_id = v_bill_id, is_billed = TRUE WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start;

    RETURN v_bill_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_invoice(p_bill_id INTEGER, p_pdf_path TEXT)
       RETURNS VOID AS $$
BEGIN
INSERT INTO invoice (bill_id, pdf_path)
VALUES (p_bill_id, p_pdf_path);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_bills(p_search TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    id INTEGER,
    contract_id INTEGER,
    billing_date DATE,
    billing_period_start DATE,
    billing_period_end DATE,
    total_amount NUMERIC(12,2),
    is_paid BOOLEAN,
    status VARCHAR(20),
    voice_usage BIGINT,
