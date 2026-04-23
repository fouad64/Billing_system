-- =========================================================
-- DUMMY DATA
-- For testing and demonstration purposes
-- =========================================================

------------------------------------------------------------
-- RESET (make script re-runnable)
-- Ensures IDs start from 1 so FK references match.
------------------------------------------------------------
TRUNCATE TABLE
    invoice,
    bill,
    cdr,
    contract_consumption,
    ror_contract,
    contract,
    rateplan_service_package,
    service_package,
    rateplan,
    customer,
    user_account,
    file
RESTART IDENTITY CASCADE;

------------------------------------------------------------
-- FILES
------------------------------------------------------------
INSERT INTO file (parsed_flag, file_path)
VALUES
    (FALSE, '/tmp/test_cdr_april_1.csv'),
    (FALSE, '/tmp/test_cdr_april_2.csv');

------------------------------------------------------------
-- user_accounts
------------------------------------------------------------
INSERT INTO user_account (name, address, birthdate, role, username, password)
VALUES
    ('Alice Smith', '123 Main St', '1990-01-01', 'customer', 'alice', 'password1'),
    ('Bob Johnson', '456 Elm St', '1985-05-15', 'customer', 'bob', 'password2');

------------------------------------------------------------
-- RATEPLANS
------------------------------------------------------------
INSERT INTO rateplan (name, ror_data, ror_voice, ror_sms, price)
VALUES
    ('Basic',   0.10, 0.20, 0.05, 50),
    ('Premium', 0.05, 0.10, 0.02, 120);

------------------------------------------------------------
-- SERVICE PACKAGES
------------------------------------------------------------
INSERT INTO service_package (name, type, amount, priority, is_roaming)
VALUES
    ('Voice Pack',   'voice', 1000, 1, FALSE),
    ('Data Pack',    'data',  5000, 1, FALSE),
    ('SMS Pack',     'sms',    200, 1, FALSE),
    ('Welcome Bonus','free_units', 50, 2, FALSE),
    -- Roaming-only bundles (consumed only when HPLMN != VPLMN)
    ('Roaming Voice Pack', 'voice', 200, 1, TRUE),
    ('Roaming Data Pack',  'data',  1000, 1, TRUE),
    ('Roaming SMS Pack',   'sms',   50,  1, TRUE);

------------------------------------------------------------
-- RATEPLAN → PACKAGES
------------------------------------------------------------
INSERT INTO rateplan_service_package (rateplan_id, service_package_id)
VALUES
    (1, 1), (1, 3),
    (2, 1), (2, 2), (2, 3), (2, 4),
    -- Premium includes roaming bundles
    (2, 5), (2, 6), (2, 7);

------------------------------------------------------------
-- CONTRACTS
------------------------------------------------------------
INSERT INTO contract (user_account_id, rateplan_id, msisdn, status, credit_limit, available_credit)
VALUES
    (1, 1, '201000000001', 'active', 200, 200),
    (2, 2, '201000000002', 'active', 500, 500),
    (3,  1, '201000000003', 'active', 200, 200),
    (4,  2, '201000000004', 'active', 500, 500),
    (5,  1, '201000000005', 'active', 200, 200),
    (6,  2, '201000000006', 'active', 500, 500),
    (7,  1, '201000000007', 'active', 200, 200),
    (8,  2, '201000000008', 'active', 500, 500),
    (9,  1, '201000000009', 'active', 200, 200),
    (10, 2, '201000000010', 'active', 500, 500),
    (11, 1, '201000000011', 'active', 200, 200),
    (12, 2, '201000000012', 'active', 500, 500),
    (13, 1, '201000000013', 'active', 200, 200),
    (14, 2, '201000000014', 'active', 500, 500),
    (15, 1, '201000000015', 'active', 200, 200),
    (16, 2, '201000000016', 'active', 500, 500),
    (17, 1, '201000000017', 'active', 200, 200),
    (18, 2, '201000000018', 'active', 500, 500);

------------------------------------------------------------
-- ROR_CONTRACT
------------------------------------------------------------
INSERT INTO ror_contract (contract_id, rateplan_id, data, voice, sms, roam_data, roam_voice, roam_sms)
VALUES
    (1, 1, 10, 20, 5, 0, 0, 0),
    (2, 2,  5, 10, 2, 0, 0, 0),
    (3,  1, 0, 0, 0, 0, 0, 0),
    (4,  2, 0, 0, 0, 0, 0, 0),
    (5,  1, 0, 0, 0, 0, 0, 0),
    (6,  2, 0, 0, 0, 0, 0, 0),
    (7,  1, 0, 0, 0, 0, 0, 0),
    (8,  2, 0, 0, 0, 0, 0, 0),
    (9,  1, 0, 0, 0, 0, 0, 0),
    (10, 2, 0, 0, 0, 0, 0, 0),
    (11, 1, 0, 0, 0, 0, 0, 0),
    (12, 2, 0, 0, 0, 0, 0, 0),
    (13, 1, 0, 0, 0, 0, 0, 0),
    (14, 2, 0, 0, 0, 0, 0, 0),
    (15, 1, 0, 0, 0, 0, 0, 0),
    (16, 2, 0, 0, 0, 0, 0, 0),
    (17, 1, 0, 0, 0, 0, 0, 0),
    (18, 2, 0, 0, 0, 0, 0, 0);

------------------------------------------------------------
-- CONTRACT_CONSUMPTION (CURRENT PERIOD = APRIL 2026)
------------------------------------------------------------
INSERT INTO contract_consumption (
    contract_id, service_package_id, rateplan_id,
    starting_date, ending_date, consumed, is_billed
) VALUES
      -- Contract 1 (Basic)
      (1, 1, 1, '2026-04-01', '2026-04-30', 120, FALSE),
      (1, 3, 1, '2026-04-01', '2026-04-30', 15,  FALSE),

      -- Contract 2 (Premium)
      (2, 1, 2, '2026-04-01', '2026-04-30', 300, FALSE),
      (2, 2, 2, '2026-04-01', '2026-04-30', 800, FALSE),
      (2, 3, 2, '2026-04-01', '2026-04-30', 40,  FALSE),
      (2, 4, 2, '2026-04-01', '2026-04-30', 10,  FALSE);

------------------------------------------------------------
-- BILL (PREVIOUS PERIOD = MARCH 2026)
------------------------------------------------------------
INSERT INTO bill (
    contract_id, billing_period_start, billing_period_end, billing_date,
    recurring_fees, one_time_fees,
    voice_usage, data_usage, sms_usage,
    ROR_charge, taxes, total_amount, status, is_paid
)
VALUES
    (1, '2026-03-01', '2026-03-31', '2026-04-01',
     50, 0,
     200, 0, 20,
     12.0, 5.0, 67.0, 'issued', FALSE),

    (2, '2026-03-01', '2026-03-31', '2026-04-01',
     120, 0,
     400, 1200, 60,
     25.0, 10.0, 155.0, 'issued', FALSE);

------------------------------------------------------------
-- INVOICES
------------------------------------------------------------
INSERT INTO invoice (bill_id, pdf_path)
VALUES
    (1, '/tmp/invoice_march_1.pdf'),
    (2, '/tmp/invoice_march_2.pdf');
