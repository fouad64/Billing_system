-- ============================================================
-- TELECOM BILLING SCHEMA - FUNCTIONS (CLEANED)
-- ============================================================

CREATE OR REPLACE FUNCTION add_new_service_package(
    p_name VARCHAR(255),
    p_type service_type,
    p_amount NUMERIC(12,4),
    p_priority INTEGER,
    p_price NUMERIC(15,2),
    p_description TEXT DEFAULT NULL,
    p_is_roaming BOOLEAN DEFAULT FALSE
)
RETURNS INTEGER AS $$
DECLARE v_new_id INTEGER;
BEGIN
    INSERT INTO service_package (name, type, amount, priority, price, description, is_roaming)
    VALUES (p_name, p_type, p_amount, p_priority, p_price, p_description, p_is_roaming)
    RETURNING id INTO v_new_id;
    RETURN v_new_id;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'add_new_service_package failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION auto_initialize_consumption()
    RETURNS TRIGGER AS $$
    DECLARE v_period_start DATE;
BEGIN
    v_period_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    PERFORM initialize_consumption_period(v_period_start);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION auto_rate_cdr()
           RETURNS TRIGGER AS $$
BEGIN
           IF NEW.service_id IS NOT NULL THEN
              PERFORM rate_cdr(NEW.id);
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cancel_addon(p_addon_id INTEGER)
    RETURNS VOID AS $$
BEGIN
    UPDATE contract_addon SET is_active = FALSE WHERE id = p_addon_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION change_contract_rateplan(
    p_contract_id     INTEGER,
    p_new_rateplan_id INTEGER
)
RETURNS VOID AS $$
DECLARE
v_contract          contract;
    v_old_rateplan_id   INTEGER;
    v_period_start      DATE;
    v_period_end        DATE;
    v_change_day        INTEGER;
    v_days_in_month     INTEGER;
    v_days_used         INTEGER;
    v_days_remaining    INTEGER;
    v_usage_ratio       NUMERIC;  -- how far through the month (0.0 → 1.0)
    v_should_prorate    BOOLEAN := FALSE;
    v_bundle            RECORD;
    v_voice_overage     NUMERIC := 0;
    v_data_overage      NUMERIC := 0;
    v_sms_overage       NUMERIC := 0;
    v_old_ror_voice     NUMERIC;
    v_old_ror_data      NUMERIC;
    v_old_ror_sms       NUMERIC;
    v_prorated_charge   NUMERIC := 0;
    v_recurring_fees    NUMERIC;
    v_prorated_recurring NUMERIC;
    v_taxes             NUMERIC;
    v_total             NUMERIC;
    v_bill_id           INTEGER;
BEGIN
    -- Load contract
SELECT * INTO v_contract FROM contract WHERE id = p_contract_id;
IF NOT FOUND THEN
        RAISE EXCEPTION 'Contract with id % does not exist', p_contract_id;
END IF;

    IF v_contract.status != 'active' THEN
        RAISE EXCEPTION 'Contract % is not active, cannot change rateplan', p_contract_id;
END IF;

    IF NOT EXISTS (SELECT 1 FROM rateplan WHERE id = p_new_rateplan_id) THEN
        RAISE EXCEPTION 'Rateplan with id % does not exist', p_new_rateplan_id;
END IF;

    IF v_contract.rateplan_id = p_new_rateplan_id THEN
        RAISE EXCEPTION 'Contract % is already on rateplan %', p_contract_id, p_new_rateplan_id;
END IF;

    v_old_rateplan_id := v_contract.rateplan_id;

    -- --------------------------------------------------------
    -- DAY CALCULATIONS
    -- v_days_used      = how many days the old plan was active
    -- v_days_in_month  = total days in the current month
    -- v_days_remaining = days left for the new plan
    -- v_usage_ratio    = days_used / days_in_month (e.g. 0.5 on day 15 of 30)
    -- --------------------------------------------------------
    v_period_start   := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_period_end     := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    v_change_day     := EXTRACT(DAY FROM CURRENT_DATE);
    v_days_in_month  := EXTRACT(DAY FROM v_period_end);
    v_days_used      := v_change_day - 1;   -- days 1 through yesterday were fully used
    v_days_remaining := v_days_in_month - v_days_used;
    v_usage_ratio    := v_days_used::NUMERIC / v_days_in_month::NUMERIC;

    -- --------------------------------------------------------
    -- PRORATION CHECK
    -- Prorate if ANY bundle consumption percentage exceeds
    -- the day-based fair share percentage
    --
    -- fair_share_pct = (days_used / days_in_month) * 100
    -- consumed_pct   = (consumed / bundle_amount)  * 100
    --
    -- if consumed_pct > fair_share_pct → prorate
    -- --------------------------------------------------------
FOR v_bundle IN
SELECT
    cc.consumed,
    sp.amount,
    sp.type
FROM contract_consumption cc
         JOIN service_package sp ON sp.id = cc.service_package_id
WHERE cc.contract_id   = p_contract_id
  AND cc.rateplan_id   = v_old_rateplan_id
  AND cc.starting_date = v_period_start
  AND cc.ending_date   = v_period_end
  AND cc.is_billed     = FALSE
  AND sp.type         != 'free_units'
          AND sp.amount        > 0
    LOOP
        -- consumed% exceeds what is proportionally fair for the days elapsed
        IF (v_bundle.consumed::NUMERIC / v_bundle.amount::NUMERIC) > v_usage_ratio THEN
            v_should_prorate := TRUE;
EXIT;
END IF;
END LOOP;

    -- --------------------------------------------------------
    -- PRORATED BILLING
    -- Charge for:
    --   1. Recurring fee prorated to days used
    --   2. Excess usage above the day-proportional fair share,
    --      rated at old rateplan ROR
    -- --------------------------------------------------------
    IF v_should_prorate THEN

SELECT ror_voice, ror_data, ror_sms, price
INTO v_old_ror_voice, v_old_ror_data, v_old_ror_sms, v_recurring_fees
FROM rateplan
WHERE id = v_old_rateplan_id;

-- Recurring fee = full price × (days used / days in month)
v_prorated_recurring := ROUND(v_recurring_fees * v_usage_ratio, 2);

        -- Calculate excess per service type
FOR v_bundle IN
SELECT
    cc.consumed,
    sp.amount,
    sp.type
FROM contract_consumption cc
         JOIN service_package sp ON sp.id = cc.service_package_id
WHERE cc.contract_id   = p_contract_id
  AND cc.rateplan_id   = v_old_rateplan_id
  AND cc.starting_date = v_period_start
  AND cc.ending_date   = v_period_end
  AND cc.is_billed     = FALSE
  AND sp.type         != 'free_units'
        LOOP
DECLARE
v_fair_share  NUMERIC;
                v_excess      NUMERIC;
BEGIN
                -- Fair share = what they should have used by this day
                v_fair_share := v_bundle.amount * v_usage_ratio;
                v_excess     := GREATEST(v_bundle.consumed - v_fair_share, 0);

CASE v_bundle.type
                    WHEN 'voice' THEN v_voice_overage := v_voice_overage + v_excess;
WHEN 'data'  THEN v_data_overage  := v_data_overage  + v_excess;
WHEN 'sms'   THEN v_sms_overage   := v_sms_overage   + v_excess;
ELSE NULL;
END CASE;
END;
END LOOP;

        -- Excess units × old ROR rates (Adjust for raw units: Seconds -> Mins, Bytes -> GB)
        v_prorated_charge :=
            ( (v_voice_overage / 60.0) * COALESCE(v_old_ror_voice, 0) ) +
            ( (v_data_overage / 1073741824.0) * COALESCE(v_old_ror_data,  0) ) +
            ( (v_sms_overage)   * COALESCE(v_old_ror_sms,   0) );

        v_taxes := ROUND(0.10 * (v_prorated_recurring + v_prorated_charge), 2);
        v_total := v_prorated_recurring + v_prorated_charge + v_taxes;

        -- Insert prorated bill
