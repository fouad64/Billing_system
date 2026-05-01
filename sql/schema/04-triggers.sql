-- ============================================================
-- TELECOM BILLING SCHEMA - TRIGGERS
-- Must be loaded AFTER 03-functions.sql
-- ============================================================

-- ------------------------------------------------------------
-- AUDIT FUNCTION: Bill Status Change
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit_bill_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO system_audit_log (action, table_affected, records_affected, performed_by, details)
        VALUES (
            'BILL_STATUS_CHANGE',
            'bill',
            1,
            current_user,
            jsonb_build_object('bill_id', NEW.id, 'old_status', OLD.status, 'new_status', NEW.status)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- AUDIT FUNCTION: Contract Status Change
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit_contract_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO system_audit_log (action, table_affected, records_affected, performed_by, details)
        VALUES (
            'CONTRACT_STATUS_CHANGE',
            'contract',
            1,
            current_user,
            jsonb_build_object('contract_id', NEW.id, 'old_status', OLD.status, 'new_status', NEW.status)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- AUDIT FUNCTION: Credit Change
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit_contract_credit_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.available_credit IS DISTINCT FROM NEW.available_credit THEN
        INSERT INTO system_audit_log (action, table_affected, records_affected, performed_by, details)
        VALUES (
            'CONTRACT_CREDIT_CHANGE',
            'contract',
            1,
            current_user,
            jsonb_build_object('contract_id', NEW.id, 'old_credit', OLD.available_credit, 'new_credit', NEW.available_credit)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- TRIGGER: Bill Status Audit
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_bill_status_audit ON bill;
CREATE TRIGGER trg_bill_status_audit
AFTER UPDATE OF status ON bill
FOR EACH ROW
EXECUTE FUNCTION audit_bill_status_change();

-- ------------------------------------------------------------
-- TRIGGER: Contract Status Audit
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_contract_status_audit ON contract;
CREATE TRIGGER trg_contract_status_audit
AFTER UPDATE OF status ON contract
FOR EACH ROW
EXECUTE FUNCTION audit_contract_status_change();

-- ------------------------------------------------------------
-- TRIGGER: Contract Credit Audit
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_contract_credit_audit ON contract;
CREATE TRIGGER trg_contract_credit_audit
AFTER UPDATE OF available_credit ON contract
FOR EACH ROW
EXECUTE FUNCTION audit_contract_credit_change();
-- ------------------------------------------------------------
-- TRIGGER: Auto-rate CDRs
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_auto_rate_cdr ON cdr;
CREATE TRIGGER trg_auto_rate_cdr
AFTER INSERT ON cdr
FOR EACH ROW
EXECUTE FUNCTION auto_rate_cdr();

-- ------------------------------------------------------------
-- TRIGGER: Auto-initialize Consumption
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_auto_initialize_consumption ON contract;
CREATE TRIGGER trg_auto_initialize_consumption
AFTER INSERT ON contract
FOR EACH ROW
EXECUTE FUNCTION auto_initialize_consumption();

-- ------------------------------------------------------------
-- TRIGGER: Restore Credit on Payment
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_restore_credit_on_payment ON bill;
CREATE TRIGGER trg_restore_credit_on_payment
AFTER UPDATE OF status ON bill
FOR EACH ROW
WHEN (OLD.status != 'paid' AND NEW.status = 'paid')
EXECUTE FUNCTION trg_restore_credit_on_payment();
