-- ============================================================
-- DEMO: CREATE MISSING STATEMENTS (HOLE PUNCHER)
-- Use this to simulate a scenario where bills are missing
-- ============================================================

-- 1. Identify 20 random contracts that have bills for April
-- 2. Clear their billing links and delete the bills
DO $$
DECLARE
    v_bill_record RECORD;
BEGIN
    FOR v_bill_record IN 
        SELECT id, contract_id FROM bill 
        WHERE billing_period_start = '2026-04-01' 
        ORDER BY RANDOM() LIMIT 20
    LOOP
        -- Remove references first to avoid foreign key errors
        UPDATE ror_contract SET bill_id = NULL WHERE bill_id = v_bill_record.id;
        UPDATE contract_consumption SET bill_id = NULL, is_billed = FALSE WHERE bill_id = v_bill_record.id;
        DELETE FROM invoice WHERE bill_id = v_bill_record.id;
        
        -- Delete the bill
        DELETE FROM bill WHERE id = v_bill_record.id;
    END LOOP;
    
    RAISE NOTICE '20 Statements have been un-generated. Check dashboard for Missing Statements!';
END $$;