INSERT INTO bill (
    contract_id,
    billing_period_start,
    billing_period_end,
    billing_date,
    recurring_fees,
    one_time_fees,
    voice_usage,
    data_usage,
    sms_usage,
    ror_charge,
    taxes,
    total_amount,
    status,
    is_paid
) VALUES (
             p_contract_id,
             v_period_start,
             CURRENT_DATE,
             CURRENT_DATE,
             v_prorated_recurring,
             0,
             v_voice_overage,
             v_data_overage,
             v_sms_overage,
             v_prorated_charge,
             v_taxes,
             v_total,
             'issued',
             FALSE
         )
    RETURNING id INTO v_bill_id;

-- Mark old consumption rows as billed
UPDATE contract_consumption
SET is_billed = TRUE,
    bill_id   = v_bill_id
WHERE contract_id   = p_contract_id
  AND rateplan_id   = v_old_rateplan_id
  AND starting_date = v_period_start
  AND ending_date   = v_period_end;

-- Link old ror_contract row to this bill
UPDATE ror_contract
SET bill_id = v_bill_id
WHERE contract_id = p_contract_id
  AND rateplan_id = v_old_rateplan_id
  AND bill_id IS NULL;

ELSE
        -- No proration: close old consumption silently
UPDATE contract_consumption
SET is_billed = TRUE
WHERE contract_id   = p_contract_id
  AND rateplan_id   = v_old_rateplan_id
  AND starting_date = v_period_start
  AND ending_date   = v_period_end
  AND is_billed     = FALSE;
END IF;

    -- --------------------------------------------------------
    -- SWITCH TO NEW RATEPLAN
    -- --------------------------------------------------------
UPDATE contract
SET rateplan_id = p_new_rateplan_id
WHERE id = p_contract_id;

-- Fresh ror_contract row for new rateplan
INSERT INTO ror_contract (contract_id, rateplan_id, voice, data, sms)
VALUES (p_contract_id, p_new_rateplan_id, 0, 0, 0)
    ON CONFLICT DO NOTHING;

-- Fresh consumption rows for new rateplan starting today
INSERT INTO contract_consumption (
    contract_id,
    service_package_id,
    rateplan_id,
    starting_date,
    ending_date,
    consumed,
    is_billed
)
SELECT
    p_contract_id,
    rsp.service_package_id,
    p_new_rateplan_id,
    CURRENT_DATE,
    v_period_end,
    0,
    FALSE
FROM rateplan_service_package rsp
WHERE rsp.rateplan_id = p_new_rateplan_id
    ON CONFLICT DO NOTHING;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'change_contract_rateplan failed for contract %: %',
                        p_contract_id, SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION change_contract_status(
    p_contract_id INTEGER,
    p_status      contract_status
)
    RETURNS VOID AS $$
DECLARE
    v_msisdn VARCHAR(20);
BEGIN
    SELECT msisdn INTO v_msisdn
    FROM contract WHERE id = p_contract_id;

    UPDATE contract SET status = p_status WHERE id = p_contract_id;

    IF p_status = 'terminated' THEN
        PERFORM release_msisdn(v_msisdn);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_admin(
    p_username  VARCHAR(255),
    p_password  VARCHAR(30),
    p_name      VARCHAR(255),
    p_email     VARCHAR(255),
    p_address   TEXT,
    p_birthdate DATE
)
RETURNS INTEGER AS $$
DECLARE
v_new_id INTEGER;
BEGIN
INSERT INTO user_account (username, password, role, name, email, address, birthdate)
VALUES (p_username, p_password, 'admin', p_name, p_email, p_address, p_birthdate)
    RETURNING id INTO v_new_id;
RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_contract(
    p_user_account_id INTEGER,
    p_rateplan_id INTEGER,
    p_msisdn VARCHAR(20),
    p_credit_limit DOUBLE PRECISION
)
RETURNS INTEGER AS $$
DECLARE v_contract_id INTEGER;
    v_period_start DATE;
    v_period_end DATE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_account WHERE id = p_user_account_id) THEN
        RAISE EXCEPTION 'Customer with id % does not exist', p_user_account_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM rateplan WHERE id = p_rateplan_id) THEN
        RAISE EXCEPTION 'Rateplan with id % does not exist', p_rateplan_id;
    END IF;

    IF EXISTS (SELECT 1 FROM contract WHERE msisdn = p_msisdn) THEN
        RAISE EXCEPTION 'MSISDN % is already assigned', p_msisdn;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM msisdn_pool WHERE msisdn = p_msisdn AND is_available = TRUE) THEN
        RAISE EXCEPTION 'MSISDN % is not available', p_msisdn;
    END IF;

    INSERT INTO contract (user_account_id, rateplan_id, msisdn, status, credit_limit, available_credit)
    VALUES (p_user_account_id, p_rateplan_id, p_msisdn, 'active', p_credit_limit::NUMERIC, p_credit_limit::NUMERIC)
    RETURNING id INTO v_contract_id;

    PERFORM mark_msisdn_taken(p_msisdn);

    INSERT INTO ror_contract (contract_id, rateplan_id, voice, data, sms)
    VALUES (v_contract_id, p_rateplan_id, 0, 0, 0);

    v_period_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_period_end := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;

    INSERT INTO contract_consumption (
        contract_id, service_package_id, rateplan_id, starting_date, ending_date, consumed, quota_limit, is_billed
    )
    SELECT v_contract_id, rsp.service_package_id, p_rateplan_id, v_period_start, v_period_end, 0, sp.amount, FALSE
    FROM rateplan_service_package rsp
    JOIN service_package sp ON rsp.service_package_id = sp.id
    WHERE rsp.rateplan_id = p_rateplan_id
    ON CONFLICT DO NOTHING;

    RETURN v_contract_id;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'create_contract failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_customer(
    p_username VARCHAR(255),
    p_password VARCHAR(30),
    p_name VARCHAR(255),
    p_email VARCHAR(255),
    p_address TEXT,
    p_birthdate DATE
) RETURNS INTEGER AS $$
DECLARE v_new_id INTEGER;
BEGIN
    INSERT INTO user_account (username, password, role, name, email, address, birthdate)
    VALUES (p_username, p_password, 'customer', p_name, p_email, p_address, p_birthdate)
    RETURNING id INTO v_new_id;
    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_file_record(p_file_path TEXT)
RETURNS INTEGER AS $$
DECLARE v_new_id INTEGER;
BEGIN
    INSERT INTO file (file_path) VALUES (p_file_path)
    RETURNING id INTO v_new_id;
    RETURN v_new_id;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'create_file_record failed for file path %: %', p_file_path, SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_rateplan_with_packages(
    p_name VARCHAR(255), p_ror_voice NUMERIC(15,2), p_ror_data NUMERIC(15,2),
    p_ror_sms NUMERIC(15,2), p_price NUMERIC(15,2), p_package_ids INTEGER[],
    p_type billing_type DEFAULT 'POSTPAID'
) RETURNS TABLE(id INTEGER, name VARCHAR(255)) AS $$
DECLARE v_rateplan_id INTEGER;
    v_package_id INTEGER;
BEGIN
    INSERT INTO rateplan (name, ror_voice, ror_data, ror_sms, price, type)
    VALUES (p_name, p_ror_voice, p_ror_data, p_ror_sms, p_price, p_type)
    RETURNING rateplan.id INTO v_rateplan_id;
    
    IF p_package_ids IS NOT NULL THEN
        FOREACH v_package_id IN ARRAY p_package_ids LOOP
            INSERT INTO rateplan_service_package (rateplan_id, service_package_id)
            VALUES (v_rateplan_id, v_package_id);
        END LOOP;
    END IF;

    RETURN QUERY SELECT v_rateplan_id, p_name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_service_package(
    p_name        VARCHAR(255),
    p_type        service_type,
    p_amount      NUMERIC(12,4),
    p_priority    INTEGER,
    p_price       NUMERIC(15,2),
    p_description TEXT,
    p_is_roaming  BOOLEAN DEFAULT FALSE
)
    RETURNS TABLE (
                      id          INTEGER,
                      name        VARCHAR(255),
                      type        service_type,
                      amount      NUMERIC(12,4),
                      priority    INTEGER,
                      price       NUMERIC(15,2),
                      description TEXT,
                      is_roaming  BOOLEAN
                  ) AS $$
BEGIN
    RETURN QUERY
        INSERT INTO service_package (name, type, amount, priority, price, description, is_roaming)
            VALUES (p_name, p_type, p_amount, p_priority, p_price, p_description, p_is_roaming)
            RETURNING
                service_package.id,
                service_package.name,
                service_package.type,
                service_package.amount,
                service_package.priority,
                service_package.price,
                service_package.description,
                service_package.is_roaming;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_rateplan(p_rateplan_id INTEGER) RETURNS VOID AS $$
