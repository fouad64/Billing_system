DO $$
BEGIN
    -- 1. Restore/Update Users (Alice = 2, Bob = 3)
    INSERT INTO user_account (id, name, address, birthdate, role, username, password, email)
    VALUES 
        (2, 'Alice Smith', '123 Main St, Cairo', '1990-05-15', 'customer', 'alice', '123456', 'alice@gmail.com'),
        (3, 'Bob Johnson', '456 Elm St', '1985-05-15', 'customer', 'bob', '123456', 'bob@gmail.com')
    ON CONFLICT (username) DO UPDATE SET 
        name = EXCLUDED.name, 
        password = EXCLUDED.password;

    -- 2. Clean up existing contracts for these MSISDNs and demo IDs 1, 2
    -- This ensures we can use IDs 1 and 2 for Alice and Bob
    DELETE FROM onetime_fee WHERE contract_id IN (SELECT id FROM contract WHERE msisdn IN ('201000000001', '201000000002')) OR contract_id IN (1, 2);
    DELETE FROM invoice WHERE bill_id IN (SELECT id FROM bill WHERE contract_id IN (SELECT id FROM contract WHERE msisdn IN ('201000000001', '201000000002')) OR contract_id IN (1, 2));
    DELETE FROM bill WHERE contract_id IN (SELECT id FROM contract WHERE msisdn IN ('201000000001', '201000000002')) OR contract_id IN (1, 2);
    DELETE FROM contract_consumption WHERE contract_id IN (SELECT id FROM contract WHERE msisdn IN ('201000000001', '201000000002')) OR contract_id IN (1, 2);
    DELETE FROM ror_contract WHERE contract_id IN (SELECT id FROM contract WHERE msisdn IN ('201000000001', '201000000002')) OR contract_id IN (1, 2);
    
    -- Update CDRs to un-link them before deleting contracts (or we can just leave them)
    UPDATE cdr SET bill_id = NULL WHERE dial_a IN ('201000000001', '201000000002');
    
    DELETE FROM contract WHERE msisdn IN ('201000000001', '201000000002') OR id IN (1, 2);

    -- 3. Insert fresh Demo Contracts
    INSERT INTO contract (id, user_account_id, rateplan_id, msisdn, status, credit_limit, available_credit)
    VALUES
        (1, 2, 1, '201000000001', 'active', 200, 150.00),
        (2, 3, 2, '201000000002', 'active', 500, 320.00);

    -- 4. Restore One-time Fees (Rich Info: SIM Change etc)
    INSERT INTO onetime_fee (contract_id, fee_type, amount, description, applied_date)
    VALUES
        (1, 'SIM_REPLACEMENT', 150.00, 'SIM card replacement due to loss', '2026-04-15'),
        (2, 'DATA_BOOSTER', 50.00, 'Extra 5GB Data Booster (Premium)', '2026-04-10'),
        (2, 'ADDRESS_CHANGE', 25.00, 'Physical address update administrative fee', '2026-04-20');

    -- 5. Restore historical Bills (Ensures Total Revenue > 0)
    INSERT INTO bill (contract_id, billing_period_start, billing_period_end, billing_date, recurring_fees, one_time_fees, voice_usage, data_usage, sms_usage, taxes, total_amount, status, is_paid)
    VALUES
        (1, '2026-02-01', '2026-02-28', '2026-03-01', 75, 0, 16800, 0, 38, 10.50, 85.50, 'paid', TRUE),
        (2, '2026-02-01', '2026-02-28', '2026-03-01', 370, 0, 34800, 1992294400, 72, 51.80, 421.80, 'paid', TRUE),
        (1, '2026-03-01', '2026-03-31', '2026-04-01', 75, 0, 310, 0, 42, 10.50, 85.50, 'paid', TRUE),
        (2, '2026-03-01', '2026-03-31', '2026-04-01', 370, 0, 640, 2200, 80, 51.80, 421.80, 'paid', TRUE);

    -- 6. Fix sequences to avoid future collisions
    PERFORM setval('user_account_id_seq', GREATEST((SELECT MAX(id) FROM user_account), 1000));
    PERFORM setval('contract_id_seq', GREATEST((SELECT MAX(id) FROM contract), 1000));
    PERFORM setval('bill_id_seq', GREATEST((SELECT MAX(id) FROM bill), 1000));
    PERFORM setval('onetime_fee_id_seq', GREATEST((SELECT MAX(id) FROM onetime_fee), 100));
END $$;

-- 7. Restore rich CDR history for April
INSERT INTO cdr (file_id, dial_a, dial_b, start_time, duration, service_id, hplmn, vplmn, cost, rated_flag)
VALUES
    (1, '201000000001', '201090000000', '2026-04-25 10:00:00', 300, 1, 'EGYVO', NULL, 0, TRUE),
    (1, '201000000001', '201090000001', '2026-04-25 11:30:00', 1, 3, 'EGYVO', NULL, 0, TRUE),
    (1, '201000000002', 'internet', '2026-04-26 14:00:00', 1073741824, 2, 'EGYVO', NULL, 0, TRUE),
    (1, '201000000002', '201090000005', '2026-04-26 16:00:00', 600, 5, 'EGYVO', 'VODAF_UK', 120.00, TRUE)
ON CONFLICT DO NOTHING;
