-- ============================================================
-- MASSIVE REAL-WORLD DUMMY DATA INJECTION
-- Total: 100+ Customers, 100+ Contracts, 300+ Rated CDRs, 100+ Bills
-- Targets: Dashboard Stats & Demo Realism
-- ============================================================

DO $$
DECLARE
    v_user_id INTEGER;
    v_msisdn VARCHAR(20);
    v_rateplan_id INTEGER;
    v_contract_id INTEGER;
    v_status contract_status;
    v_credit_limit NUMERIC;
    v_first_names TEXT[] := ARRAY['Ahmed', 'Mohamed', 'Sara', 'Mona', 'Hassan', 'Youssef', 'Layla', 'Omar', 'Nour', 'Amir', 'Ziad', 'Mariam', 'Fatma', 'Ibrahim', 'Salma', 'Khaled', 'Dina', 'Tarek', 'Hala', 'Sameh'];
    v_last_names TEXT[]  := ARRAY['Hassan', 'Mansour', 'Zaki', 'Khattab', 'Fouad', 'Salem', 'Nasr', 'Said', 'Gaber', 'Ezzat', 'Wahba', 'Soliman', 'Badawi', 'Moussa', 'Hamad'];
    v_streets TEXT[]     := ARRAY['El-Nasr St', 'Cornish Rd', '9th Street', 'Tahrir Sq', 'Abbas El Akkad', 'Makram Ebeid', 'Gameat El Dowal', 'Zamalek Dr', 'Maadi St'];
    v_cities TEXT[]      := ARRAY['Cairo', 'Giza', 'Alexandria', 'Mansoura', 'Suez', 'Luxor', 'Aswan', 'Hurghada'];
    v_fname TEXT;
    v_lname TEXT;
    v_uname TEXT;
    v_i INTEGER;
BEGIN
    RAISE NOTICE 'Starting Massive Data Injection...';

    FOR v_i IN 1..100 LOOP
        -- 1. Generate Random User Data
        v_fname := v_first_names[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_first_names, 1))];
        v_lname := v_last_names[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_last_names, 1))];
        v_uname := LOWER(v_fname) || '_' || (2000 + v_i);

        INSERT INTO user_account (name, address, birthdate, role, username, password, email)
        VALUES (
            v_fname || ' ' || v_lname,
            (10 + FLOOR(RANDOM() * 90)) || ' ' || v_streets[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_streets, 1))] || ', ' || v_cities[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_cities, 1))],
            '1970-01-01'::DATE + (FLOOR(RANDOM() * 15000) || ' days')::INTERVAL,
            'customer',
            v_uname,
            'password123',
            v_uname || '@fmrz-telecom.com'
        ) RETURNING id INTO v_user_id;

        -- 2. Pick Random RatePlan (40% Basic, 40% Gold, 20% Elite)
        v_rateplan_id := (CASE 
            WHEN RANDOM() < 0.4 THEN 1 -- Basic
            WHEN RANDOM() < 0.8 THEN 2 -- Gold
            ELSE 3                     -- Elite
        END);

        -- 3. MSISDN Generation (Fresh range for this batch)
        v_msisdn := '20101' || LPAD((v_i + 5000)::TEXT, 5, '0');
        INSERT INTO msisdn_pool (msisdn, is_available) VALUES (v_msisdn, FALSE)
        ON CONFLICT (msisdn) DO UPDATE SET is_available = FALSE;

        -- 4. Distribute Statuses (70% Active, 10% Suspended, 10% Debt, 10% Terminated)
        v_status := (CASE 
            WHEN RANDOM() < 0.7 THEN 'active'::contract_status
            WHEN RANDOM() < 0.8 THEN 'suspended'::contract_status
            WHEN RANDOM() < 0.9 THEN 'suspended_debt'::contract_status
            ELSE 'terminated'::contract_status
        END);

        v_credit_limit := (CASE v_rateplan_id WHEN 1 THEN 200 WHEN 2 THEN 500 ELSE 1000 END);

        -- 5. Create Contract
        INSERT INTO contract (user_account_id, rateplan_id, msisdn, status, credit_limit, available_credit)
        VALUES (v_user_id, v_rateplan_id, v_msisdn, v_status, v_credit_limit, v_credit_limit)
        RETURNING id INTO v_contract_id;

        -- 6. Initialize Consumption
        -- Note: using a sub-block to swallow errors if period already exists
        BEGIN
            PERFORM initialize_consumption_period('2026-04-01');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;

        -- 7. Randomly Add Welcome Gift (Only if Active)
        IF v_status = 'active' AND RANDOM() < 0.5 THEN
            PERFORM purchase_addon(v_contract_id, 4); -- 4 is Welcome Gift ID
        END IF;
    END LOOP;

    RAISE NOTICE '100 Customers & Contracts created successfully.';
END $$;

-- ============================================================
-- MASSIVE CDR INJECTION & RATING
-- ============================================================
DO $$
DECLARE
    v_msisdn RECORD;
    v_i INTEGER := 0;
    v_vplmn VARCHAR;
    v_service_id INTEGER;
    v_duration INTEGER;
BEGIN
    -- Inject 300 CDRs distributed across the new active contracts
    FOR v_msisdn IN 
        SELECT msisdn FROM contract WHERE status = 'active' ORDER BY id DESC LIMIT 100
    LOOP
        FOR j IN 1..4 LOOP
            v_i := v_i + 1;
            
            -- Service Types: 1=Voice, 2=Data, 3=SMS
            v_service_id := (CASE WHEN (v_i % 3) = 0 THEN 1 WHEN (v_i % 3) = 1 THEN 2 ELSE 3 END);
            
            -- Randomize Roaming (15% chance)
            v_vplmn := (CASE WHEN RANDOM() < 0.15 THEN 'VODAFONE_UK' ELSE NULL END);
            
            -- Randomize Durations
            v_duration := (CASE 
                WHEN v_service_id = 1 THEN floor(random()*300 + 30) -- 30-330s
                WHEN v_service_id = 2 THEN floor(random()*100 + 5) * 1024 -- 5-105MB
                ELSE 1 -- SMS
            END);

            INSERT INTO cdr (file_id, dial_a, dial_b, start_time, duration, service_id, hplmn, vplmn, external_charges, rated_flag)
            VALUES (
                1, 
                v_msisdn.msisdn, 
                '201090000000', 
                '2026-04-01 10:00:00'::timestamp + (v_i * interval '20 minutes'), 
                v_duration, 
                v_service_id, 
                'EGYVO', 
                v_vplmn, 
                0, 
                FALSE
            );
        END LOOP;
    END LOOP;
END $$;

-- Run Rating Engine
SELECT rate_cdr(id) FROM cdr WHERE rated_flag = FALSE;

-- ============================================================
-- GENERATE BILLS FOR ALL NEW ACTIVE CONTRACTS
-- ============================================================
SELECT generate_all_bills('2026-04-01');

DO $$
BEGIN
    RAISE NOTICE 'Massive Data Injection Complete. Dashboard should now show 140+ Contracts.';
END $$;