BEGIN
    DELETE FROM rateplan_service_package WHERE rateplan_id = p_rateplan_id;
    DELETE FROM rateplan WHERE id = p_rateplan_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_service_package(p_id INTEGER) 
RETURNS VOID AS $$
BEGIN
    DELETE FROM service_package WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION expire_addons()
RETURNS VOID AS $$
BEGIN
    UPDATE contract_addon 
    SET is_active = FALSE 
    WHERE expiry_date < CURRENT_DATE AND is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_all_bills(p_period_start DATE)
RETURNS VOID AS $$
DECLARE v_contract RECORD;
    v_success INTEGER := 0;
    v_failed INTEGER := 0;
BEGIN
    PERFORM expire_addons();

    FOR v_contract IN
        SELECT id FROM contract 
        WHERE status IN ('active', 'suspended', 'suspended_debt')
          AND id NOT IN (SELECT contract_id FROM bill WHERE billing_period_start = p_period_start)
    LOOP
        BEGIN
            PERFORM generate_bill(v_contract.id, p_period_start);
            v_success := v_success + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'generate_bill failed for contract %: %', v_contract.id, SQLERRM;
            v_failed := v_failed + 1;
        END;
    END LOOP;

    RAISE NOTICE 'generate_all_bills complete: % succeeded, % failed', v_success, v_failed;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_bill(p_contract_id INTEGER, p_billing_period_start DATE)
RETURNS INTEGER AS $$
DECLARE
    v_billing_period_end DATE;
    v_recurring_fees NUMERIC(15,2);
    v_voice_usage BIGINT;
    v_data_usage BIGINT;
    v_sms_usage BIGINT;
    v_overage_charge NUMERIC(15,2);
    v_roaming_charge NUMERIC(15,2);
    v_one_time_fees NUMERIC(15,2);
    v_promo_discount NUMERIC(15,2) := 0;
    v_taxes NUMERIC(15,2);
    v_subtotal NUMERIC(15,2);
    v_total_amount NUMERIC(15,2);
    v_rateplan_id INTEGER;
    v_bill_id INTEGER;
    v_msisdn VARCHAR;
BEGIN
    v_billing_period_end := (DATE_TRUNC('month', p_billing_period_start) + INTERVAL '1 month - 1 day')::DATE;
    SELECT rateplan_id, msisdn INTO v_rateplan_id, v_msisdn FROM contract WHERE id = p_contract_id;
    
    SELECT price INTO v_recurring_fees FROM rateplan WHERE id = v_rateplan_id;

    -- Calculate Raw Usage Totals from Consumption table
    SELECT
        COALESCE(SUM(CASE WHEN sp.type::TEXT = 'voice' THEN cc.consumed ELSE 0 END), 0)::BIGINT,
        COALESCE(SUM(CASE WHEN sp.type::TEXT = 'data' THEN cc.consumed ELSE 0 END), 0)::BIGINT,
        COALESCE(SUM(CASE WHEN sp.type::TEXT = 'sms' THEN cc.consumed ELSE 0 END), 0)::BIGINT
    INTO v_voice_usage, v_data_usage, v_sms_usage
    FROM contract_consumption cc
    JOIN service_package sp ON cc.service_package_id = sp.id
    WHERE cc.contract_id = p_contract_id AND cc.starting_date = p_billing_period_start;

    -- Add domestic and roaming overage to the total usage counts for the bill display
    SELECT 
        v_voice_usage + COALESCE(SUM(voice + roaming_voice), 0),
        v_data_usage + COALESCE(SUM(data + roaming_data), 0),
        v_sms_usage + COALESCE(SUM(sms + roaming_sms), 0)
    INTO v_voice_usage, v_data_usage, v_sms_usage
    FROM ror_contract
    WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start AND bill_id IS NULL;

    -- PRECISION FIX: Calculate charges directly from Rated CDRs
    SELECT 
        COALESCE(SUM(CASE WHEN (vplmn IS NOT NULL AND vplmn != '' AND vplmn != hplmn) THEN cost ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN (vplmn IS NULL OR vplmn = '' OR vplmn = hplmn) THEN cost ELSE 0 END), 0)
    INTO v_roaming_charge, v_overage_charge
    FROM cdr 
    WHERE dial_a = v_msisdn 
      AND DATE_TRUNC('month', start_time)::DATE = p_billing_period_start
      AND bill_id IS NULL
      AND rated_flag = TRUE;

    -- Calculate one-time fees
    SELECT COALESCE(SUM(amount), 0) INTO v_one_time_fees
    FROM onetime_fee
    WHERE contract_id = p_contract_id AND bill_id IS NULL;

    -- Financial Math Section
    v_subtotal := v_recurring_fees + v_overage_charge + v_roaming_charge + v_one_time_fees - v_promo_discount;
    v_taxes := ROUND(0.14 * v_subtotal, 2);
    v_total_amount := v_subtotal + v_taxes;

    INSERT INTO bill (
        contract_id, billing_period_start, billing_period_end, billing_date,
        recurring_fees, one_time_fees, voice_usage, data_usage, sms_usage,
        overage_charge, roaming_charge, promotional_discount, taxes, 
        total_amount, subtotal, tax_total, overage_total, roaming_total, status
    ) VALUES (
        p_contract_id, p_billing_period_start, v_billing_period_end, CURRENT_DATE,
        v_recurring_fees, v_one_time_fees, v_voice_usage, v_data_usage, v_sms_usage,
        v_overage_charge, v_roaming_charge, v_promo_discount, v_taxes, 
        v_total_amount, v_subtotal, v_taxes, v_overage_charge, v_roaming_charge, 'issued'
    ) RETURNING id INTO v_bill_id;

    -- Linkage Updates
    UPDATE ror_contract SET bill_id = v_bill_id WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start AND bill_id IS NULL;
    UPDATE cdr SET bill_id = v_bill_id WHERE dial_a = v_msisdn AND DATE_TRUNC('month', start_time)::DATE = p_billing_period_start AND bill_id IS NULL AND rated_flag = TRUE;
    UPDATE contract_consumption SET bill_id = v_bill_id, is_billed = TRUE WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start;
    UPDATE onetime_fee SET bill_id = v_bill_id WHERE contract_id = p_contract_id AND bill_id IS NULL;

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
    id INTEGER, contract_id INTEGER, billing_date DATE,
    billing_period_start DATE, billing_period_end DATE,
    total_amount NUMERIC(15,2), is_paid BOOLEAN, status VARCHAR(20),
    voice_usage BIGINT, data_usage BIGINT, sms_usage BIGINT,
    customer_name VARCHAR(255), msisdn VARCHAR(20), total_count BIGINT,
    subscription_fee NUMERIC(15,2), tax_amount NUMERIC(15,2),
    overage_amount NUMERIC(15,2), roaming_amount NUMERIC(15,2)
) AS $$
DECLARE v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM bill b
    JOIN contract c ON b.contract_id = c.id
    JOIN user_account ua ON c.user_account_id = ua.id
    WHERE (p_search IS NULL OR p_search = '' OR
           ua.name ILIKE '%' || p_search || '%' OR
           c.msisdn ILIKE '%' || p_search || '%' OR
           b.status::TEXT ILIKE '%' || p_search || '%');

    RETURN QUERY
    SELECT b.id, b.contract_id, b.billing_date, b.billing_period_start, b.billing_period_end,
           b.total_amount, b.is_paid, b.status::VARCHAR(20),
           b.voice_usage, b.data_usage, b.sms_usage,
           ua.name, c.msisdn, v_total,
           b.recurring_fees, b.taxes, b.overage_charge, b.roaming_charge
    FROM bill b
    JOIN contract c ON b.contract_id = c.id
    JOIN user_account ua ON c.user_account_id = ua.id
    WHERE (p_search IS NULL OR p_search = '' OR
           ua.name ILIKE '%' || p_search || '%' OR
           c.msisdn ILIKE '%' || p_search || '%' OR
           b.status::TEXT ILIKE '%' || p_search || '%')
    ORDER BY b.billing_period_start DESC, b.id DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_contracts(p_search TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    id INTEGER, msisdn VARCHAR(20), status contract_status,
    available_credit NUMERIC(15,2), customer_name VARCHAR(255),
    rateplan_name VARCHAR(255), total_count BIGINT
) AS $$
DECLARE v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM contract c
    JOIN user_account u ON c.user_account_id = u.id
    LEFT JOIN rateplan r ON c.rateplan_id = r.id
    WHERE (p_search IS NULL OR p_search = '' OR
           c.msisdn ILIKE '%' || p_search || '%' OR
           u.name ILIKE '%' || p_search || '%' OR
           r.name ILIKE '%' || p_search || '%');

    RETURN QUERY
    SELECT c.id, c.msisdn, c.status, c.available_credit, u.name, r.name, v_total
    FROM contract c
    JOIN user_account u ON c.user_account_id = u.id
    LEFT JOIN rateplan r ON c.rateplan_id = r.id
    WHERE (p_search IS NULL OR p_search = '' OR
           c.msisdn ILIKE '%' || p_search || '%' OR
           u.name ILIKE '%' || p_search || '%' OR
           r.name ILIKE '%' || p_search || '%')
    ORDER BY c.id DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_customers(p_search TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    id INTEGER, username VARCHAR(255), name VARCHAR(255), email VARCHAR(255),
    role user_role, address TEXT, birthdate DATE, msisdn VARCHAR(20), total_count BIGINT
) AS $$
DECLARE v_total BIGINT;
BEGIN
    SELECT COUNT(DISTINCT ua.id) INTO v_total
    FROM user_account ua
    LEFT JOIN contract c ON ua.id = c.user_account_id
    WHERE ua.role = 'customer'
      AND (p_search IS NULL OR p_search = '' OR
           ua.name ILIKE '%' || p_search || '%' OR
           ua.email ILIKE '%' || p_search || '%' OR
           c.msisdn ILIKE '%' || p_search || '%');

    RETURN QUERY
    SELECT DISTINCT ON (ua.id) ua.id, ua.username, ua.name, ua.email, ua.role, ua.address, ua.birthdate, c.msisdn, v_total
    FROM user_account ua
    LEFT JOIN contract c ON ua.id = c.user_account_id
    WHERE ua.role = 'customer'
      AND (p_search IS NULL OR p_search = '' OR
           ua.name ILIKE '%' || p_search || '%' OR
           ua.email ILIKE '%' || p_search || '%' OR
           c.msisdn ILIKE '%' || p_search || '%')
    ORDER BY ua.id DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_rateplans()
    RETURNS TABLE (
                      id        INTEGER,
                      name      VARCHAR(255),
                      price     NUMERIC(15,2),
                      ror_voice NUMERIC(15,2),
                      ror_data  NUMERIC(15,2),
                      ror_sms   NUMERIC(15,2)
                  ) AS $$
