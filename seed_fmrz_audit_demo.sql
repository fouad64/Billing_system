-- FMRZ AUDIT DEMO SEED (IDEMPOTENT)
-- This script populates the dashboard stats safely.

-- 1. Create a "Restricted" Customer (For Blocked Usage Demo)
DO $$
DECLARE v_user_id INTEGER; v_contract_id INTEGER;
BEGIN
    -- Check if user exists
    SELECT id INTO v_user_id FROM user_account WHERE username = 'restricted_user';
    
    IF v_user_id IS NULL THEN
        INSERT INTO user_account (username, password, name, email, role, address)
        VALUES ('restricted_user', 'pass123', 'John Restricted', 'restricted@fmrz.com', 'customer', '99 Debt St, Cairo')
        RETURNING id INTO v_user_id;
    END IF;

    -- Check if contract exists
    SELECT id INTO v_contract_id FROM contract WHERE user_account_id = v_user_id;
    IF v_contract_id IS NULL THEN
        INSERT INTO contract (user_account_id, msisdn, rateplan_id, status, billing_mode, balance, available_credit)
        VALUES (v_user_id, '201099999999', (SELECT id FROM rateplan ORDER BY price ASC LIMIT 1), 'active', 'PREPAID', 0.00, 0.00)
        RETURNING id INTO v_contract_id;
    END IF;

    -- Delete old rejections for this user to avoid bloat
    DELETE FROM cdr WHERE dial_a = '201099999999' AND rejection_reason IS NOT NULL;

    -- Generate 10 Blocked CDRs (Rejections)
    FOR i IN 1..10 LOOP
        INSERT INTO cdr (file_id, dial_a, dial_b, start_time, duration, service_id, hplmn, vplmn, rated_flag, rejection_reason, cost)
        VALUES (1, '201099999999', '201012345678', CURRENT_TIMESTAMP - (i || ' minutes')::interval, 300, 1, 'EGYVO', NULL, TRUE, 'INSUFFICIENT_BALANCE', 0.00);
    END LOOP;
END $$;

-- 2. Create Pending Collection (Issued Bills)
DO $$
DECLARE v_msisdn VARCHAR; v_cid INTEGER;
BEGIN
    FOR i IN 1..5 LOOP
        v_msisdn := '20100000080' || i;
        SELECT id INTO v_cid FROM contract WHERE msisdn = v_msisdn;
        IF v_cid IS NOT NULL THEN
            -- Check if an issued bill already exists for this period
            IF NOT EXISTS (SELECT 1 FROM bill WHERE contract_id = v_cid AND status = 'issued') THEN
                INSERT INTO bill (contract_id, billing_period_start, billing_period_end, billing_date, recurring_fees, taxes, total_amount, status, is_paid)
                VALUES (v_cid, DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::DATE, (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 day')::DATE, CURRENT_DATE - (i || ' days')::interval, 500.00, 70.00, 570.00, 'issued', FALSE);
            END IF;
        END IF;
    END LOOP;
END $$;

-- 3. Create Missing Statements (Active Contracts)
DO $$
DECLARE v_user_id INTEGER; v_username VARCHAR;
BEGIN
    FOR i IN 1..5 LOOP
        v_username := 'new_user_' || i;
        SELECT id INTO v_user_id FROM user_account WHERE username = v_username;
        
        IF v_user_id IS NULL THEN
            INSERT INTO user_account (username, password, name, email, role)
            VALUES (v_username, 'pass123', 'Elite Client ' || i, 'elite' || i || '@fmrz.com', 'customer')
            RETURNING id INTO v_user_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM contract WHERE user_account_id = v_user_id) THEN
            INSERT INTO contract (user_account_id, msisdn, rateplan_id, status)
            VALUES (v_user_id, '20107777777' || i, (SELECT id FROM rateplan ORDER BY price DESC LIMIT 1), 'active');
        END IF;
    END LOOP;
END $$;
