-- ELITE PRECISION AUDIT SCRIPT
-- Verifies mathematical integrity across CDR, Bill, and Contract tables

WITH bill_audit AS (
    SELECT 
        b.id as bill_id,
        b.contract_id,
        b.total_amount as actual_total,
        (b.subtotal + b.tax_total) as calculated_total,
        b.subtotal as actual_subtotal,
        (b.recurring_fees + b.overage_total + b.roaming_total + b.one_time_fees - b.promotional_discount) as calculated_subtotal,
        b.overage_total as actual_overage,
        COALESCE((SELECT SUM(cost) FROM cdr WHERE bill_id = b.id AND (vplmn IS NULL OR vplmn = '' OR vplmn = hplmn)), 0) as cdr_overage,
        b.roaming_total as actual_roaming,
        COALESCE((SELECT SUM(cost) FROM cdr WHERE bill_id = b.id AND vplmn IS NOT NULL AND vplmn != '' AND vplmn != hplmn), 0) as cdr_roaming
    FROM bill b
)
SELECT 
    bill_id,
    contract_id,
    CASE WHEN ABS(actual_total - calculated_total) < 0.01 THEN 'PASS' ELSE 'FAIL (Total)' END as status_total,
    CASE WHEN ABS(actual_subtotal - calculated_subtotal) < 0.01 THEN 'PASS' ELSE 'FAIL (Subtotal)' END as status_subtotal,
    CASE WHEN ABS(actual_overage - cdr_overage) < 0.01 THEN 'PASS' ELSE 'FAIL (CDR Overage Sync)' END as status_overage,
    CASE WHEN ABS(actual_roaming - cdr_roaming) < 0.01 THEN 'PASS' ELSE 'FAIL (CDR Roaming Sync)' END as status_roaming,
    (actual_total - calculated_total) as variance
FROM bill_audit
WHERE ABS(actual_total - calculated_total) > 0.01 
   OR ABS(actual_subtotal - calculated_subtotal) > 0.01
   OR ABS(actual_overage - cdr_overage) > 0.01
   OR ABS(actual_roaming - cdr_roaming) > 0.01;