BEGIN
    RETURN QUERY
        SELECT
            r.id,
            r.name,
            r.price,
            r.ror_voice,
            r.ror_data,
            r.ror_sms
        FROM rateplan "r"
        ORDER BY r.price ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_service_packages()
    RETURNS TABLE (
        id          INTEGER,
        name        VARCHAR(255),
        type        service_type,
        amount      NUMERIC(12,4),
        priority    INTEGER,
        price       NUMERIC(15,2),
        description TEXT,
        is_roaming  BOOLEAN
    ) AS $$
BEGIN
    RETURN QUERY
        SELECT sp.id, sp.name, sp.type, sp.amount, sp.priority, sp.price, sp.description, sp.is_roaming
        FROM service_package sp
        ORDER BY sp.type, sp.priority ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_available_msisdns()
    RETURNS TABLE (
                      id     INTEGER,
                      msisdn VARCHAR(20)
                  ) AS $$
BEGIN
    RETURN QUERY
        SELECT mp.id, mp.msisdn
        FROM msisdn_pool mp
        WHERE mp.is_available = TRUE
        ORDER BY mp.msisdn;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_bill(p_bill_id INTEGER)
RETURNS TABLE (
    contract_id INTEGER,
    billing_period_start DATE,
    billing_period_end DATE,
    billing_date DATE,
    recurring_fees NUMERIC(15,2),
    one_time_fees NUMERIC(15,2),
    voice_usage INTEGER,
    data_usage INTEGER,
    sms_usage INTEGER,
    ROR_charge NUMERIC(15,2),
    taxes NUMERIC(15,2),
    total_amount NUMERIC(15,2),
    status bill_status,
    is_paid BOOLEAN
) AS $$
BEGIN
RETURN QUERY
SELECT
    b.contract_id,
    b.billing_period_start,
    b.billing_period_end,
    b.billing_date,
    b.recurring_fees,
    b.one_time_fees,
    b.voice_usage,
    b.data_usage,
    b.sms_usage,
    b.ROR_charge,
    b.taxes,
    b.total_amount,
    b.status,
    b.is_paid
FROM bill b
WHERE b.id = p_bill_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_bill_usage_breakdown(p_bill_id INTEGER)
RETURNS TABLE (
    service_type TEXT,
    category_label TEXT,
    quota_raw BIGINT,
    consumed_raw BIGINT,
    quota_display NUMERIC(15,2),
    consumed_display NUMERIC(15,2),
    unit_label TEXT,
    unit_rate NUMERIC(15,4),
    line_total NUMERIC(15,2),
    is_roaming BOOLEAN,
    is_promotional BOOLEAN,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- 1. Bundled Packages (Included in Monthly Fee)
    SELECT 
        COALESCE(sp.type::TEXT, 'unknown'), 
        COALESCE(sp.name::TEXT, 'Standard Package'),
        COALESCE(cc.quota_limit, 0)::BIGINT, 
        COALESCE(cc.consumed, 0)::BIGINT,
        CASE 
            WHEN sp.type::TEXT ILIKE '%voice%' THEN ROUND(COALESCE(cc.quota_limit, 0) / 60.0, 2)
            WHEN sp.type::TEXT ILIKE '%data%' OR (sp.type::TEXT = 'free_units' AND cc.quota_limit > 1000000) THEN ROUND(COALESCE(cc.quota_limit, 0) / 1073741824.0, 2)
            ELSE COALESCE(cc.quota_limit, 0)::NUMERIC(15,2)
        END,
        CASE 
            WHEN sp.type::TEXT ILIKE '%voice%' THEN ROUND(COALESCE(cc.consumed, 0) / 60.0, 2)
            WHEN sp.type::TEXT ILIKE '%data%' OR (sp.type::TEXT = 'free_units' AND cc.quota_limit > 1000000) THEN ROUND(COALESCE(cc.consumed, 0) / 1073741824.0, 2)
            ELSE COALESCE(cc.consumed, 0)::NUMERIC(15,2)
        END,
        CASE 
            WHEN sp.type::TEXT ILIKE '%voice%' THEN 'min'::TEXT
            WHEN sp.type::TEXT ILIKE '%data%' OR (sp.type::TEXT = 'free_units' AND cc.quota_limit > 1000000) THEN 'GB'::TEXT
            WHEN sp.type::TEXT ILIKE '%sms%' THEN 'SMS'::TEXT
            ELSE 'units'::TEXT
        END,
        0::NUMERIC(15,4), 
        0::NUMERIC(15,2),
        COALESCE(sp.is_roaming, FALSE),
        (COALESCE(sp.name, '') ~* 'Welcome|Gift|Bonus')::BOOLEAN,
        CASE 
            WHEN COALESCE(cc.consumed, 0) >= COALESCE(cc.quota_limit, 0) THEN 'Bundle fully utilized'::TEXT
            WHEN COALESCE(cc.consumed, 0) = 0 THEN 'No usage recorded'::TEXT
            ELSE 'Partial bundle usage'::TEXT
        END
    FROM contract_consumption cc
    JOIN service_package sp ON cc.service_package_id = sp.id
    WHERE cc.bill_id = p_bill_id
    
    UNION ALL
    
    -- 2. Overage Calculations (Domestic)
    SELECT 
        CASE 
            WHEN service_id = 2 THEN 'data'::TEXT
            WHEN service_id = 1 THEN 'voice'::TEXT
            WHEN service_id = 3 THEN 'sms'::TEXT
            ELSE 'usage'::TEXT
        END, 
        'Domestic Overage (' || 
        CASE 
            WHEN service_id = 2 THEN 'Data'::TEXT
            WHEN service_id = 1 THEN 'Voice'::TEXT
            WHEN service_id = 3 THEN 'SMS'::TEXT
            ELSE 'Units'::TEXT
        END || ')', 
        0::BIGINT, 
        SUM(duration)::BIGINT,
        0::NUMERIC, 
        CASE 
            WHEN service_id = 1 THEN ROUND(SUM(duration) / 60.0, 2)
            WHEN service_id = 2 THEN ROUND(SUM(duration) / 1073741824.0, 2)
            ELSE SUM(duration)::NUMERIC(15,2)
        END, 
        CASE 
            WHEN service_id = 1 THEN 'min'::TEXT
            WHEN service_id = 2 THEN 'GB'::TEXT
            WHEN service_id = 3 THEN 'SMS'::TEXT
            ELSE 'units'::TEXT
        END, 
        NULL::NUMERIC,
        SUM(cost)::NUMERIC(15,2),
        FALSE, 
        FALSE, 
        'Rated Domestic Overage'::TEXT
    FROM cdr
    WHERE bill_id = p_bill_id AND rated_flag = TRUE AND (vplmn IS NULL OR vplmn = '' OR vplmn = hplmn) AND cost > 0
    GROUP BY service_id
    
    UNION ALL
    
    -- 3. Roaming Calculations
    SELECT 
        CASE 
            WHEN service_id = 2 THEN 'data'::TEXT
            WHEN service_id = 1 THEN 'voice'::TEXT
            WHEN service_id = 3 THEN 'sms'::TEXT
            ELSE 'roaming'::TEXT
        END, 
        'International Roaming (' || 
        CASE 
            WHEN service_id = 2 THEN 'Data'::TEXT
            WHEN service_id = 1 THEN 'Voice'::TEXT
            WHEN service_id = 3 THEN 'SMS'::TEXT
            ELSE 'Units'::TEXT
        END || ')', 
        0::BIGINT, 
        SUM(duration)::BIGINT,
        0::NUMERIC, 
        CASE 
            WHEN service_id = 1 THEN ROUND(SUM(duration) / 60.0, 2)
            WHEN service_id = 2 THEN ROUND(SUM(duration) / 1073741824.0, 2)
            ELSE SUM(duration)::NUMERIC(15,2)
        END, 
        CASE 
            WHEN service_id = 1 THEN 'min'::TEXT
            WHEN service_id = 2 THEN 'GB'::TEXT
            WHEN service_id = 3 THEN 'SMS'::TEXT
            ELSE 'units'::TEXT
        END, 
        NULL::NUMERIC,
        SUM(cost)::NUMERIC(15,2),
        TRUE, 
        FALSE, 
        'International Roaming'::TEXT
    FROM cdr
    WHERE bill_id = p_bill_id AND rated_flag = TRUE AND (vplmn IS NOT NULL AND vplmn != '' AND vplmn != hplmn) AND cost > 0
    GROUP BY service_id

    UNION ALL

    -- 4. One-time Fees (Administrative / Service Fees)
    SELECT 
        'fee'::TEXT, 
        COALESCE(description, fee_type::TEXT), 
        0::BIGINT, 
        1::BIGINT,
        0::NUMERIC, 
        1::NUMERIC(15,2), 
        'item'::TEXT, 
        amount::NUMERIC(15,4),
        amount::NUMERIC(15,2),
        FALSE, 
        FALSE, 
        'One-time Fee'::TEXT
    FROM onetime_fee
    WHERE bill_id = p_bill_id
    
    ORDER BY 1, 10 DESC, 2;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_bills_by_contract(p_contract_id INTEGER)
       RETURNS TABLE (
    id INTEGER,
    billing_period_start DATE,
    billing_period_end DATE,
    billing_date DATE,
    total_amount NUMERIC(15,2),
    status bill_status
) AS $$
BEGIN
RETURN QUERY
SELECT b.id, b.billing_period_start, b.billing_period_end, b.billing_date, b.total_amount, b.status
FROM bill b WHERE b.contract_id = p_contract_id
ORDER BY b.billing_period_start DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_cdr_usage_amount(
    p_duration BIGINT,
    p_service_type service_type
)
RETURNS BIGINT AS $$
BEGIN
    RETURN CASE p_service_type
        WHEN 'voice' THEN p_duration
        WHEN 'data' THEN p_duration
        WHEN 'sms' THEN 1
        WHEN 'free_units' THEN p_duration
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_cdrs(p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    id INTEGER,
    msisdn VARCHAR,
    destination VARCHAR,
    duration BIGINT,
    "timestamp" TIMESTAMP,
    rated BOOLEAN,
    type VARCHAR,
    service_id INTEGER,
    service_type TEXT,
    cost NUMERIC(15,2),
    hplmn VARCHAR,
    vplmn VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id, c.dial_a, c.dial_b, c.duration, c.start_time, c.rated_flag,
        COALESCE(sp_rated.name, sp_base.name, 'Unrated')::VARCHAR,
        COALESCE(c.rated_service_id, c.service_id),
        CASE 
            WHEN sp_rated.type IS NOT NULL THEN sp_rated.type::TEXT
            WHEN sp_base.type IS NOT NULL THEN sp_base.type::TEXT
            WHEN c.dial_b = 'internet' THEN 'data'
            WHEN c.dial_b ~ '^[0-9]+$' AND c.duration = 1 THEN 'sms'
            WHEN c.dial_b ~ '^[0-9]+$' THEN 'voice'
            ELSE 'other'
        END::TEXT,
        c.cost,
        c.hplmn,
        c.vplmn
    FROM cdr c
    LEFT JOIN service_package sp_rated ON c.rated_service_id = sp_rated.id
    LEFT JOIN service_package sp_base ON c.service_id = sp_base.id
    ORDER BY c.start_time DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_contract_addons(p_contract_id INTEGER)
    RETURNS TABLE (
                      id                 INTEGER,
                      service_package_id INTEGER,
                      package_name       VARCHAR(255),
                      type               service_type,
                      amount             NUMERIC(12,4),
                      purchased_date     DATE,
                      expiry_date        DATE,
                      price_paid         NUMERIC(15,2),
                      is_active          BOOLEAN
                  ) AS $$
BEGIN
    RETURN QUERY
        SELECT ca.id, ca.service_package_id, sp.name, sp.type, sp.amount,
               ca.purchased_date, ca.expiry_date, ca.price_paid, ca.is_active
        FROM contract_addon ca
        JOIN service_package sp ON sp.id = ca.service_package_id
        WHERE ca.contract_id = p_contract_id
        ORDER BY ca.purchased_date DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_contract_by_id(p_id INTEGER)
    RETURNS TABLE (
                      id               INTEGER,
                      user_account_id  INTEGER,
                      rateplan_id      INTEGER,
                      msisdn           VARCHAR(20),
                      status           contract_status,
                      credit_limit     NUMERIC(15,2),
                      available_credit NUMERIC(15,2),
                      customer_name    VARCHAR(255),
                      rateplan_name    VARCHAR(255)
                  ) AS $$
BEGIN
    RETURN QUERY
        SELECT
            c.id,
            c.user_account_id,
            c.rateplan_id,
            c.msisdn,
            c.status,
            c.credit_limit,
            c.available_credit,
            u.name AS customer_name,
            r.name AS rateplan_name
        FROM contract c
                 JOIN user_account u ON c.user_account_id = u.id
                 LEFT JOIN rateplan r ON c.rateplan_id = r.id
        WHERE c.id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_contract_consumption(p_contract_id INTEGER, p_period_start DATE)
       RETURNS TABLE (
    service_package_id INTEGER,
    consumed INTEGER
) AS $$
BEGIN
RETURN QUERY
SELECT cc.service_package_id, cc.consumed
FROM contract_consumption cc
WHERE cc.contract_id = p_contract_id
  AND cc.starting_date = p_period_start
  AND cc.is_billed = FALSE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_customer_by_id(p_id INTEGER)
RETURNS TABLE (
    id INTEGER, username VARCHAR(255), name VARCHAR(255), email VARCHAR(255),
    role user_role, address TEXT, birthdate DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT ua.id, ua.username, ua.name, ua.email, ua.role, ua.address, ua.birthdate
    FROM user_account ua
    WHERE ua.id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS TABLE (
    total_customers BIGINT,
    total_contracts BIGINT,
    active_contracts BIGINT,
    suspended_contracts BIGINT,
    suspended_debt_contracts BIGINT,
    terminated_contracts BIGINT,
    total_cdrs BIGINT,
    revenue NUMERIC(15,2),
    pending_bills BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM user_account WHERE role = 'customer'),
        (SELECT COUNT(*) FROM contract),
        (SELECT COUNT(*) FROM contract WHERE status = 'active'),
        (SELECT COUNT(*) FROM contract WHERE status = 'suspended'),
        (SELECT COUNT(*) FROM contract WHERE status = 'suspended_debt'),
        (SELECT COUNT(*) FROM contract WHERE status = 'terminated'),
        (SELECT COUNT(*) FROM cdr),
        (SELECT COALESCE(SUM(total_amount), 0) FROM bill WHERE status IN ('issued', 'paid')),
        (SELECT COUNT(*) FROM bill WHERE status = 'issued');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_missing_bills(p_search TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    contract_id INTEGER,
    msisdn VARCHAR(20),
    customer_name VARCHAR(255),
    rateplan_name VARCHAR(255),
    last_bill_date DATE,
    total_count BIGINT
) AS $$
DECLARE
    v_period_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM contract c
    JOIN user_account u ON c.user_account_id = u.id
    LEFT JOIN rateplan r ON c.rateplan_id = r.id
    WHERE c.status IN ('active', 'suspended', 'suspended_debt')
      AND NOT EXISTS (SELECT 1 FROM bill b WHERE b.contract_id = c.id AND b.billing_period_start = v_period_start)
      AND (p_search IS NULL OR p_search = '' OR
           c.msisdn ILIKE '%' || p_search || '%' OR
           u.name ILIKE '%' || p_search || '%' OR
           r.name ILIKE '%' || p_search || '%');

    RETURN QUERY
    SELECT c.id, c.msisdn, u.name, r.name,
           (SELECT MAX(billing_date) FROM bill b WHERE b.contract_id = c.id),
           v_total
    FROM contract c
    JOIN user_account u ON c.user_account_id = u.id
    LEFT JOIN rateplan r ON c.rateplan_id = r.id
    WHERE c.status IN ('active', 'suspended', 'suspended_debt')
      AND NOT EXISTS (SELECT 1 FROM bill b WHERE b.contract_id = c.id AND b.billing_period_start = v_period_start)
      AND (p_search IS NULL OR p_search = '' OR
           c.msisdn ILIKE '%' || p_search || '%' OR
           u.name ILIKE '%' || p_search || '%' OR
           r.name ILIKE '%' || p_search || '%')
    ORDER BY c.id ASC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_rateplan_by_id(p_id INTEGER)
    RETURNS TABLE (
        id        INTEGER,
        name      VARCHAR(255),
        ror_voice NUMERIC(15,2),
        ror_data  NUMERIC(15,2),
        ror_sms   NUMERIC(15,2),
        price     NUMERIC(15,2)
    ) AS $$
BEGIN
    RETURN QUERY
        SELECT r.id, r.name, r.ror_voice, r.ror_data, r.ror_sms, r.price
        FROM rateplan r
        WHERE r.id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_rateplan_data(p_rateplan_id INTEGER)
RETURNS TABLE(id INTEGER, name VARCHAR(255), ror_data NUMERIC(15,2),
              ror_voice NUMERIC(15,2), ror_sms NUMERIC(15,2), price NUMERIC(15,2))
AS $$
BEGIN
    RETURN QUERY
    SELECT r.id, r.name, r.ror_data, r.ror_voice, r.ror_sms, r.price
    FROM rateplan r WHERE r.id = p_rateplan_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_service_package_by_id(p_id INTEGER)
    RETURNS TABLE (
        id          INTEGER,
        name        VARCHAR(255),
        type        service_type,
        amount      NUMERIC(12,4),
        priority    INTEGER,
        price       NUMERIC(15,2),
        description TEXT,
        is_roaming  BOOLEAN
    ) AS $$
BEGIN
    RETURN QUERY
        SELECT sp.id, sp.name, sp.type, sp.amount, sp.priority, sp.price, sp.description, sp.is_roaming
        FROM service_package sp
        WHERE sp.id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_contracts(p_user_id INTEGER)
RETURNS TABLE (
    id INTEGER, msisdn VARCHAR(20), status contract_status,
    available_credit NUMERIC(15,2), credit_limit NUMERIC(15,2),
    rateplan_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.msisdn, c.status, c.available_credit, c.credit_limit, r.name
    FROM contract c
    LEFT JOIN rateplan r ON c.rateplan_id = r.id
    WHERE c.user_account_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_data(p_user_account_id INTEGER)
    RETURNS TABLE (
                      username VARCHAR(255),
                      role VARCHAR(20),
                      name VARCHAR(255),
                      email VARCHAR(255),
                      address TEXT,
                      birthdate DATE
                  ) AS $$
BEGIN
    RETURN QUERY
        SELECT
            ua.username,
            ua.role,
            ua.name,
            ua.email,
            ua.address,
            ua.birthdate
        FROM user_account ua
        WHERE ua.id = p_user_account_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_invoices(p_user_id INTEGER)
RETURNS TABLE (
    id INTEGER, contract_id INTEGER,
    billing_period_start DATE, billing_period_end DATE, billing_date DATE,
    recurring_fees NUMERIC(15,2), one_time_fees NUMERIC(15,2),
    voice_usage BIGINT, data_usage BIGINT, sms_usage BIGINT,
    ror_charge NUMERIC(15,2), taxes NUMERIC(15,2),
    total_amount NUMERIC(15,2), status bill_status,
    is_paid BOOLEAN, pdf_path TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT b.id, b.contract_id, b.billing_period_start, b.billing_period_end, b.billing_date,
        b.recurring_fees, b.one_time_fees, b.voice_usage, b.data_usage, b.sms_usage,
        b.ror_charge, b.taxes, b.total_amount, b.status, b.is_paid, i.pdf_path
    FROM bill b
    JOIN contract c ON b.contract_id = c.id
    LEFT JOIN invoice i ON b.id = i.bill_id
    WHERE c.user_account_id = p_user_id
    ORDER BY b.billing_date DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION initialize_consumption_period(p_period_start DATE)
RETURNS VOID AS $$
DECLARE v_period_end DATE;
BEGIN
    v_period_end := (DATE_TRUNC('month', p_period_start) + INTERVAL '1 month - 1 day')::DATE;

    INSERT INTO contract_consumption (
        contract_id, service_package_id, rateplan_id,
        starting_date, ending_date, consumed, quota_limit, is_billed
    )
    SELECT c.id, rsp.service_package_id, c.rateplan_id,
        p_period_start, v_period_end, 0, sp.amount, FALSE
    FROM contract c
    JOIN rateplan_service_package rsp ON rsp.rateplan_id = c.rateplan_id
    JOIN service_package sp ON sp.id = rsp.service_package_id
    WHERE c.status = 'active'
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_cdr(
    p_file_id INTEGER,
    p_dial_a VARCHAR(20),
    p_dial_b VARCHAR(20),
    p_start_time TIMESTAMP,
    p_duration BIGINT,
    p_service_id INTEGER,
    p_hplmn VARCHAR(20),
    p_vplmn VARCHAR(20),
    p_external_charges NUMERIC(15,2)
)
RETURNS INTEGER AS $$
DECLARE
    v_new_id INTEGER;
    v_contract_id INTEGER;
    v_status contract_status;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM file WHERE id = p_file_id) THEN
        RAISE EXCEPTION 'File with id % does not exist', p_file_id;
    END IF;

    IF p_service_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM service_package WHERE id = p_service_id
    ) THEN
        RAISE EXCEPTION 'Service package with id % does not exist', p_service_id;
    END IF;

    SELECT id, status INTO v_contract_id, v_status
    FROM contract WHERE msisdn = p_dial_a;

    IF v_contract_id IS NULL THEN
        INSERT INTO rejected_cdr (file_id, dial_a, dial_b, start_time, duration, service_id, rejection_reason)
        VALUES (p_file_id, p_dial_a, p_dial_b, p_start_time, p_duration, p_service_id, 'NO_CONTRACT_FOUND');
        RETURN 0;
    END IF;

    IF v_status != 'active' THEN
        INSERT INTO rejected_cdr (file_id, dial_a, dial_b, start_time, duration, service_id, rejection_reason)
        VALUES (p_file_id, p_dial_a, p_dial_b, p_start_time, p_duration, p_service_id,
            CASE v_status
                WHEN 'suspended' THEN 'CONTRACT_ADMIN_HOLD'
                WHEN 'suspended_debt' THEN 'CONTRACT_DEBT_HOLD'
                WHEN 'terminated' THEN 'CONTRACT_TERMINATED'
                ELSE 'CONTRACT_BLOCK'
            END);
        RETURN 0;
    END IF;

    INSERT INTO cdr (file_id, dial_a, dial_b, start_time, duration, service_id, hplmn, vplmn, external_charges, rated_flag)
    VALUES (p_file_id, p_dial_a, p_dial_b, p_start_time, p_duration, p_service_id, p_hplmn, p_vplmn, COALESCE(p_external_charges, 0), FALSE)
    ON CONFLICT (dial_a, dial_b, start_time, duration) DO NOTHING
    RETURNING id INTO v_new_id;

    RETURN COALESCE(v_new_id, 0);
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'insert_cdr failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_audit_action(
    p_action VARCHAR(100),
    p_table_affected VARCHAR(50),
    p_records_affected INTEGER,
    p_performed_by VARCHAR(255),
    p_details JSONB DEFAULT '{}'::JSONB
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO system_audit_log (action, table_affected, records_affected, performed_by, details)
    VALUES (p_action, p_table_affected, p_records_affected, p_performed_by, p_details);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION login(p_username VARCHAR(255), p_password VARCHAR(30))
RETURNS TABLE (id INTEGER, username VARCHAR(255), name VARCHAR(255), email VARCHAR(255), role user_role) AS $$
BEGIN
    RETURN QUERY
    SELECT ua.id, ua.username, ua.name, ua.email, ua.role
    FROM user_account ua
    WHERE ua.username = p_username AND ua.password = p_password;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_bill_paid(p_bill_id INTEGER)
RETURNS VOID AS $$
BEGIN
UPDATE bill
SET is_paid = TRUE, status = 'paid'
WHERE id = p_bill_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_msisdn_available(p_msisdn VARCHAR(20))
RETURNS VOID AS $$
BEGIN
    UPDATE msisdn_pool SET is_available = TRUE WHERE msisdn = p_msisdn;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_msisdn_taken(p_msisdn VARCHAR(20))
RETURNS VOID AS $$
BEGIN
    UPDATE msisdn_pool SET is_available = FALSE WHERE msisdn = p_msisdn;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION notify_bill_generation()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('generate_bill_event', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pay_bill(p_bill_id INTEGER, p_pdf_path TEXT)
         RETURNS VOID AS $$
BEGIN
         PERFORM mark_bill_paid(p_bill_id);
         PERFORM generate_invoice(p_bill_id, p_pdf_path);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION purchase_addon(p_contract_id INTEGER, p_service_package_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_addon_id INTEGER;
    v_pkg_price NUMERIC(15,2);
    v_pkg_amount BIGINT;
    v_expiry DATE;
    v_period_start DATE;
    v_period_end DATE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM contract WHERE id = p_contract_id AND status = 'active') THEN
        RAISE EXCEPTION 'Contract % is not active', p_contract_id;
    END IF;

    SELECT price, amount INTO v_pkg_price, v_pkg_amount
    FROM service_package WHERE id = p_service_package_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service package % not found', p_service_package_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM contract WHERE id = p_contract_id AND available_credit >= COALESCE(v_pkg_price, 0)
    ) THEN
        RAISE EXCEPTION 'Insufficient credit to purchase add-on';
    END IF;

    v_expiry := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;

    INSERT INTO contract_addon (
        contract_id, service_package_id, purchased_date, expiry_date, is_active, price_paid
    ) VALUES (p_contract_id, p_service_package_id, CURRENT_DATE, v_expiry, TRUE, v_pkg_price)
    RETURNING id INTO v_addon_id;

    UPDATE contract SET available_credit = available_credit - v_pkg_price WHERE id = p_contract_id;

    v_period_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_period_end := v_expiry;

    INSERT INTO contract_consumption (
        contract_id, service_package_id, rateplan_id, starting_date, ending_date, consumed, quota_limit, is_billed
    )
    SELECT p_contract_id, p_service_package_id, c.rateplan_id, v_period_start, v_period_end, 0, v_pkg_amount, FALSE
    FROM contract c WHERE c.id = p_contract_id
    ON CONFLICT DO UPDATE SET quota_limit = contract_consumption.quota_limit + EXCLUDED.quota_limit;

    RETURN v_addon_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_all_unrated_cdrs()
RETURNS INT AS $$
DECLARE
    v_cdr RECORD;
    v_count INT := 0;
BEGIN
    FOR v_cdr IN 
        SELECT id FROM cdr 
        WHERE rated_flag = FALSE 
        AND dial_a IN (SELECT msisdn FROM contract WHERE status = 'active')
    LOOP
        PERFORM rate_cdr(v_cdr.id);
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_cdr(p_cdr_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_cdr RECORD;
    v_contract RECORD;
    v_service_type VARCHAR;
    v_bundle RECORD;
    v_remaining BIGINT;
    v_deduct BIGINT;
    v_available BIGINT;
    v_ror_rate NUMERIC;
    v_ror_rate_v NUMERIC;
    v_ror_rate_d NUMERIC;
    v_ror_rate_s NUMERIC;
    v_ror_roaming_v NUMERIC;
    v_ror_roaming_d NUMERIC;
    v_ror_roaming_s NUMERIC;
    v_overage_charge NUMERIC(15,4) := 0;
    v_rated_service_id INTEGER;
    v_is_roaming BOOLEAN;
    v_period_start DATE;
    v_contract_id INTEGER;
BEGIN
    SELECT * INTO v_cdr FROM cdr WHERE id = p_cdr_id;
    
    -- Subscriber Lookup (Join rateplan to get billing type)
    SELECT c.*, rp.type as billing_mode INTO v_contract 
    FROM contract c 
    JOIN rateplan rp ON c.rateplan_id = rp.id
    WHERE c.msisdn = v_cdr.dial_a AND c.status IN ('active', 'suspended', 'suspended_debt');
    
    IF NOT FOUND THEN
        UPDATE cdr SET rated_flag = TRUE, cost = 0, rejection_reason = 'NO_ACTIVE_CONTRACT' WHERE id = p_cdr_id;
        RETURN;
    END IF;

    -- 1. Precision Service Type Detection
    v_service_type := CASE 
        WHEN v_cdr.service_id = 1 THEN 'voice'
        WHEN v_cdr.service_id = 2 THEN 'data'
        WHEN v_cdr.service_id = 3 THEN 'sms'
        WHEN v_cdr.dial_b = 'internet' THEN 'data'
        WHEN v_cdr.duration = 1 AND v_cdr.dial_b ~ '^[0-9]+$' THEN 'sms'
        ELSE 'voice'
    END;

    v_remaining := v_cdr.duration;
    v_is_roaming := (v_cdr.vplmn IS NOT NULL AND v_cdr.vplmn != '' AND v_cdr.vplmn != v_cdr.hplmn);
    v_period_start := DATE_TRUNC('month', v_cdr.start_time)::DATE;

    -- Get Contract ID
    SELECT id INTO v_contract_id FROM contract WHERE msisdn = v_cdr.dial_a;

    -- 2. Bundle Deduction Loop
    FOR v_bundle IN
        SELECT cc.contract_id, cc.service_package_id, cc.consumed, sp.amount as quota_limit, sp.type, sp.priority
        FROM contract_consumption cc
        JOIN service_package sp ON cc.service_package_id = sp.id
        WHERE cc.contract_id = v_contract_id
          AND cc.starting_date = v_period_start
          AND (sp.type = v_service_type::service_type OR sp.type = 'free_units')
          AND (sp.is_roaming = v_is_roaming OR sp.type = 'free_units')
        ORDER BY sp.priority ASC
    LOOP
        EXIT WHEN v_remaining <= 0;
        v_available := v_bundle.quota_limit - v_bundle.consumed;
        IF v_available <= 0 THEN CONTINUE; END IF;
        
        v_deduct := LEAST(v_remaining, v_available);
        v_remaining := v_remaining - v_deduct;

        UPDATE contract_consumption
        SET consumed = consumed + v_deduct
        WHERE contract_id = v_bundle.contract_id
          AND service_package_id = v_bundle.service_package_id
          AND starting_date = v_period_start;
          
        v_rated_service_id := v_bundle.service_package_id;
    END LOOP;

    -- 3. Overage Calculation
    IF v_remaining > 0 THEN
        -- Resolve Rates
        SELECT 
            ror_voice, ror_data, ror_sms, 
            ror_roaming_voice, ror_roaming_data, ror_roaming_sms
        INTO v_ror_rate_v, v_ror_rate_d, v_ror_rate_s, v_ror_roaming_v, v_ror_roaming_d, v_ror_roaming_s
        FROM rateplan WHERE id = v_contract.rateplan_id;

        IF v_is_roaming THEN
            v_ror_rate := CASE WHEN v_service_type='voice' THEN v_ror_roaming_v WHEN v_service_type='data' THEN v_ror_roaming_d ELSE v_ror_roaming_s END;
            v_overage_charge := CASE 
                WHEN v_service_type='data' THEN (v_remaining / 1048576.0) * v_ror_rate
                ELSE (v_remaining / 60.0) * v_ror_rate
            END;

            IF v_contract.billing_mode = 'PREPAID' THEN
                IF v_contract.balance < v_overage_charge THEN
                    UPDATE cdr SET rated_flag = TRUE, cost = 0, rejection_reason = 'INSUFFICIENT_BALANCE' WHERE id = p_cdr_id;
                    RETURN;
                END IF;
                UPDATE contract SET balance = balance - v_overage_charge WHERE id = v_contract.id;
            ELSE
                -- POSTPAID CREDIT CHECK
                IF v_contract.available_credit < v_overage_charge THEN
                    UPDATE cdr SET rated_flag = TRUE, cost = 0, rejection_reason = 'CREDIT_LIMIT_REACHED' WHERE id = p_cdr_id;
                    RETURN;
                END IF;
                UPDATE contract SET available_credit = available_credit - v_overage_charge WHERE id = v_contract.id;

                INSERT INTO ror_contract (contract_id, rateplan_id, starting_date, roaming_voice, roaming_data, roaming_sms)
                VALUES (v_contract.id, v_contract.rateplan_id, v_period_start,
                    CASE WHEN v_service_type='voice' THEN v_remaining ELSE 0 END,
                    CASE WHEN v_service_type='data' THEN v_remaining ELSE 0 END,
                    CASE WHEN v_service_type='sms' THEN v_remaining ELSE 0 END)
                ON CONFLICT (contract_id, rateplan_id, starting_date) DO UPDATE SET
                    roaming_voice = ror_contract.roaming_voice + EXCLUDED.roaming_voice,
                    roaming_data = ror_contract.roaming_data + EXCLUDED.roaming_data,
                    roaming_sms = ror_contract.roaming_sms + EXCLUDED.roaming_sms;
            END IF;
        ELSE
            v_ror_rate := CASE WHEN v_service_type='voice' THEN v_ror_rate_v WHEN v_service_type='data' THEN v_ror_rate_d ELSE v_ror_rate_s END;
            v_overage_charge := CASE 
                WHEN v_service_type='data' THEN (v_remaining / 1048576.0) * v_ror_rate
                ELSE (v_remaining / 60.0) * v_ror_rate
            END;

            IF v_contract.billing_mode = 'PREPAID' THEN
                IF v_contract.balance < v_overage_charge THEN
                    UPDATE cdr SET rated_flag = TRUE, cost = 0, rejection_reason = 'INSUFFICIENT_BALANCE' WHERE id = p_cdr_id;
                    RETURN;
                END IF;
                UPDATE contract SET balance = balance - v_overage_charge WHERE id = v_contract.id;
            ELSE
                -- POSTPAID CREDIT CHECK
                IF v_contract.available_credit < v_overage_charge THEN
                    UPDATE cdr SET rated_flag = TRUE, cost = 0, rejection_reason = 'CREDIT_LIMIT_REACHED' WHERE id = p_cdr_id;
                    RETURN;
                END IF;
                UPDATE contract SET available_credit = available_credit - v_overage_charge WHERE id = v_contract.id;

                INSERT INTO ror_contract (contract_id, rateplan_id, starting_date, voice, data, sms)
                VALUES (v_contract.id, v_contract.rateplan_id, v_period_start,
                    CASE WHEN v_service_type='voice' THEN v_remaining ELSE 0 END,
                    CASE WHEN v_service_type='data' THEN v_remaining ELSE 0 END,
                    CASE WHEN v_service_type='sms' THEN v_remaining ELSE 0 END)
                ON CONFLICT (contract_id, rateplan_id, starting_date) DO UPDATE SET
                    voice = ror_contract.voice + EXCLUDED.voice,
                    data = ror_contract.data + EXCLUDED.data,
                    sms = ror_contract.sms + EXCLUDED.sms;
            END IF;
        END IF;
    END IF;

    -- 4. Audit Update
    UPDATE cdr SET 
        rated_flag = TRUE, 
        cost = ROUND(v_overage_charge, 4), 
        rated_service_id = v_rated_service_id,
        usage_type = v_service_type
    WHERE id = p_cdr_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION release_msisdn(p_msisdn VARCHAR(20))
    RETURNS VOID AS $$
BEGIN
    UPDATE msisdn_pool
    SET is_available = TRUE
    WHERE msisdn = p_msisdn;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_file_parsed(p_file_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE file SET parsed_flag = TRUE WHERE id = p_file_id;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'set_file_parsed failed for file id %: %', p_file_id, SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_restore_credit_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_paid = TRUE AND OLD.is_paid = FALSE THEN
UPDATE contract
SET available_credit = credit_limit
WHERE id = NEW.contract_id;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_rateplan(
    p_rateplan_id INTEGER, p_name VARCHAR(255) DEFAULT NULL,
    p_ror_voice NUMERIC(15,2) DEFAULT NULL, p_ror_data NUMERIC(15,2) DEFAULT NULL,
    p_ror_sms NUMERIC(15,2) DEFAULT NULL, p_price NUMERIC(15,2) DEFAULT NULL,
    p_service_package_ids INTEGER[] DEFAULT NULL,
    p_type billing_type DEFAULT NULL
) RETURNS VOID AS $$
DECLARE v_package_id INTEGER;
BEGIN
    UPDATE rateplan 
    SET name = COALESCE(p_name, name), ror_voice = COALESCE(p_ror_voice, ror_voice),
        ror_data = COALESCE(p_ror_data, ror_data), ror_sms = COALESCE(p_ror_sms, ror_sms),
        price = COALESCE(p_price, price),
        type = COALESCE(p_type, type)
    WHERE id = p_rateplan_id;
    
    IF p_service_package_ids IS NOT NULL THEN
        DELETE FROM rateplan_service_package WHERE rateplan_id = p_rateplan_id;
        FOREACH v_package_id IN ARRAY p_service_package_ids LOOP
            INSERT INTO rateplan_service_package (rateplan_id, service_package_id)
            VALUES (p_rateplan_id, v_package_id);
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_service_package(
    p_id INTEGER, p_name VARCHAR(255), p_type service_type, p_amount NUMERIC(12,4),
    p_priority INTEGER, p_price NUMERIC(15,2), p_description TEXT,
    p_is_roaming BOOLEAN DEFAULT FALSE
) RETURNS TABLE(
    id INTEGER, name VARCHAR(255), type service_type, amount NUMERIC(12,4),
    priority INTEGER, price NUMERIC(15,2), description TEXT, is_roaming BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
        UPDATE service_package 
        SET name = p_name, type = p_type, amount = p_amount, priority = p_priority,
            price = p_price, description = p_description, is_roaming = p_is_roaming
        WHERE service_package.id = p_id
        RETURNING service_package.id, service_package.name, service_package.type,
                  service_package.amount, service_package.priority, service_package.price,
                  service_package.description, service_package.is_roaming;
END;
$$ LANGUAGE plpgsql;

