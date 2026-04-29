--
-- PostgreSQL database dump
--

\restrict dG7Kti98q4JC7ooEAbgDHCu8D8JT07TUV47bhWDd8IREPnIRkzQPw3XXfH82BGX

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: bill_status; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.bill_status AS ENUM (
    'draft',
    'issued',
    'paid',
    'overdue',
    'cancelled'
);


ALTER TYPE public.bill_status OWNER TO zkhattab;

--
-- Name: contract_recurring_status; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.contract_recurring_status AS ENUM (
    'Active',
    'Suspended',
    'Cancelled',
    'Completed'
);


ALTER TYPE public.contract_recurring_status OWNER TO zkhattab;

--
-- Name: contract_status; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.contract_status AS ENUM (
    'active',
    'suspended',
    'suspended_debt',
    'terminated'
);


ALTER TYPE public.contract_status OWNER TO zkhattab;

--
-- Name: contract_status_enum; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.contract_status_enum AS ENUM (
    'Active',
    'Suspended',
    'Terminated',
    'Credit_Blocked'
);


ALTER TYPE public.contract_status_enum OWNER TO zkhattab;

--
-- Name: cot_status_enum; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.cot_status_enum AS ENUM (
    'Active',
    'Expired',
    'Cancelled'
);


ALTER TYPE public.cot_status_enum OWNER TO zkhattab;

--
-- Name: cr_status_enum; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.cr_status_enum AS ENUM (
    'Active',
    'Suspended',
    'Cancelled',
    'Completed'
);


ALTER TYPE public.cr_status_enum OWNER TO zkhattab;

--
-- Name: customer_type; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.customer_type AS ENUM (
    'Individual',
    'Corporate'
);


ALTER TYPE public.customer_type OWNER TO zkhattab;

--
-- Name: one_time_status; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.one_time_status AS ENUM (
    'Active',
    'Expired',
    'Cancelled'
);


ALTER TYPE public.one_time_status OWNER TO zkhattab;

--
-- Name: rateplan_status; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.rateplan_status AS ENUM (
    'Active',
    'Inactive'
);


ALTER TYPE public.rateplan_status OWNER TO zkhattab;

--
-- Name: rateplan_status_enum; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.rateplan_status_enum AS ENUM (
    'Active',
    'Inactive'
);


ALTER TYPE public.rateplan_status_enum OWNER TO zkhattab;

--
-- Name: service_type; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.service_type AS ENUM (
    'voice',
    'data',
    'sms',
    'free_units'
);


ALTER TYPE public.service_type OWNER TO zkhattab;

--
-- Name: service_type_enum; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.service_type_enum AS ENUM (
    'Voice',
    'Data',
    'SMS',
    'Roaming',
    'VAS',
    'Other'
);


ALTER TYPE public.service_type_enum OWNER TO zkhattab;

--
-- Name: service_uom; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.service_uom AS ENUM (
    'Minute',
    'MB',
    'GB',
    'SMS',
    'Event'
);


ALTER TYPE public.service_uom OWNER TO zkhattab;

--
-- Name: service_uom_enum; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.service_uom_enum AS ENUM (
    'Minute',
    'MB',
    'GB',
    'SMS',
    'Event'
);


ALTER TYPE public.service_uom_enum OWNER TO zkhattab;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: zkhattab
--

CREATE TYPE public.user_role AS ENUM (
    'admin',
    'customer'
);


ALTER TYPE public.user_role OWNER TO zkhattab;

--
-- Name: auto_initialize_consumption(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.auto_initialize_consumption() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
           DECLARE v_period_start DATE;
BEGIN
                   v_period_start := DATE_TRUNC('month', New.start_time )::DATE;
                                  PERFORM initialize_consumption_period(v_period_start);
RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_initialize_consumption() OWNER TO zkhattab;

--
-- Name: auto_rate_cdr(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.auto_rate_cdr() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
           IF NEW.service_id IS NOT NULL THEN
              PERFORM rate_cdr(NEW.id);
END IF;
RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_rate_cdr() OWNER TO zkhattab;

--
-- Name: cancel_addon(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.cancel_addon(p_addon_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE contract_addon
    SET is_active = FALSE
    WHERE id = p_addon_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Add-on % not found', p_addon_id;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'cancel_addon failed: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.cancel_addon(p_addon_id integer) OWNER TO zkhattab;

--
-- Name: change_contract_rateplan(integer, integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.change_contract_rateplan(p_contract_id integer, p_new_rateplan_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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

        -- Excess units × old ROR rates
        v_prorated_charge :=
            (v_voice_overage * COALESCE(v_old_ror_voice, 0)) +
            (v_data_overage  * COALESCE(v_old_ror_data,  0)) +
            (v_sms_overage   * COALESCE(v_old_ror_sms,   0));

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
$$;


ALTER FUNCTION public.change_contract_rateplan(p_contract_id integer, p_new_rateplan_id integer) OWNER TO zkhattab;

--
-- Name: change_contract_status(integer, public.contract_status); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.change_contract_status(p_contract_id integer, p_status public.contract_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_msisdn VARCHAR(20);
BEGIN
    SELECT msisdn INTO v_msisdn
    FROM contract WHERE id = p_contract_id;

    UPDATE contract SET status = p_status WHERE id = p_contract_id;

    -- Release number back to pool if terminated
    IF p_status = 'terminated' THEN
        PERFORM release_msisdn(v_msisdn);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'change_contract_status failed for contract id %: %',
            p_contract_id, SQLERRM;
END;
$$;


ALTER FUNCTION public.change_contract_status(p_contract_id integer, p_status public.contract_status) OWNER TO zkhattab;

--
-- Name: create_admin(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.create_admin(p_username character varying, p_password character varying, p_name character varying, p_email character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    -- Admins don't strictly need a customer profile in the teammate logic, 
    -- but they need a record in user_account.
    INSERT INTO user_account (username, password, role, customer_id)
    VALUES (p_username, p_password, 'admin', NULL)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'create_admin failed: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.create_admin(p_username character varying, p_password character varying, p_name character varying, p_email character varying) OWNER TO zkhattab;

--
-- Name: create_admin(character varying, character varying, character varying, character varying, text, date); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.create_admin(p_username character varying, p_password character varying, p_name character varying, p_email character varying, p_address text, p_birthdate date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
v_new_id INTEGER;
BEGIN
INSERT INTO user_account (username, password, role, name, email, address, birthdate)
VALUES (p_username, p_password, 'admin', p_name, p_email, p_address, p_birthdate)
    RETURNING id INTO v_new_id;

RETURN v_new_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'create_admin failed for username %: %', p_username, SQLERRM;
END;
$$;


ALTER FUNCTION public.create_admin(p_username character varying, p_password character varying, p_name character varying, p_email character varying, p_address text, p_birthdate date) OWNER TO zkhattab;

--
-- Name: create_contract(integer, integer, character varying, double precision); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.create_contract(p_user_account_id integer, p_rateplan_id integer, p_msisdn character varying, p_credit_limit double precision) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_contract_id  INTEGER;
    v_period_start DATE;
    v_period_end   DATE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_account WHERE id = p_user_account_id) THEN
        RAISE EXCEPTION 'Customer with id % does not exist', p_user_account_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM rateplan WHERE id = p_rateplan_id) THEN
        RAISE EXCEPTION 'Rateplan with id % does not exist', p_rateplan_id;
    END IF;

    IF EXISTS (SELECT 1 FROM contract WHERE msisdn = p_msisdn) THEN
        RAISE EXCEPTION 'MSISDN % is already assigned to another contract', p_msisdn;
    END IF;

    -- Check MSISDN is actually available in the pool
    IF NOT EXISTS (
        SELECT 1 FROM msisdn_pool
        WHERE msisdn = p_msisdn AND is_available = TRUE
    ) THEN
        RAISE EXCEPTION 'MSISDN % is not available', p_msisdn;
    END IF;

    INSERT INTO contract (
        user_account_id, rateplan_id, msisdn,
        status, credit_limit, available_credit
    ) VALUES (
                 p_user_account_id, p_rateplan_id, p_msisdn,
                 'active', p_credit_limit::NUMERIC, p_credit_limit::NUMERIC
             ) RETURNING id INTO v_contract_id;

    -- Mark MSISDN as taken
    PERFORM mark_msisdn_taken(p_msisdn);

    INSERT INTO ror_contract (contract_id, rateplan_id, voice, data, sms)
    VALUES (v_contract_id, p_rateplan_id, 0, 0, 0);

    v_period_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_period_end   := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;

    INSERT INTO contract_consumption (
        contract_id, service_package_id, rateplan_id,
        starting_date, ending_date, consumed, quota_limit, is_billed
    )
    SELECT v_contract_id, rsp.service_package_id, p_rateplan_id,
           v_period_start, v_period_end, 0, sp.amount, FALSE
    FROM rateplan_service_package rsp
    JOIN service_package sp ON rsp.service_package_id = sp.id
    WHERE rsp.rateplan_id = p_rateplan_id
    ON CONFLICT DO NOTHING;

    RETURN v_contract_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'create_contract failed: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.create_contract(p_user_account_id integer, p_rateplan_id integer, p_msisdn character varying, p_credit_limit double precision) OWNER TO zkhattab;

--
-- Name: create_customer(character varying, character varying, character varying, character varying, text, date); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.create_customer(p_username character varying, p_password character varying, p_name character varying, p_email character varying, p_address text, p_birthdate date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
v_new_id INTEGER;
BEGIN
INSERT INTO user_account (username, password, role, name, email, address, birthdate)
VALUES (p_username, p_password, 'customer', p_name, p_email, p_address, p_birthdate)
    RETURNING id INTO v_new_id;

RETURN v_new_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'create_customer failed for username %: %', p_username, SQLERRM;
END;
$$;


ALTER FUNCTION public.create_customer(p_username character varying, p_password character varying, p_name character varying, p_email character varying, p_address text, p_birthdate date) OWNER TO zkhattab;

--
-- Name: create_file_record(text); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.create_file_record(p_file_path text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
          DECLARE v_new_id INTEGER;
BEGIN
INSERT INTO file (file_path) VALUES (p_file_path)
    RETURNING id INTO v_new_id;
RETURN v_new_id;
EXCEPTION
    WHEN OTHERS THEN
RAISE EXCEPTION 'create_file_record failed for file path %: %', p_file_path, SQLERRM;
END;
$$;


ALTER FUNCTION public.create_file_record(p_file_path text) OWNER TO zkhattab;

--
-- Name: create_service_package(character varying, public.service_type, numeric, integer, numeric, text, boolean); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.create_service_package(p_name character varying, p_type public.service_type, p_amount numeric, p_priority integer, p_price numeric, p_description text, p_is_roaming boolean DEFAULT false) RETURNS TABLE(id integer, name character varying, type public.service_type, amount numeric, priority integer, price numeric, description text, is_roaming boolean)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.create_service_package(p_name character varying, p_type public.service_type, p_amount numeric, p_priority integer, p_price numeric, p_description text, p_is_roaming boolean) OWNER TO zkhattab;

--
-- Name: expire_addons(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.expire_addons() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE contract_addon
    SET is_active = FALSE
    WHERE expiry_date < CURRENT_DATE
      AND is_active   = TRUE;
END;
$$;


ALTER FUNCTION public.expire_addons() OWNER TO zkhattab;

--
-- Name: generate_all_bills(date); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.generate_all_bills(p_period_start date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_contract RECORD;
    v_success  INTEGER := 0;
    v_failed   INTEGER := 0;
BEGIN
    -- Expire any add-ons from last period first
    PERFORM expire_addons();

    FOR v_contract IN
        SELECT id FROM contract 
        WHERE status = 'active'
          AND id NOT IN (SELECT contract_id FROM bill WHERE billing_period_start = p_period_start)
    LOOP
        BEGIN
            PERFORM generate_bill(v_contract.id, p_period_start);
            v_success := v_success + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'generate_bill failed for contract %: %',
                    v_contract.id, SQLERRM;
                v_failed := v_failed + 1;
        END;
    END LOOP;

    RAISE NOTICE 'generate_all_bills complete: % succeeded, % failed',
        v_success, v_failed;
END;
$$;


ALTER FUNCTION public.generate_all_bills(p_period_start date) OWNER TO zkhattab;

--
-- Name: generate_bill(integer, date); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.generate_bill(p_contract_id integer, p_billing_period_start date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
    DECLARE
        v_billing_period_end DATE;
        v_recurring_fees NUMERIC(12,2);
        v_voice_usage INTEGER;
        v_data_usage INTEGER;
        v_sms_usage INTEGER;
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
    BEGIN
        v_billing_period_end := (DATE_TRUNC('month', p_billing_period_start) + INTERVAL '1 month - 1 day')::DATE;
        SELECT rateplan_id, msisdn INTO v_rateplan_id, v_msisdn FROM contract WHERE id = p_contract_id;
        SELECT price, ror_voice, ror_data, ror_sms INTO v_recurring_fees, v_ror_rate_v, v_ror_rate_d, v_ror_rate_s FROM rateplan WHERE id = v_rateplan_id;

        -- Calculate actual usage from contract_consumption (normalized units)
        SELECT
            COALESCE(SUM(CASE WHEN sp.type::TEXT = 'voice' THEN cc.consumed ELSE 0 END), 0)::INT,
            COALESCE(SUM(CASE WHEN sp.type::TEXT = 'data' THEN cc.consumed ELSE 0 END), 0)::INT,
            COALESCE(SUM(CASE WHEN sp.type::TEXT = 'sms' THEN cc.consumed ELSE 0 END), 0)::INT
        INTO v_voice_usage, v_data_usage, v_sms_usage
        FROM contract_consumption cc
        JOIN service_package sp ON cc.service_package_id = sp.id
        WHERE cc.contract_id = p_contract_id AND cc.starting_date = p_billing_period_start;

        -- Calculate overage charges from ror_contract (units * rates)
        SELECT
            COALESCE(SUM((voice * v_ror_rate_v) + (data / 1073741824.0 * v_ror_rate_d) + (sms * v_ror_rate_s)), 0),
            COALESCE(SUM((roaming_voice * v_ror_rate_v) + (roaming_data / 1073741824.0 * v_ror_rate_d) + (roaming_sms * v_ror_rate_s)), 0)
        INTO v_overage_charge, v_roaming_charge
        FROM ror_contract 
        WHERE contract_id = p_contract_id 
          AND starting_date = p_billing_period_start
          AND bill_id IS NULL;

        v_overage_charge := COALESCE(v_overage_charge, 0);
        v_roaming_charge := COALESCE(v_roaming_charge, 0);

        -- Calculate Promotional Savings (free units don't cost anything)
        -- For now, set to 0 as promotional discounts should be calculated separately
        v_promo_discount := 0;

        -- Calculate subtotal and taxes
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
        UPDATE contract_consumption SET bill_id = v_bill_id, is_billed = TRUE WHERE contract_id = p_contract_id AND starting_date = p_billing_period_start;

        RETURN v_bill_id;
    END;
$$;


ALTER FUNCTION public.generate_bill(p_contract_id integer, p_billing_period_start date) OWNER TO zkhattab;

--
-- Name: generate_bulk_missing(text); Type: PROCEDURE; Schema: public; Owner: zkhattab
--

CREATE PROCEDURE public.generate_bulk_missing(IN p_search text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_contract_id INTEGER;
    v_period_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
BEGIN
    FOR v_contract_id IN
        SELECT c.id
        FROM contract c
        JOIN user_account u ON c.user_account_id = u.id
        LEFT JOIN rateplan r ON c.rateplan_id = r.id
        WHERE c.status IN ('active', 'suspended', 'suspended_debt')
          AND NOT EXISTS (
            SELECT 1 FROM bill b
            WHERE b.contract_id = c.id
              AND b.billing_period_start = v_period_start
          )
          AND (p_search IS NULL OR p_search = '' OR
               c.msisdn ILIKE '%' || p_search || '%' OR
               u.name ILIKE '%' || p_search || '%' OR
               r.name ILIKE '%' || p_search || '%')
    LOOP
        PERFORM generate_bill(v_contract_id, v_period_start);
    END LOOP;
END;
$$;


ALTER PROCEDURE public.generate_bulk_missing(IN p_search text) OWNER TO zkhattab;

--
-- Name: generate_invoice(integer, text); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.generate_invoice(p_bill_id integer, p_pdf_path text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
INSERT INTO invoice (bill_id, pdf_path)
VALUES (p_bill_id, p_pdf_path);
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'generate_invoice failed for bill id %: %', p_bill_id, SQLERRM;
END;
$$;


ALTER FUNCTION public.generate_invoice(p_bill_id integer, p_pdf_path text) OWNER TO zkhattab;

--
-- Name: get_admin_stats(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_admin_stats() RETURNS TABLE(customers bigint, contracts bigint, cdrs bigint, revenue numeric, pending_bills bigint)
    LANGUAGE plpgsql
    AS $$ 
BEGIN 
    RETURN QUERY SELECT 
        (SELECT COUNT(*) FROM customer) AS customers, 
        (SELECT COUNT(*) FROM contract) AS contracts, 
        (SELECT COUNT(*) FROM cdr) AS cdrs,
        (SELECT COALESCE(SUM(total_amount), 0) FROM bill WHERE is_paid = TRUE) AS revenue,
        (SELECT COUNT(*) FROM bill WHERE is_paid = FALSE) AS pending_bills; 
END; 
$$;


ALTER FUNCTION public.get_admin_stats() OWNER TO zkhattab;

--
-- Name: get_all_bills(text, integer, integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_all_bills(p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, contract_id integer, billing_date date, billing_period_start date, billing_period_end date, total_amount numeric, is_paid boolean, status character varying, voice_usage integer, data_usage integer, sms_usage integer, customer_name character varying, msisdn character varying, total_count bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total BIGINT;
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
        SELECT
            b.id,
            b.contract_id,
            b.billing_date,
            b.billing_period_start,
            b.billing_period_end,
            b.total_amount,
            b.is_paid,
            b.status::VARCHAR(20) AS status,
            b.voice_usage,
            b.data_usage,
            b.sms_usage,
            ua.name AS customer_name,
            c.msisdn,
            v_total
        FROM bill b
        JOIN contract c ON b.contract_id = c.id
        JOIN user_account ua ON c.user_account_id = ua.id
        WHERE (p_search IS NULL OR p_search = '' OR
               ua.name ILIKE '%' || p_search || '%' OR
               c.msisdn ILIKE '%' || p_search || '%' OR
               b.status::TEXT ILIKE '%' || p_search || '%')
        ORDER BY b.billing_date DESC
        LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION public.get_all_bills(p_search text, p_limit integer, p_offset integer) OWNER TO zkhattab;

--
-- Name: get_all_contracts(text, integer, integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_all_contracts(p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, msisdn character varying, status public.contract_status, available_credit numeric, customer_name character varying, rateplan_name character varying, total_count bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total BIGINT;
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
        SELECT
            c.id,
            c.msisdn,
            c.status,
            c.available_credit,
            u.name  AS customer_name,
            r.name  AS rateplan_name,
            v_total
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
$$;


ALTER FUNCTION public.get_all_contracts(p_search text, p_limit integer, p_offset integer) OWNER TO zkhattab;

--
-- Name: get_all_customers(text, integer, integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_all_customers(p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, username character varying, name character varying, email character varying, role public.user_role, address text, birthdate date, msisdn character varying, total_count bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(DISTINCT ua.id) INTO v_total
    FROM user_account ua
    LEFT JOIN contract c ON ua.id = c.user_account_id
    WHERE ua.role = 'customer'
      AND (p_search IS NULL OR p_search = '' OR
           ua.name ILIKE '%' || p_search || '%' OR
           ua.email ILIKE '%' || p_search || '%' OR
           ua.username ILIKE '%' || p_search || '%' OR
           c.msisdn ILIKE '%' || p_search || '%');

    RETURN QUERY
        SELECT DISTINCT ON (ua.id)
            ua.id,
            ua.username,
            ua.name,
            ua.email,
            ua.role,
            ua.address,
            ua.birthdate,
            c.msisdn,
            v_total
        FROM user_account ua
        LEFT JOIN contract c ON ua.id = c.user_account_id
        WHERE ua.role = 'customer'
          AND (p_search IS NULL OR p_search = '' OR
               ua.name ILIKE '%' || p_search || '%' OR
               ua.email ILIKE '%' || p_search || '%' OR
               ua.username ILIKE '%' || p_search || '%' OR
               c.msisdn ILIKE '%' || p_search || '%')
        ORDER BY ua.id DESC
        LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION public.get_all_customers(p_search text, p_limit integer, p_offset integer) OWNER TO zkhattab;

--
-- Name: get_all_rateplans(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_all_rateplans() RETURNS TABLE(id integer, name character varying, price numeric, ror_voice numeric, ror_data numeric, ror_sms numeric)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_all_rateplans() OWNER TO zkhattab;

--
-- Name: get_all_service_packages(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_all_service_packages() RETURNS TABLE(id integer, name character varying, type public.service_type, amount numeric, priority integer, price numeric, description text, is_roaming boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            sp.id,
            sp.name,
            sp.type,
            sp.amount,
            sp.priority,
            sp.price,
            sp.description,
            sp.is_roaming
        FROM service_package sp
        ORDER BY sp.type, sp.priority ASC;
END;
$$;


ALTER FUNCTION public.get_all_service_packages() OWNER TO zkhattab;

--
-- Name: get_available_msisdns(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_available_msisdns() RETURNS TABLE(id integer, msisdn character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT mp.id, mp.msisdn
        FROM msisdn_pool mp
        WHERE mp.is_available = TRUE
        ORDER BY mp.msisdn;
END;
$$;


ALTER FUNCTION public.get_available_msisdns() OWNER TO zkhattab;

--
-- Name: get_bill(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_bill(p_bill_id integer) RETURNS TABLE(contract_id integer, billing_period_start date, billing_period_end date, billing_date date, recurring_fees numeric, one_time_fees numeric, voice_usage integer, data_usage integer, sms_usage integer, ror_charge numeric, taxes numeric, total_amount numeric, status public.bill_status, is_paid boolean)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_bill(p_bill_id integer) OWNER TO zkhattab;

--
-- Name: get_bill_usage_breakdown(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_bill_usage_breakdown(p_bill_id integer) RETURNS TABLE(service_type text, category_label text, quota integer, consumed integer, unit_rate numeric, line_total numeric, is_roaming boolean, is_promotional boolean, notes text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_contract_id INTEGER;
    v_period_start DATE;
BEGIN
    -- Get contract and period for this bill
    SELECT contract_id, billing_period_start INTO v_contract_id, v_period_start
    FROM bill WHERE id = p_bill_id;
    
    -- 1. Bundled usage from contract_consumption (linked by bill_id)
    RETURN QUERY
    SELECT 
        sp.type::TEXT AS service_type,
        sp.name::TEXT AS category_label,
        cc.quota_limit::INTEGER AS quota,
        cc.consumed::INTEGER AS consumed,
        0::NUMERIC(12,4) AS unit_rate,
        0::NUMERIC(12,2) AS line_total,
        sp.is_roaming,
        (sp.name ~* 'Welcome|Gift|Bonus|Bonus') AS is_promotional,
        CASE 
            WHEN cc.consumed >= cc.quota_limit THEN 'Bundle fully utilized'::TEXT
            ELSE 'Partial bundle usage'::TEXT
        END AS notes
    FROM contract_consumption cc
    JOIN service_package sp ON cc.service_package_id = sp.id
    WHERE cc.bill_id = p_bill_id
      AND cc.is_billed = TRUE
    
    UNION ALL
    
    -- 2. Domestic overage (from ror_contract non-roaming columns)
    SELECT 
        'voice'::TEXT AS service_type,
        'Overage - Voice'::TEXT AS category_label,
        NULL::INTEGER AS quota,
        rc.voice::INTEGER AS consumed,
        rp.ror_voice AS unit_rate,
        ROUND((rc.voice * rp.ror_voice)::NUMERIC, 2) AS line_total,
        FALSE AS is_roaming,
        FALSE AS is_promotional,
        'Overage minutes beyond bundle allowance'::TEXT AS notes
    FROM ror_contract rc
    JOIN rateplan rp ON rc.rateplan_id = rp.id
    WHERE rc.contract_id = v_contract_id
      AND rc.bill_id = p_bill_id
      AND rc.voice > 0
    
    UNION ALL
    SELECT 
        'data'::TEXT AS service_type,
        'Overage - Data'::TEXT AS category_label,
        NULL::INTEGER, 
        (rc.data / 1024 / 1024)::INTEGER, -- Show as MB in consumed
        rp.ror_data,
        ROUND((rc.data / 1073741824.0 * rp.ror_data)::NUMERIC, 2), -- Convert Bytes to GB for pricing
        FALSE, FALSE,
        'Overage data beyond bundle allowance'::TEXT
    FROM ror_contract rc JOIN rateplan rp ON rc.rateplan_id = rp.id
    WHERE rc.contract_id = v_contract_id AND rc.bill_id = p_bill_id AND rc.data > 0
    
    UNION ALL
    -- 3. Roaming overage (from ror_contract roaming columns)
    SELECT 
        'voice'::TEXT AS service_type,
        'Roaming Overage - Voice'::TEXT AS category_label,
        NULL::INTEGER, rc.roaming_voice::INTEGER, rp.ror_roaming_voice,
        ROUND((rc.roaming_voice * rp.ror_roaming_voice)::NUMERIC, 2),
        TRUE, FALSE, 'Roaming overage minutes'::TEXT
    FROM ror_contract rc JOIN rateplan rp ON rc.rateplan_id = rp.id
    WHERE rc.contract_id = v_contract_id AND rc.bill_id = p_bill_id AND rc.roaming_voice > 0
    
    UNION ALL
    SELECT 
        'data'::TEXT AS service_type,
        'Roaming Overage - Data'::TEXT AS category_label,
        NULL::INTEGER, (rc.roaming_data / 1024 / 1024)::INTEGER, rp.ror_roaming_data,
        ROUND((rc.roaming_data / 1073741824.0 * rp.ror_roaming_data)::NUMERIC, 2),
        TRUE, FALSE, 'Roaming overage data (MB)'::TEXT
    FROM ror_contract rc JOIN rateplan rp ON rc.rateplan_id = rp.id
    WHERE rc.contract_id = v_contract_id AND rc.bill_id = p_bill_id AND rc.roaming_data > 0
    
    UNION ALL
    SELECT 
        'sms'::TEXT AS service_type,
        'Overage - SMS'::TEXT AS category_label,
        NULL::INTEGER, rc.sms::INTEGER, rp.ror_sms,
        ROUND((rc.sms * rp.ror_sms)::NUMERIC, 2), FALSE, FALSE,
        'Overage SMS beyond bundle allowance'::TEXT
    FROM ror_contract rc JOIN rateplan rp ON rc.rateplan_id = rp.id
    WHERE rc.contract_id = v_contract_id AND rc.bill_id = p_bill_id AND rc.sms > 0

    UNION ALL
    SELECT 
        'sms'::TEXT AS service_type,
        'Roaming Overage - SMS'::TEXT AS category_label,
        NULL::INTEGER, rc.roaming_sms::INTEGER, rp.ror_roaming_sms,
        ROUND((rc.roaming_sms * rp.ror_roaming_sms)::NUMERIC, 2),
        TRUE, FALSE, 'Roaming overage SMS'::TEXT
    FROM ror_contract rc JOIN rateplan rp ON rc.rateplan_id = rp.id
    WHERE rc.contract_id = v_contract_id AND rc.bill_id = p_bill_id AND rc.roaming_sms > 0
    
    ORDER BY service_type, is_roaming DESC, category_label;
END;
$$;


ALTER FUNCTION public.get_bill_usage_breakdown(p_bill_id integer) OWNER TO zkhattab;

--
-- Name: get_bills_by_contract(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_bills_by_contract(p_contract_id integer) RETURNS TABLE(id integer, billing_period_start date, billing_period_end date, billing_date date, total_amount numeric, status public.bill_status)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY
SELECT b.id, b.billing_period_start, billing_period_end, billing_date, total_amount, status
FROM bill b WHERE b.contract_id = p_contract_id
ORDER BY billing_period_start DESC;
END;
$$;


ALTER FUNCTION public.get_bills_by_contract(p_contract_id integer) OWNER TO zkhattab;

--
-- Name: get_cdr_usage_amount(integer, public.service_type); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_cdr_usage_amount(p_duration integer, p_service_type public.service_type) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN CASE p_service_type
           WHEN 'voice' THEN CEIL(p_duration / 60.0)  -- convert seconds to minutes, round up
           WHEN 'data'  THEN p_duration
           WHEN 'sms'   THEN 1
           WHEN 'free_units' THEN p_duration
    END;
END;
$$;


ALTER FUNCTION public.get_cdr_usage_amount(p_duration integer, p_service_type public.service_type) OWNER TO zkhattab;

--
-- Name: get_cdrs(integer, integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_cdrs(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, msisdn character varying, destination character varying, duration integer, "timestamp" timestamp without time zone, rated boolean, type character varying, service_id integer, service_type text)
    LANGUAGE plpgsql
    AS $$
 BEGIN
     RETURN QUERY
     SELECT 
         c.id, 
         c.dial_a AS msisdn, 
         c.dial_b AS destination, 
         c.duration, 
         c.start_time AS "timestamp", 
         c.rated_flag AS rated,
         CASE 
            WHEN sp_rated.id IS NOT NULL THEN sp_rated.name
            WHEN c.external_charges > 0 THEN 'Overage (' || sp_base.name || ')'
            ELSE COALESCE(sp_base.name, 'Unrated')
         END AS type,
         COALESCE(c.rated_service_id, c.service_id) AS service_id,
         COALESCE(sp_rated.type::TEXT, sp_base.type::TEXT, 'other') AS service_type
     FROM cdr c
     LEFT JOIN service_package sp_rated ON c.rated_service_id = sp_rated.id
     LEFT JOIN service_package sp_base ON c.service_id = sp_base.id
     ORDER BY c.start_time DESC
     LIMIT p_limit OFFSET p_offset;
 END;
 $$;


ALTER FUNCTION public.get_cdrs(p_limit integer, p_offset integer) OWNER TO zkhattab;

--
-- Name: get_contract_addons(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_contract_addons(p_contract_id integer) RETURNS TABLE(id integer, service_package_id integer, package_name character varying, type public.service_type, amount numeric, purchased_date date, expiry_date date, price_paid numeric, is_active boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            ca.id,
            ca.service_package_id,
            sp.name        AS package_name,
            sp.type,
            sp.amount,
            ca.purchased_date,
            ca.expiry_date,
            ca.price_paid,
            ca.is_active
        FROM contract_addon ca
                 JOIN service_package sp ON sp.id = ca.service_package_id
        WHERE ca.contract_id = p_contract_id
        ORDER BY ca.purchased_date DESC;
END;
$$;


ALTER FUNCTION public.get_contract_addons(p_contract_id integer) OWNER TO zkhattab;

--
-- Name: get_contract_by_id(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_contract_by_id(p_id integer) RETURNS TABLE(id integer, user_account_id integer, rateplan_id integer, msisdn character varying, status public.contract_status, credit_limit numeric, available_credit numeric, customer_name character varying, rateplan_name character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_contract_by_id(p_id integer) OWNER TO zkhattab;

--
-- Name: get_contract_consumption(integer, date); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_contract_consumption(p_contract_id integer, p_period_start date) RETURNS TABLE(service_package_id integer, consumed integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY
SELECT service_package_id, consumed
FROM contract_consumption
WHERE contract_id = p_contract_id
  AND starting_date = p_period_start
  AND is_billed = FALSE;
END;
$$;


ALTER FUNCTION public.get_contract_consumption(p_contract_id integer, p_period_start date) OWNER TO zkhattab;

--
-- Name: get_customer_by_id(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_customer_by_id(p_id integer) RETURNS TABLE(id integer, username character varying, name character varying, email character varying, role public.user_role, address text, birthdate date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            ua.id,
            ua.username,
            ua.name,
            ua.email,
            ua.role,
            ua.address,
            ua.birthdate
        FROM user_account ua
        WHERE ua.id = p_id AND ua.role = 'customer';
END;
$$;


ALTER FUNCTION public.get_customer_by_id(p_id integer) OWNER TO zkhattab;

--
-- Name: get_dashboard_stats(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_dashboard_stats() RETURNS TABLE(total_customers bigint, total_contracts bigint, active_contracts bigint, suspended_contracts bigint, suspended_debt_contracts bigint, terminated_contracts bigint, total_cdrs bigint, revenue numeric, pending_bills bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            (SELECT COUNT(*) FROM user_account  WHERE role = 'customer'),
            (SELECT COUNT(*) FROM contract),
            (SELECT COUNT(*) FROM contract      WHERE status = 'active'),
            (SELECT COUNT(*) FROM contract      WHERE status = 'suspended'),
            (SELECT COUNT(*) FROM contract      WHERE status = 'suspended_debt'),
            (SELECT COUNT(*) FROM contract      WHERE status = 'terminated'),
            (SELECT COUNT(*) FROM cdr),
            (SELECT COALESCE(SUM(total_amount), 0) FROM bill WHERE status = 'paid'),
            (SELECT COUNT(*) FROM bill WHERE status = 'issued');
END;
$$;


ALTER FUNCTION public.get_dashboard_stats() OWNER TO zkhattab;

--
-- Name: get_missing_bills(text, integer, integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_missing_bills(p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(contract_id integer, msisdn character varying, customer_name character varying, rateplan_name character varying, last_bill_date date, total_count bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_period_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM contract c
    JOIN user_account u ON c.user_account_id = u.id
    LEFT JOIN rateplan r ON c.rateplan_id = r.id
    WHERE c.status IN ('active', 'suspended', 'suspended_debt')
      AND NOT EXISTS (
        SELECT 1 FROM bill b
        WHERE b.contract_id = c.id
          AND b.billing_period_start = v_period_start
      )
      AND (p_search IS NULL OR p_search = '' OR
           c.msisdn ILIKE '%' || p_search || '%' OR
           u.name ILIKE '%' || p_search || '%' OR
           r.name ILIKE '%' || p_search || '%');

    RETURN QUERY
        SELECT
            c.id           AS contract_id,
            c.msisdn,
            u.name         AS customer_name,
            r.name         AS rateplan_name,
            (SELECT MAX(billing_date) FROM bill b WHERE b.contract_id = c.id) AS last_bill_date,
            v_total AS total_count
        FROM contract c
                 JOIN user_account u ON c.user_account_id = u.id
                 LEFT JOIN rateplan r ON c.rateplan_id = r.id
        WHERE c.status IN ('active', 'suspended', 'suspended_debt')
          AND NOT EXISTS (
            SELECT 1 FROM bill b
            WHERE b.contract_id = c.id
              AND b.billing_period_start = v_period_start
          )
          AND (p_search IS NULL OR p_search = '' OR
               c.msisdn ILIKE '%' || p_search || '%' OR
               u.name ILIKE '%' || p_search || '%' OR
               r.name ILIKE '%' || p_search || '%')
        ORDER BY c.id
        LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION public.get_missing_bills(p_search text, p_limit integer, p_offset integer) OWNER TO zkhattab;

--
-- Name: get_rateplan_by_id(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_rateplan_by_id(p_id integer) RETURNS TABLE(id integer, name character varying, ror_voice numeric, ror_data numeric, ror_sms numeric, price numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            r.id,
            r.name,
            r.ror_voice,
            r.ror_data,
            r.ror_sms,
            r.price
        FROM rateplan r
        WHERE r.id = p_id;
END;
$$;


ALTER FUNCTION public.get_rateplan_by_id(p_id integer) OWNER TO zkhattab;

--
-- Name: get_rateplan_data(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_rateplan_data(p_rateplan_id integer) RETURNS TABLE(id integer, name character varying, ror_data numeric, ror_voice numeric, ror_sms numeric, price numeric)
    LANGUAGE plpgsql
    AS $$
 BEGIN
     RETURN QUERY
     SELECT
         r.id,
         r.name,
         r.ror_data,
         r.ror_voice,
         r.ror_sms,
         r.price
     FROM
         rateplan r
     WHERE
         r.id = p_rateplan_id;
 END;
 $$;


ALTER FUNCTION public.get_rateplan_data(p_rateplan_id integer) OWNER TO zkhattab;

--
-- Name: get_service_package_by_id(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_service_package_by_id(p_id integer) RETURNS TABLE(id integer, name character varying, type public.service_type, amount numeric, priority integer, price numeric, description text, is_roaming boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            sp.id,
            sp.name,
            sp.type,
            sp.amount,
            sp.priority,
            sp.price,
            sp.description,
            sp.is_roaming
        FROM service_package sp
        WHERE sp.id = p_id;
END;
$$;


ALTER FUNCTION public.get_service_package_by_id(p_id integer) OWNER TO zkhattab;

--
-- Name: get_user_contracts(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_user_contracts(p_user_id integer) RETURNS TABLE(id integer, msisdn character varying, status public.contract_status, available_credit numeric, credit_limit numeric, rateplan_name character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            c.id,
            c.msisdn,
            c.status,
            c.available_credit,
            c.credit_limit,
            r.name AS rateplan_name
        FROM contract c
                 LEFT JOIN rateplan r ON c.rateplan_id = r.id
        WHERE c.user_account_id = p_user_id;
END;
$$;


ALTER FUNCTION public.get_user_contracts(p_user_id integer) OWNER TO zkhattab;

--
-- Name: get_user_data(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_user_data(p_user_account_id integer) RETURNS TABLE(username character varying, role character varying, name character varying, email character varying, address text, birthdate date)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_user_data(p_user_account_id integer) OWNER TO zkhattab;

--
-- Name: get_user_invoices(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_user_invoices(p_user_id integer) RETURNS TABLE(id integer, contract_id integer, billing_period_start date, billing_period_end date, billing_date date, recurring_fees numeric, one_time_fees numeric, voice_usage integer, data_usage integer, sms_usage integer, ror_charge numeric, taxes numeric, total_amount numeric, status public.bill_status, is_paid boolean, pdf_path text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            b.id,
            b.contract_id,
            b.billing_period_start,
            b.billing_period_end,
            b.billing_date,
            b.recurring_fees,
            b.one_time_fees,
            b.voice_usage,
            b.data_usage,
            b.sms_usage,
            b.ror_charge,
            b.taxes,
            b.total_amount,
            b.status,
            b.is_paid,
            i.pdf_path
        FROM bill b
                 JOIN contract c ON b.contract_id = c.id
                 LEFT JOIN invoice i on b.id = i.bill_id
        WHERE c.user_account_id = p_user_id
        ORDER BY b.billing_date DESC;
END;
$$;


ALTER FUNCTION public.get_user_invoices(p_user_id integer) OWNER TO zkhattab;

--
-- Name: get_user_msisdn_bill(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.get_user_msisdn_bill(p_contract_id integer) RETURNS TABLE(user_account_id integer, msisdn character varying, bill_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.user_account_id,
        c.msisdn,
        b.id AS bill_id
    FROM contract c
    LEFT JOIN bill b ON b.contract_id = c.id
    WHERE c.id = p_contract_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No contract found with id %', p_contract_id;
    END IF;
END;
$$;


ALTER FUNCTION public.get_user_msisdn_bill(p_contract_id integer) OWNER TO zkhattab;

--
-- Name: initialize_consumption_period(date); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.initialize_consumption_period(p_period_start date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_period_end DATE;
BEGIN
    v_period_end := (DATE_TRUNC('month', p_period_start) + INTERVAL '1 month - 1 day')::DATE;

INSERT INTO contract_consumption (
    contract_id,
    service_package_id,
    rateplan_id,
    starting_date,
    ending_date,
    consumed,
    quota_limit,
    is_billed
)
SELECT
    c.id,
    rsp.service_package_id,
    c.rateplan_id,
    p_period_start,
    v_period_end,
    0,
    sp.amount, 
    FALSE
FROM contract c
         JOIN rateplan_service_package rsp ON rsp.rateplan_id = c.rateplan_id
         JOIN service_package sp ON sp.id = rsp.service_package_id
WHERE c.status = 'active'
    ON CONFLICT DO NOTHING;

END;
$$;


ALTER FUNCTION public.initialize_consumption_period(p_period_start date) OWNER TO zkhattab;

--
-- Name: insert_cdr(integer, character varying, character varying, timestamp without time zone, integer, integer, character varying, character varying, numeric); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.insert_cdr(p_file_id integer, p_dial_a character varying, p_dial_b character varying, p_start_time timestamp without time zone, p_duration integer, p_service_id integer, p_hplmn character varying, p_vplmn character varying, p_external_charges numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
v_new_id INTEGER;
BEGIN
    -- Validate file exists
    IF NOT EXISTS (SELECT 1 FROM file WHERE id = p_file_id) THEN
        RAISE EXCEPTION 'File with id % does not exist', p_file_id;
END IF;

    -- Validate service_package exists if provided
    IF p_service_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM service_package WHERE id = p_service_id
    ) THEN
        RAISE EXCEPTION 'Service package with id % does not exist', p_service_id;
END IF;

    -- Validate dial_a is not empty
    IF p_dial_a IS NULL OR TRIM(p_dial_a) = '' THEN
        RAISE EXCEPTION 'dial_a (calling party MSISDN) cannot be empty';
END IF;

    -- Validate duration is non-negative
    IF p_duration < 0 THEN
        RAISE EXCEPTION 'Duration cannot be negative';
END IF;

INSERT INTO cdr (
    file_id,
    dial_a,
    dial_b,
    start_time,
    duration,
    service_id,
    hplmn,
    vplmn,
    external_charges,
    rated_flag
)
VALUES (
           p_file_id,
           p_dial_a,
           p_dial_b,
           p_start_time,
           p_duration,
           p_service_id,
           p_hplmn,
           p_vplmn,
           COALESCE(p_external_charges, 0),
           FALSE
       )
    RETURNING id INTO v_new_id;

RETURN v_new_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'insert_cdr failed: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.insert_cdr(p_file_id integer, p_dial_a character varying, p_dial_b character varying, p_start_time timestamp without time zone, p_duration integer, p_service_id integer, p_hplmn character varying, p_vplmn character varying, p_external_charges numeric) OWNER TO zkhattab;

--
-- Name: login(character varying, character varying); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.login(p_username character varying, p_password character varying) RETURNS TABLE(id integer, username character varying, name character varying, email character varying, role public.user_role)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            ua.id,
            ua.username,
            ua.name,
            ua.email,
            ua.role
        FROM user_account ua
        WHERE ua.username = p_username
          AND ua.password = p_password;
END;
$$;


ALTER FUNCTION public.login(p_username character varying, p_password character varying) OWNER TO zkhattab;

--
-- Name: mark_bill_paid(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.mark_bill_paid(p_bill_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
UPDATE bill
SET is_paid = TRUE, status = 'paid'
WHERE id = p_bill_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'mark_bill_paid failed for bill id %: %', p_bill_id, SQLERRM;
END;
$$;


ALTER FUNCTION public.mark_bill_paid(p_bill_id integer) OWNER TO zkhattab;

--
-- Name: mark_msisdn_taken(character varying); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.mark_msisdn_taken(p_msisdn character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE msisdn_pool
    SET is_available = FALSE
    WHERE msisdn = p_msisdn;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'MSISDN % not found in pool', p_msisdn;
    END IF;
END;
$$;


ALTER FUNCTION public.mark_msisdn_taken(p_msisdn character varying) OWNER TO zkhattab;

--
-- Name: notify_bill_generation(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.notify_bill_generation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM pg_notify('generate_bill_event', NEW.id::text);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_bill_generation() OWNER TO zkhattab;

--
-- Name: pay_bill(integer, text); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.pay_bill(p_bill_id integer, p_pdf_path text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
         -- Mark bill as paid
         PERFORM mark_bill_paid(p_bill_id);
         -- Generate invoice PDF
         PERFORM generate_invoice(p_bill_id, p_pdf_path);
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'pay_bill failed for bill id %: %', p_bill_id, SQLERRM;
END;
$$;


ALTER FUNCTION public.pay_bill(p_bill_id integer, p_pdf_path text) OWNER TO zkhattab;

--
-- Name: purchase_addon(integer, integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.purchase_addon(p_contract_id integer, p_service_package_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_addon_id     INTEGER;
    v_pkg_price    NUMERIC(12,2);
    v_pkg_amount   NUMERIC(12,4);
    v_pkg_type     service_type;
    v_expiry       DATE;
    v_period_start DATE;
    v_period_end   DATE;
BEGIN
    -- Validate contract exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM contract WHERE id = p_contract_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Contract % is not active', p_contract_id;
    END IF;

    -- Validate service package exists
    SELECT price, amount, type
    INTO v_pkg_price, v_pkg_amount, v_pkg_type
    FROM service_package
    WHERE id = p_service_package_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service package % not found', p_service_package_id;
    END IF;

    -- [RULE] Welcome Bonus is only once per lifetime per customer (across all their lines)
    IF EXISTS (
        SELECT 1 FROM service_package sp
        WHERE sp.id = p_service_package_id AND sp.name = '🎁 Welcome Gift'
    ) AND EXISTS (
        SELECT 1 FROM contract_addon ca
        JOIN service_package sp ON ca.service_package_id = sp.id
        JOIN contract c ON ca.contract_id = c.id
        WHERE c.user_account_id = (SELECT user_account_id FROM contract WHERE id = p_contract_id)
          AND sp.name = '🎁 Welcome Gift'
    ) THEN
        RAISE EXCEPTION 'Welcome Bonus can only be provisioned once per customer';
    END IF;

    -- Check customer has enough credit
    IF NOT EXISTS (
        SELECT 1 FROM contract
        WHERE id = p_contract_id
          AND available_credit >= COALESCE(v_pkg_price, 0)
    ) THEN
        RAISE EXCEPTION 'Insufficient credit to purchase add-on';
    END IF;

    -- Expiry = end of current billing month
    v_expiry := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;

    -- Insert addon record
    INSERT INTO contract_addon (
        contract_id, service_package_id,
        purchased_date, expiry_date,
        is_active, price_paid
    ) VALUES (
                 p_contract_id, p_service_package_id,
                 CURRENT_DATE, v_expiry,
                 TRUE, COALESCE(v_pkg_price, 0)
             ) RETURNING id INTO v_addon_id;

    -- Deduct price from available credit
    UPDATE contract
    SET available_credit = available_credit - COALESCE(v_pkg_price, 0)
    WHERE id = p_contract_id;

    -- Update or Insert consumption row
    v_period_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_period_end   := v_expiry;

    INSERT INTO contract_consumption (
        contract_id, service_package_id, rateplan_id,
        starting_date, ending_date, consumed, quota_limit, is_billed
    )
    SELECT
        p_contract_id,
        p_service_package_id,
        c.rateplan_id,
        v_period_start,
        v_period_end,
        0,
        v_pkg_amount,
        FALSE
    FROM contract c
    WHERE c.id = p_contract_id
    ON CONFLICT (contract_id, service_package_id, rateplan_id, starting_date, ending_date)
    DO UPDATE SET quota_limit = contract_consumption.quota_limit + EXCLUDED.quota_limit;

    RETURN v_addon_id;
END;
$$;


ALTER FUNCTION public.purchase_addon(p_contract_id integer, p_service_package_id integer) OWNER TO zkhattab;

--
-- Name: rate_cdr(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.rate_cdr(p_cdr_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
 DECLARE
     v_cdr RECORD;
     v_contract RECORD;
     v_service_type VARCHAR;
     v_bundle RECORD;
     v_remaining NUMERIC;
     v_deduct NUMERIC;
     v_available NUMERIC;
     v_ror_rate NUMERIC;
     v_ror_rate_v NUMERIC;
     v_ror_rate_d NUMERIC;
     v_ror_rate_s NUMERIC;
     v_overage_charge NUMERIC := 0;
     v_rated_service_id INTEGER;
     v_is_roaming BOOLEAN;
     v_period_start DATE;
 BEGIN
     SELECT * INTO v_cdr FROM cdr WHERE id = p_cdr_id;
     
     -- Only rate for ACTIVE contracts
     SELECT * INTO v_contract FROM contract WHERE msisdn = v_cdr.dial_a AND status = 'active';
     
     IF NOT FOUND THEN
         UPDATE cdr SET rated_flag = TRUE, external_charges = 0, rated_service_id = NULL WHERE id = p_cdr_id;
         RETURN;
     END IF;

     SELECT type::TEXT INTO v_service_type FROM service_package WHERE id = v_cdr.service_id;
     v_remaining := get_cdr_usage_amount(v_cdr.duration, v_service_type::service_type);
     v_is_roaming := (v_cdr.vplmn IS NOT NULL AND v_cdr.vplmn != '');

     -- Determine billing period for this CDR
     v_period_start := DATE_TRUNC('month', v_cdr.start_time)::DATE;

     FOR v_bundle IN
         SELECT cc.contract_id, cc.service_package_id, cc.rateplan_id, cc.consumed, cc.quota_limit, sp.name, sp.is_roaming as pkg_roaming
         FROM contract_consumption cc
         JOIN service_package sp ON cc.service_package_id = sp.id
         WHERE cc.contract_id = v_contract.id AND cc.is_billed = FALSE
           AND cc.starting_date = v_period_start
           AND (sp.type::TEXT = v_service_type OR sp.type::TEXT = 'free_units')
           AND (sp.is_roaming = v_is_roaming OR sp.type::TEXT = 'free_units')
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
            AND rateplan_id = v_bundle.rateplan_id
            AND starting_date = v_period_start;
          v_rated_service_id := v_bundle.service_package_id;
      END LOOP;

      IF v_remaining > 0 THEN
          IF v_is_roaming THEN
              INSERT INTO ror_contract (contract_id, rateplan_id, starting_date, roaming_voice, roaming_data, roaming_sms)
              VALUES (v_contract.id, v_contract.rateplan_id, v_period_start,
                     CASE WHEN v_service_type='voice' THEN v_remaining ELSE 0 END,
                     CASE WHEN v_service_type='data'  THEN v_remaining ELSE 0 END,
                     CASE WHEN v_service_type='sms'   THEN v_remaining ELSE 0 END)
              ON CONFLICT (contract_id, rateplan_id, starting_date) DO UPDATE SET
                 roaming_voice = ror_contract.roaming_voice + EXCLUDED.roaming_voice,
                 roaming_data = ror_contract.roaming_data + EXCLUDED.roaming_data,
                 roaming_sms = ror_contract.roaming_sms + EXCLUDED.roaming_sms;
          ELSE
              INSERT INTO ror_contract (contract_id, rateplan_id, starting_date, voice, data, sms)
              VALUES (v_contract.id, v_contract.rateplan_id, v_period_start,
                     CASE WHEN v_service_type='voice' THEN v_remaining ELSE 0 END,
                     CASE WHEN v_service_type='data'  THEN v_remaining ELSE 0 END,
                     CASE WHEN v_service_type='sms'   THEN v_remaining ELSE 0 END)
              ON CONFLICT (contract_id, rateplan_id, starting_date) DO UPDATE SET
                 voice = ror_contract.voice + EXCLUDED.voice,
                 data = ror_contract.data + EXCLUDED.data,
                 sms = ror_contract.sms + EXCLUDED.sms;
          END IF;

          -- Calculate charge for the CDR record
          SELECT 
            CASE WHEN v_is_roaming THEN ror_roaming_voice ELSE ror_voice END as v_rate,
            CASE WHEN v_is_roaming THEN ror_roaming_data ELSE ror_data END as d_rate,
            CASE WHEN v_is_roaming THEN ror_roaming_sms ELSE ror_sms END as s_rate
          INTO v_ror_rate_v, v_ror_rate_d, v_ror_rate_s
          FROM rateplan WHERE id = v_contract.rateplan_id;

          IF v_service_type = 'voice' THEN v_ror_rate := v_ror_rate_v;
          ELSIF v_service_type = 'data' THEN v_ror_rate := v_ror_rate_d;
          ELSIF v_service_type = 'sms' THEN v_ror_rate := v_ror_rate_s;
          END IF;
          
          IF v_service_type = 'data' THEN
              v_overage_charge := (v_remaining / 1073741824.0) * COALESCE(v_ror_rate, 0);
          ELSE
              v_overage_charge := v_remaining * COALESCE(v_ror_rate, 0);
          END IF;

          -- Deduct from available_credit
          UPDATE contract 
          SET available_credit = available_credit - v_overage_charge
          WHERE id = v_contract.id;
      END IF;

     UPDATE cdr SET rated_flag = TRUE, external_charges = v_overage_charge, rated_service_id = v_rated_service_id WHERE id = p_cdr_id;
 END;
$$;


ALTER FUNCTION public.rate_cdr(p_cdr_id integer) OWNER TO zkhattab;

--
-- Name: release_msisdn(character varying); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.release_msisdn(p_msisdn character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE msisdn_pool
    SET is_available = TRUE
    WHERE msisdn = p_msisdn;
END;
$$;


ALTER FUNCTION public.release_msisdn(p_msisdn character varying) OWNER TO zkhattab;

--
-- Name: set_file_parsed(integer); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.set_file_parsed(p_file_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
UPDATE file
SET parsed_flag = TRUE
WHERE id = p_file_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'set_file_parsed failed for file id %: %', p_file_id, SQLERRM;
END;
$$;


ALTER FUNCTION public.set_file_parsed(p_file_id integer) OWNER TO zkhattab;

--
-- Name: trg_restore_credit_on_payment(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.trg_restore_credit_on_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.is_paid = TRUE AND OLD.is_paid = FALSE THEN
UPDATE contract
SET available_credit = credit_limit
WHERE id = NEW.contract_id;
END IF;
RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_restore_credit_on_payment() OWNER TO zkhattab;

--
-- Name: validate_cdr_contract(); Type: FUNCTION; Schema: public; Owner: zkhattab
--

CREATE FUNCTION public.validate_cdr_contract() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
       DECLARE v_contract contract;
BEGIN
SELECT c.* INTO v_contract
FROM contract c WHERE c.msisdn = NEW.dial_a;
IF NOT FOUND THEN
   RAISE EXCEPTION 'No contract found for MSISDN %', NEW.dial_a;
END IF ;
   IF v_contract.status <> 'active' THEN
      RAISE EXCEPTION 'contract for MSISDN % is not active it is %', NEW.dial_a, v_contract.status;
END IF;
RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_cdr_contract() OWNER TO zkhattab;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bill; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.bill (
    id integer NOT NULL,
    contract_id integer NOT NULL,
    billing_period_start date NOT NULL,
    billing_period_end date NOT NULL,
    billing_date date NOT NULL,
    recurring_fees numeric(12,2) DEFAULT 0 NOT NULL,
    one_time_fees numeric(12,2) DEFAULT 0 NOT NULL,
    voice_usage integer DEFAULT 0 NOT NULL,
    data_usage integer DEFAULT 0 NOT NULL,
    sms_usage integer DEFAULT 0 NOT NULL,
    ror_charge numeric(12,2) DEFAULT 0 NOT NULL,
    overage_charge numeric(12,2) DEFAULT 0 NOT NULL,
    roaming_charge numeric(12,2) DEFAULT 0 NOT NULL,
    promotional_discount numeric(12,2) DEFAULT 0 NOT NULL,
    taxes numeric(12,2) DEFAULT 0 NOT NULL,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    status public.bill_status DEFAULT 'draft'::public.bill_status NOT NULL,
    is_paid boolean DEFAULT false NOT NULL
);


ALTER TABLE public.bill OWNER TO zkhattab;

--
-- Name: bill_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.bill_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bill_id_seq OWNER TO zkhattab;

--
-- Name: bill_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.bill_id_seq OWNED BY public.bill.id;


--
-- Name: cdr; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.cdr (
    id integer NOT NULL,
    file_id integer NOT NULL,
    dial_a character varying(20) NOT NULL,
    dial_b character varying(20) NOT NULL,
    start_time timestamp without time zone NOT NULL,
    duration integer DEFAULT 0 NOT NULL,
    service_id integer,
    hplmn character varying(20),
    vplmn character varying(20),
    external_charges numeric(12,2) DEFAULT 0 NOT NULL,
    rated_flag boolean DEFAULT false NOT NULL,
    rated_service_id integer
);


ALTER TABLE public.cdr OWNER TO zkhattab;

--
-- Name: cdr_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.cdr_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cdr_id_seq OWNER TO zkhattab;

--
-- Name: cdr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.cdr_id_seq OWNED BY public.cdr.id;


--
-- Name: contract; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.contract (
    id integer NOT NULL,
    user_account_id integer NOT NULL,
    rateplan_id integer NOT NULL,
    msisdn character varying(20) NOT NULL,
    status public.contract_status DEFAULT 'active'::public.contract_status NOT NULL,
    credit_limit numeric(12,2) DEFAULT 0 NOT NULL,
    available_credit numeric(12,2) DEFAULT 0 NOT NULL
);


ALTER TABLE public.contract OWNER TO zkhattab;

--
-- Name: contract_addon; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.contract_addon (
    id integer NOT NULL,
    contract_id integer NOT NULL,
    service_package_id integer NOT NULL,
    purchased_date date DEFAULT CURRENT_DATE NOT NULL,
    expiry_date date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    price_paid numeric(12,2) DEFAULT 0 NOT NULL
);


ALTER TABLE public.contract_addon OWNER TO zkhattab;

--
-- Name: contract_addon_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.contract_addon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contract_addon_id_seq OWNER TO zkhattab;

--
-- Name: contract_addon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.contract_addon_id_seq OWNED BY public.contract_addon.id;


--
-- Name: contract_consumption; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.contract_consumption (
    contract_id integer NOT NULL,
    service_package_id integer NOT NULL,
    rateplan_id integer NOT NULL,
    starting_date date NOT NULL,
    ending_date date NOT NULL,
    consumed numeric(12,4) DEFAULT 0 NOT NULL,
    quota_limit numeric(12,4) DEFAULT 0 NOT NULL,
    is_billed boolean DEFAULT false NOT NULL,
    bill_id integer
);


ALTER TABLE public.contract_consumption OWNER TO zkhattab;

--
-- Name: contract_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contract_id_seq OWNER TO zkhattab;

--
-- Name: contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.contract_id_seq OWNED BY public.contract.id;


--
-- Name: file; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.file (
    id integer NOT NULL,
    parsed_flag boolean DEFAULT false NOT NULL,
    file_path text NOT NULL
);


ALTER TABLE public.file OWNER TO zkhattab;

--
-- Name: file_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.file_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.file_id_seq OWNER TO zkhattab;

--
-- Name: file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.file_id_seq OWNED BY public.file.id;


--
-- Name: invoice; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.invoice (
    id integer NOT NULL,
    bill_id integer NOT NULL,
    pdf_path text,
    generation_date timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.invoice OWNER TO zkhattab;

--
-- Name: invoice_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.invoice_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_id_seq OWNER TO zkhattab;

--
-- Name: invoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.invoice_id_seq OWNED BY public.invoice.id;


--
-- Name: msisdn_pool; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.msisdn_pool (
    id integer NOT NULL,
    msisdn character varying(20) NOT NULL,
    is_available boolean DEFAULT true NOT NULL
);


ALTER TABLE public.msisdn_pool OWNER TO zkhattab;

--
-- Name: msisdn_pool_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.msisdn_pool_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.msisdn_pool_id_seq OWNER TO zkhattab;

--
-- Name: msisdn_pool_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.msisdn_pool_id_seq OWNED BY public.msisdn_pool.id;


--
-- Name: rateplan; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.rateplan (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    ror_data numeric(10,2),
    ror_voice numeric(10,2),
    ror_sms numeric(10,2),
    ror_roaming_data numeric(10,2),
    ror_roaming_voice numeric(10,2),
    ror_roaming_sms numeric(10,2),
    price numeric(10,2)
);


ALTER TABLE public.rateplan OWNER TO zkhattab;

--
-- Name: rateplan_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.rateplan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rateplan_id_seq OWNER TO zkhattab;

--
-- Name: rateplan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.rateplan_id_seq OWNED BY public.rateplan.id;


--
-- Name: rateplan_service_package; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.rateplan_service_package (
    rateplan_id integer NOT NULL,
    service_package_id integer NOT NULL
);


ALTER TABLE public.rateplan_service_package OWNER TO zkhattab;

--
-- Name: ror_contract; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.ror_contract (
    contract_id integer NOT NULL,
    rateplan_id integer NOT NULL,
    starting_date date DEFAULT (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone))::date NOT NULL,
    data bigint DEFAULT 0,
    voice numeric(12,2) DEFAULT 0,
    sms bigint DEFAULT 0,
    roaming_voice numeric(12,2) DEFAULT 0.00,
    roaming_data bigint DEFAULT 0,
    roaming_sms bigint DEFAULT 0,
    bill_id integer
);


ALTER TABLE public.ror_contract OWNER TO zkhattab;

--
-- Name: service_package; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.service_package (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    type public.service_type NOT NULL,
    amount numeric(12,4) NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    price numeric(12,2),
    is_roaming boolean DEFAULT false NOT NULL,
    description text
);


ALTER TABLE public.service_package OWNER TO zkhattab;

--
-- Name: service_package_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.service_package_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_package_id_seq OWNER TO zkhattab;

--
-- Name: service_package_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.service_package_id_seq OWNED BY public.service_package.id;


--
-- Name: user_account; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.user_account (
    id integer NOT NULL,
    username character varying(255) NOT NULL,
    password character varying(30) NOT NULL,
    role public.user_role NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    address text,
    birthdate date
);


ALTER TABLE public.user_account OWNER TO zkhattab;

--
-- Name: user_account_id_seq; Type: SEQUENCE; Schema: public; Owner: zkhattab
--

CREATE SEQUENCE public.user_account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_account_id_seq OWNER TO zkhattab;

--
-- Name: user_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zkhattab
--

ALTER SEQUENCE public.user_account_id_seq OWNED BY public.user_account.id;


--
-- Name: v_msisdn; Type: TABLE; Schema: public; Owner: zkhattab
--

CREATE TABLE public.v_msisdn (
    msisdn character varying(20)
);


ALTER TABLE public.v_msisdn OWNER TO zkhattab;

--
-- Name: bill id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.bill ALTER COLUMN id SET DEFAULT nextval('public.bill_id_seq'::regclass);


--
-- Name: cdr id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.cdr ALTER COLUMN id SET DEFAULT nextval('public.cdr_id_seq'::regclass);


--
-- Name: contract id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract ALTER COLUMN id SET DEFAULT nextval('public.contract_id_seq'::regclass);


--
-- Name: contract_addon id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_addon ALTER COLUMN id SET DEFAULT nextval('public.contract_addon_id_seq'::regclass);


--
-- Name: file id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.file ALTER COLUMN id SET DEFAULT nextval('public.file_id_seq'::regclass);


--
-- Name: invoice id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.invoice ALTER COLUMN id SET DEFAULT nextval('public.invoice_id_seq'::regclass);


--
-- Name: msisdn_pool id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.msisdn_pool ALTER COLUMN id SET DEFAULT nextval('public.msisdn_pool_id_seq'::regclass);


--
-- Name: rateplan id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.rateplan ALTER COLUMN id SET DEFAULT nextval('public.rateplan_id_seq'::regclass);


--
-- Name: service_package id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.service_package ALTER COLUMN id SET DEFAULT nextval('public.service_package_id_seq'::regclass);


--
-- Name: user_account id; Type: DEFAULT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.user_account ALTER COLUMN id SET DEFAULT nextval('public.user_account_id_seq'::regclass);


--
-- Data for Name: bill; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.bill (id, contract_id, billing_period_start, billing_period_end, billing_date, recurring_fees, one_time_fees, voice_usage, data_usage, sms_usage, ror_charge, overage_charge, roaming_charge, promotional_discount, taxes, total_amount, status, is_paid) FROM stdin;
1	1	2026-02-01	2026-02-28	2026-03-01	75.00	0.69	280	0	38	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
2	2	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	580	1900	72	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
3	3	2026-02-01	2026-02-28	2026-03-01	75.00	0.69	150	0	18	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
4	4	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	410	1400	50	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
5	5	2026-02-01	2026-02-28	2026-03-01	75.00	0.69	80	0	10	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
6	6	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	690	2800	95	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
7	7	2026-02-01	2026-02-28	2026-03-01	75.00	0.69	190	0	25	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
8	8	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	350	1200	45	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
9	9	2026-02-01	2026-02-28	2026-03-01	75.00	0.69	120	0	15	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
10	10	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	470	1750	62	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
11	11	2026-02-01	2026-02-28	2026-03-01	75.00	0.69	820	0	175	10.00	0.00	0.00	0.00	6.07	66.76	paid	t
12	12	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	260	800	30	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
13	14	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	390	1050	52	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
14	15	2026-02-01	2026-02-28	2026-03-01	950.00	0.69	750	3500	130	0.00	0.00	0.00	0.00	133.00	1083.69	paid	t
15	16	2026-02-01	2026-02-28	2026-03-01	950.00	0.69	880	4200	160	5.00	0.00	0.00	0.00	35.47	390.16	paid	t
16	17	2026-02-01	2026-02-28	2026-03-01	370.00	0.69	310	950	42	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
17	1	2026-03-01	2026-03-31	2026-04-01	75.00	0.69	310	0	42	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
18	2	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	640	2200	80	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
32	17	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	330	980	45	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
31	16	2026-03-01	2026-03-31	2026-04-01	950.00	0.69	920	4800	170	8.00	0.00	0.00	0.00	35.77	393.46	paid	t
30	15	2026-03-01	2026-03-31	2026-04-01	950.00	0.69	800	3700	140	0.00	0.00	0.00	0.00	133.00	1083.69	paid	t
29	14	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	420	1100	55	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
28	12	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	280	850	35	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
27	11	2026-03-01	2026-03-31	2026-04-01	75.00	0.69	900	0	195	14.50	0.00	0.00	0.00	6.52	71.71	paid	t
26	10	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	500	1900	68	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
25	9	2026-03-01	2026-03-31	2026-04-01	75.00	0.69	130	0	16	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
24	8	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	380	1350	50	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
23	7	2026-03-01	2026-03-31	2026-04-01	75.00	0.69	200	0	28	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
22	6	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	720	3100	105	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
21	5	2026-03-01	2026-03-31	2026-04-01	75.00	0.69	90	0	11	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
20	4	2026-03-01	2026-03-31	2026-04-01	370.00	0.69	450	1600	58	0.00	0.00	0.00	0.00	51.80	422.49	paid	t
19	3	2026-03-01	2026-03-31	2026-04-01	75.00	0.69	170	0	20	0.00	0.00	0.00	0.00	10.50	86.19	paid	t
33	10	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	510	2400	75	0.00	2.34	0.00	0.00	52.13	424.47	issued	f
34	9	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	140	0	8	0.00	1.30	0.00	0.00	10.68	86.98	issued	f
35	8	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	390	1500	55	0.00	1.94	0.00	0.00	52.07	424.01	issued	f
36	7	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	210	0	18	0.00	2.10	0.00	0.00	10.79	87.89	issued	f
37	6	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	750	3200	110	0.00	4.06	0.00	0.00	52.37	426.43	issued	f
38	5	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	95	0	12	0.00	1.50	0.00	0.00	10.71	87.21	issued	f
39	4	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	480	1800	65	0.00	2.24	0.00	0.00	52.11	424.35	issued	f
40	3	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	180	0	22	0.00	2.30	0.00	0.00	10.82	88.12	issued	f
42	2	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	740	2500	115	0.00	3.18	0.52	0.00	52.32	426.02	issued	f
43	19	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
44	20	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
45	21	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	issued	f
46	22	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	issued	f
47	23	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	issued	f
48	24	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
49	25	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
50	26	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
51	27	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
52	28	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
53	29	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	issued	f
62	38	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	paid	t
61	37	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	0	0	0	0.00	0.00	0.00	0.00	10.50	85.50	paid	t
60	36	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	0	0	0	0.00	0.00	0.00	0.00	10.50	85.50	paid	t
59	35	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	paid	t
58	34	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	0	0	0	0.00	0.00	0.00	0.00	10.50	85.50	paid	t
57	33	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	0	0	0	0.00	0.00	0.00	0.00	10.50	85.50	paid	t
56	32	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	paid	t
55	31	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	paid	t
54	30	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	paid	t
41	1	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	350	0	45	0.00	8.90	0.00	0.00	11.75	95.65	paid	t
78	11	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	980	0	190	0.00	7.00	0.00	0.00	11.48	93.48	paid	t
77	12	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	290	900	35	0.00	1.12	0.00	0.00	51.96	423.08	paid	t
76	14	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	430	1200	60	0.00	1.54	0.00	0.00	52.02	423.56	paid	t
75	15	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	900	4120	165	0.00	1.52	0.21	0.00	133.24	1084.97	paid	t
74	16	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	950	4900	180	0.00	1.87	0.00	0.00	133.26	1085.13	paid	t
73	17	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	340	1100	48	0.00	1.24	0.00	0.00	51.97	423.21	paid	t
72	48	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	0	0	0	0.00	0.00	0.00	0.00	10.50	85.50	paid	t
71	47	2026-04-01	2026-04-30	2026-04-29	75.00	0.00	0	0	0	0.00	0.00	0.00	0.00	10.50	85.50	paid	t
70	46	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	paid	t
69	45	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	paid	t
68	44	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	paid	t
67	43	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	paid	t
66	42	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	paid	t
65	41	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	paid	t
64	40	2026-04-01	2026-04-30	2026-04-29	370.00	0.00	0	0	0	0.00	0.00	0.00	0.00	51.80	421.80	paid	t
63	39	2026-04-01	2026-04-30	2026-04-29	950.00	0.00	0	0	0	0.00	0.00	0.00	0.00	133.00	1083.00	paid	t
\.


--
-- Data for Name: cdr; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.cdr (id, file_id, dial_a, dial_b, start_time, duration, service_id, hplmn, vplmn, external_charges, rated_flag, rated_service_id) FROM stdin;
1	1	201000000001	201000000002	2026-04-01 09:15:00	180	1	EGYVO	\N	0.60	t	\N
2	1	201000000001	201000000003	2026-04-01 14:30:00	1	3	EGYVO	\N	0.05	t	\N
3	1	201000000001	201000000005	2026-04-02 08:00:00	300	1	EGYVO	\N	1.00	t	\N
4	1	201000000001	201000000007	2026-04-03 11:20:00	1	3	EGYVO	\N	0.05	t	\N
5	1	201000000001	201000000009	2026-04-04 10:05:00	240	1	EGYVO	\N	0.80	t	\N
6	1	201000000001	201000000002	2026-04-05 16:45:00	1	3	EGYVO	\N	0.05	t	\N
7	1	201000000001	201000000011	2026-04-07 09:30:00	420	1	EGYVO	\N	1.40	t	\N
8	1	201000000001	201000000013	2026-04-08 13:00:00	1	3	EGYVO	\N	0.05	t	\N
9	1	201000000001	201000000015	2026-04-09 17:20:00	150	1	EGYVO	\N	0.60	t	\N
10	1	201000000001	201000000002	2026-04-10 08:45:00	360	1	EGYVO	\N	1.20	t	\N
11	1	201000000001	201000000003	2026-04-12 12:10:00	1	3	EGYVO	\N	0.05	t	\N
12	1	201000000001	201000000017	2026-04-14 15:30:00	210	1	EGYVO	\N	0.80	t	\N
13	1	201000000001	201000000004	2026-04-16 09:00:00	270	1	EGYVO	\N	1.00	t	\N
14	1	201000000001	201000000006	2026-04-18 14:00:00	1	3	EGYVO	\N	0.05	t	\N
15	1	201000000001	201000000008	2026-04-20 10:30:00	330	1	EGYVO	\N	1.20	t	\N
16	1	201000000002	201000000001	2026-04-01 08:30:00	300	1	EGYVO	\N	0.50	t	\N
17	1	201000000002	201000000004	2026-04-01 10:00:00	500	2	EGYVO	\N	0.00	t	\N
18	1	201000000002	201000000006	2026-04-01 12:00:00	1	3	EGYVO	\N	0.02	t	\N
19	1	201000000002	201000000008	2026-04-02 09:15:00	450	1	EGYVO	\N	0.80	t	\N
20	1	201000000002	201000000010	2026-04-02 14:30:00	750	2	EGYVO	\N	0.00	t	\N
21	1	201000000002	201000000012	2026-04-03 08:00:00	1	3	EGYVO	\N	0.02	t	\N
22	1	201000000002	201000000001	2026-04-04 11:45:00	600	1	EGYVO	\N	1.00	t	\N
23	1	201000000002	201000000014	2026-04-05 15:00:00	1000	2	EGYVO	\N	0.00	t	\N
24	1	201000000002	201000000016	2026-04-06 09:30:00	1	3	EGYVO	\N	0.02	t	\N
25	1	201000000002	201000000018	2026-04-07 13:20:00	480	1	EGYVO	\N	0.80	t	\N
26	1	201000000002	201000000001	2026-04-08 17:00:00	800	2	EGYVO	\N	0.00	t	\N
27	1	201000000002	201000000003	2026-04-09 10:15:00	1	3	EGYVO	\N	0.02	t	\N
28	2	201000000002	201000000001	2026-04-15 10:00:00	180	5	EGYVO	DEUTS	0.00	t	\N
29	2	201000000002	201000000004	2026-04-15 14:30:00	200	6	EGYVO	DEUTS	0.00	t	\N
30	2	201000000002	201000000006	2026-04-16 09:00:00	1	7	EGYVO	DEUTS	0.00	t	\N
31	2	201000000002	201000000008	2026-04-16 15:45:00	120	5	EGYVO	DEUTS	0.00	t	\N
32	2	201000000002	201000000001	2026-04-17 11:00:00	300	6	EGYVO	DEUTS	0.00	t	\N
33	1	201000000003	201000000001	2026-04-01 09:00:00	120	1	EGYVO	\N	0.40	t	\N
34	1	201000000003	201000000005	2026-04-02 11:30:00	1	3	EGYVO	\N	0.05	t	\N
35	1	201000000003	201000000007	2026-04-04 14:00:00	240	1	EGYVO	\N	0.80	t	\N
36	1	201000000003	201000000009	2026-04-06 16:30:00	1	3	EGYVO	\N	0.05	t	\N
37	1	201000000003	201000000001	2026-04-08 10:15:00	180	1	EGYVO	\N	0.60	t	\N
38	1	201000000003	201000000011	2026-04-10 13:45:00	90	1	EGYVO	\N	0.40	t	\N
39	1	201000000004	201000000002	2026-04-01 08:00:00	360	1	EGYVO	\N	0.60	t	\N
40	1	201000000004	201000000006	2026-04-01 13:00:00	600	2	EGYVO	\N	0.00	t	\N
41	1	201000000004	201000000008	2026-04-02 10:30:00	1	3	EGYVO	\N	0.02	t	\N
42	1	201000000004	201000000010	2026-04-03 15:00:00	420	1	EGYVO	\N	0.70	t	\N
43	1	201000000004	201000000012	2026-04-05 09:45:00	800	2	EGYVO	\N	0.00	t	\N
44	1	201000000004	201000000002	2026-04-07 14:00:00	1	3	EGYVO	\N	0.02	t	\N
45	1	201000000004	201000000014	2026-04-09 11:30:00	540	1	EGYVO	\N	0.90	t	\N
46	1	201000000004	201000000016	2026-04-11 16:00:00	700	2	EGYVO	\N	0.00	t	\N
47	1	201000000005	201000000001	2026-04-01 10:00:00	90	1	EGYVO	\N	0.40	t	\N
48	1	201000000005	201000000003	2026-04-03 12:30:00	1	3	EGYVO	\N	0.05	t	\N
49	1	201000000005	201000000007	2026-04-05 15:45:00	150	1	EGYVO	\N	0.60	t	\N
50	1	201000000005	201000000009	2026-04-08 09:00:00	1	3	EGYVO	\N	0.05	t	\N
51	1	201000000005	201000000001	2026-04-11 11:15:00	120	1	EGYVO	\N	0.40	t	\N
52	2	201000000006	201000000002	2026-04-01 09:30:00	540	1	EGYVO	\N	0.90	t	\N
53	2	201000000006	201000000008	2026-04-01 13:00:00	900	2	EGYVO	\N	0.00	t	\N
54	2	201000000006	201000000010	2026-04-02 08:15:00	1	3	EGYVO	\N	0.02	t	\N
55	2	201000000006	201000000012	2026-04-02 14:00:00	480	1	EGYVO	\N	0.80	t	\N
56	2	201000000006	201000000014	2026-04-03 10:30:00	1100	2	EGYVO	\N	0.00	t	\N
57	2	201000000006	201000000002	2026-04-04 15:45:00	1	3	EGYVO	\N	0.02	t	\N
58	2	201000000006	201000000016	2026-04-05 09:00:00	660	1	EGYVO	\N	1.10	t	\N
59	2	201000000006	201000000018	2026-04-06 12:30:00	850	2	EGYVO	\N	0.00	t	\N
60	2	201000000006	201000000002	2026-04-07 16:00:00	1	3	EGYVO	\N	0.02	t	\N
61	2	201000000006	201000000004	2026-04-08 10:15:00	720	1	EGYVO	\N	1.20	t	\N
62	2	201000000007	201000000001	2026-04-01 08:45:00	60	1	EGYVO	\N	0.20	t	\N
63	2	201000000007	201000000009	2026-04-03 13:30:00	1	3	EGYVO	\N	0.05	t	\N
64	2	201000000007	201000000011	2026-04-05 16:00:00	120	1	EGYVO	\N	0.40	t	\N
65	2	201000000007	201000000001	2026-04-08 10:00:00	180	1	EGYVO	\N	0.60	t	\N
66	2	201000000007	201000000003	2026-04-11 14:15:00	1	3	EGYVO	\N	0.05	t	\N
67	2	201000000007	201000000005	2026-04-14 09:30:00	240	1	EGYVO	\N	0.80	t	\N
68	2	201000000008	201000000002	2026-04-01 10:15:00	300	1	EGYVO	\N	0.50	t	\N
69	2	201000000008	201000000004	2026-04-02 12:00:00	650	2	EGYVO	\N	0.00	t	\N
70	2	201000000008	201000000006	2026-04-03 15:30:00	1	3	EGYVO	\N	0.02	t	\N
71	2	201000000008	201000000010	2026-04-04 09:00:00	420	1	EGYVO	\N	0.70	t	\N
72	2	201000000008	201000000012	2026-04-05 13:45:00	750	2	EGYVO	\N	0.00	t	\N
73	2	201000000008	201000000002	2026-04-07 11:00:00	1	3	EGYVO	\N	0.02	t	\N
74	2	201000000008	201000000014	2026-04-09 16:30:00	390	1	EGYVO	\N	0.70	t	\N
75	2	201000000009	201000000001	2026-04-01 11:00:00	180	1	EGYVO	\N	0.60	t	\N
76	2	201000000009	201000000003	2026-04-03 14:00:00	1	3	EGYVO	\N	0.05	t	\N
77	2	201000000009	201000000005	2026-04-06 09:30:00	150	1	EGYVO	\N	0.60	t	\N
78	2	201000000009	201000000007	2026-04-09 12:45:00	1	3	EGYVO	\N	0.05	t	\N
79	2	201000000010	201000000002	2026-04-01 09:45:00	360	1	EGYVO	\N	0.60	t	\N
80	2	201000000010	201000000004	2026-04-02 13:15:00	700	2	EGYVO	\N	0.00	t	\N
81	2	201000000010	201000000006	2026-04-03 16:00:00	1	3	EGYVO	\N	0.02	t	\N
82	2	201000000010	201000000008	2026-04-04 10:30:00	480	1	EGYVO	\N	0.80	t	\N
83	2	201000000010	201000000012	2026-04-05 14:00:00	900	2	EGYVO	\N	0.00	t	\N
84	2	201000000010	201000000002	2026-04-07 09:15:00	1	3	EGYVO	\N	0.02	t	\N
85	2	201000000010	201000000014	2026-04-09 15:45:00	540	1	EGYVO	\N	0.90	t	\N
86	2	201000000010	201000000016	2026-04-11 11:00:00	800	2	EGYVO	\N	0.00	t	\N
87	1	201000000011	201000000001	2026-04-01 08:00:00	600	1	EGYVO	\N	2.00	t	\N
88	1	201000000011	201000000003	2026-04-02 10:30:00	1	3	EGYVO	\N	0.05	t	\N
89	1	201000000011	201000000005	2026-04-03 14:15:00	480	1	EGYVO	\N	1.60	t	\N
90	1	201000000011	201000000007	2026-04-04 16:45:00	1	3	EGYVO	\N	0.05	t	\N
91	1	201000000011	201000000009	2026-04-05 09:30:00	540	1	EGYVO	\N	1.80	t	\N
92	1	201000000011	201000000001	2026-04-07 13:00:00	1	3	EGYVO	\N	0.05	t	\N
93	1	201000000011	201000000003	2026-04-09 10:15:00	420	1	EGYVO	\N	1.40	t	\N
94	1	201000000011	201000000005	2026-04-11 15:30:00	1	3	EGYVO	\N	0.05	t	\N
95	1	201000000012	201000000002	2026-04-01 11:30:00	270	1	EGYVO	\N	0.50	t	\N
96	1	201000000012	201000000004	2026-04-03 09:00:00	550	2	EGYVO	\N	0.00	t	\N
97	1	201000000012	201000000006	2026-04-05 13:45:00	1	3	EGYVO	\N	0.02	t	\N
98	1	201000000012	201000000008	2026-04-07 16:00:00	330	1	EGYVO	\N	0.60	t	\N
99	1	201000000014	201000000002	2026-04-01 09:00:00	390	1	EGYVO	\N	0.70	t	\N
100	1	201000000014	201000000004	2026-04-02 11:30:00	650	2	EGYVO	\N	0.00	t	\N
101	1	201000000014	201000000006	2026-04-03 14:00:00	1	3	EGYVO	\N	0.02	t	\N
102	1	201000000014	201000000008	2026-04-05 16:30:00	450	1	EGYVO	\N	0.80	t	\N
103	1	201000000014	201000000010	2026-04-07 10:15:00	700	2	EGYVO	\N	0.00	t	\N
104	1	201000000014	201000000002	2026-04-09 13:45:00	1	3	EGYVO	\N	0.02	t	\N
105	2	201000000015	201000000002	2026-04-01 08:00:00	480	1	EGYVO	\N	0.40	t	\N
106	2	201000000015	201000000004	2026-04-01 10:30:00	1200	2	EGYVO	\N	0.00	t	\N
107	2	201000000015	201000000006	2026-04-01 13:00:00	1	3	EGYVO	\N	0.01	t	\N
108	2	201000000015	201000000008	2026-04-02 09:00:00	600	1	EGYVO	\N	0.50	t	\N
109	2	201000000015	201000000010	2026-04-02 14:00:00	1500	2	EGYVO	\N	0.00	t	\N
110	2	201000000015	201000000012	2026-04-03 10:15:00	1	3	EGYVO	\N	0.01	t	\N
111	2	201000000015	201000000002	2026-04-04 15:30:00	720	1	EGYVO	\N	0.60	t	\N
112	2	201000000015	201000000016	2026-04-05 09:45:00	1800	2	EGYVO	\N	0.00	t	\N
113	2	201000000015	201000000002	2026-04-20 10:00:00	240	5	EGYVO	FRANC	0.00	t	\N
114	2	201000000015	201000000004	2026-04-20 14:30:00	400	6	EGYVO	FRANC	0.00	t	\N
115	2	201000000015	201000000006	2026-04-21 09:00:00	1	7	EGYVO	FRANC	0.00	t	\N
116	2	201000000016	201000000002	2026-04-01 09:30:00	600	1	EGYVO	\N	0.50	t	\N
117	2	201000000016	201000000004	2026-04-01 12:00:00	1400	2	EGYVO	\N	0.00	t	\N
118	2	201000000016	201000000006	2026-04-01 15:30:00	1	3	EGYVO	\N	0.01	t	\N
119	2	201000000016	201000000008	2026-04-02 08:30:00	780	1	EGYVO	\N	0.65	t	\N
120	2	201000000016	201000000010	2026-04-02 13:00:00	1600	2	EGYVO	\N	0.00	t	\N
121	2	201000000016	201000000012	2026-04-03 10:00:00	1	3	EGYVO	\N	0.01	t	\N
122	2	201000000016	201000000014	2026-04-03 16:00:00	840	1	EGYVO	\N	0.70	t	\N
123	2	201000000016	201000000002	2026-04-04 11:30:00	1800	2	EGYVO	\N	0.00	t	\N
124	2	201000000017	201000000002	2026-04-01 10:00:00	300	1	EGYVO	\N	0.50	t	\N
125	2	201000000017	201000000004	2026-04-02 12:30:00	600	2	EGYVO	\N	0.00	t	\N
126	2	201000000017	201000000006	2026-04-03 15:00:00	1	3	EGYVO	\N	0.02	t	\N
127	2	201000000017	201000000008	2026-04-05 09:30:00	420	1	EGYVO	\N	0.70	t	\N
128	2	201000000017	201000000010	2026-04-07 14:00:00	750	2	EGYVO	\N	0.00	t	\N
129	2	201000000017	201000000002	2026-04-09 11:15:00	1	3	EGYVO	\N	0.02	t	\N
\.


--
-- Data for Name: contract; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.contract (id, user_account_id, rateplan_id, msisdn, status, credit_limit, available_credit) FROM stdin;
13	14	1	201000000013	suspended	200.00	200.00
18	19	1	201000000018	terminated	200.00	200.00
10	11	2	201000000010	active	500.00	500.00
9	10	1	201000000009	active	200.00	200.00
8	9	2	201000000008	active	500.00	500.00
7	8	1	201000000007	active	200.00	200.00
6	7	2	201000000006	active	500.00	500.00
5	6	1	201000000005	active	200.00	200.00
4	5	2	201000000004	active	500.00	500.00
3	4	1	201000000003	active	200.00	200.00
1	2	1	201000000001	active	200.00	200.00
2	3	2	201000000002	active	500.00	496.82
33	34	1	201000000033	active	300.00	300.00
32	33	3	201000000032	active	300.00	300.00
31	32	2	201000000031	active	300.00	300.00
30	31	2	201000000030	active	300.00	300.00
19	20	3	201000000019	active	300.00	300.00
20	21	3	201000000020	active	300.00	300.00
21	22	2	201000000021	active	300.00	300.00
22	23	2	201000000022	active	300.00	300.00
23	24	2	201000000023	active	300.00	300.00
24	25	3	201000000024	active	300.00	300.00
25	26	3	201000000025	active	300.00	300.00
26	27	3	201000000026	active	300.00	300.00
27	28	3	201000000027	active	300.00	300.00
28	29	3	201000000028	active	300.00	300.00
29	30	3	201000000029	active	300.00	300.00
11	12	1	201000000011	active	200.00	200.00
12	13	2	201000000012	active	500.00	500.00
14	15	2	201000000014	active	500.00	500.00
15	16	3	201000000015	active	1000.00	1000.00
16	17	3	201000000016	active	1000.00	1000.00
17	18	2	201000000017	active	500.00	500.00
48	49	1	201000000048	active	300.00	300.00
47	48	1	201000000047	active	300.00	300.00
46	47	2	201000000046	active	300.00	300.00
45	46	3	201000000045	active	300.00	300.00
44	45	2	201000000044	active	300.00	300.00
43	44	3	201000000043	active	300.00	300.00
42	43	3	201000000042	active	300.00	300.00
41	42	3	201000000041	active	300.00	300.00
40	41	2	201000000040	active	300.00	300.00
39	40	3	201000000039	active	300.00	300.00
38	39	2	201000000038	active	300.00	300.00
37	38	1	201000000037	active	300.00	300.00
36	37	1	201000000036	active	300.00	300.00
35	36	3	201000000035	active	300.00	300.00
34	35	1	201000000034	active	300.00	300.00
\.


--
-- Data for Name: contract_addon; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.contract_addon (id, contract_id, service_package_id, purchased_date, expiry_date, is_active, price_paid) FROM stdin;
\.


--
-- Data for Name: contract_consumption; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.contract_consumption (contract_id, service_package_id, rateplan_id, starting_date, ending_date, consumed, quota_limit, is_billed, bill_id) FROM stdin;
10	5	2	2026-04-01	2026-04-30	0.0000	100.0000	t	33
10	6	2	2026-04-01	2026-04-30	0.0000	2000.0000	t	33
10	7	2	2026-04-01	2026-04-30	0.0000	100.0000	t	33
10	1	2	2026-04-01	2026-04-30	510.0000	2000.0000	t	33
9	1	1	2026-04-01	2026-04-30	140.0000	2000.0000	t	34
8	5	2	2026-04-01	2026-04-30	0.0000	100.0000	t	35
8	6	2	2026-04-01	2026-04-30	0.0000	2000.0000	t	35
8	7	2	2026-04-01	2026-04-30	0.0000	100.0000	t	35
8	1	2	2026-04-01	2026-04-30	390.0000	2000.0000	t	35
7	1	1	2026-04-01	2026-04-30	210.0000	2000.0000	t	36
6	5	2	2026-04-01	2026-04-30	0.0000	100.0000	t	37
6	6	2	2026-04-01	2026-04-30	0.0000	2000.0000	t	37
6	7	2	2026-04-01	2026-04-30	0.0000	100.0000	t	37
6	1	2	2026-04-01	2026-04-30	750.0000	2000.0000	t	37
5	1	1	2026-04-01	2026-04-30	95.0000	2000.0000	t	38
4	5	2	2026-04-01	2026-04-30	0.0000	100.0000	t	39
4	6	2	2026-04-01	2026-04-30	0.0000	2000.0000	t	39
4	7	2	2026-04-01	2026-04-30	0.0000	100.0000	t	39
4	1	2	2026-04-01	2026-04-30	480.0000	2000.0000	t	39
3	1	1	2026-04-01	2026-04-30	180.0000	2000.0000	t	40
17	5	2	2026-04-01	2026-04-30	0.0000	100.0000	t	73
17	6	2	2026-04-01	2026-04-30	0.0000	2000.0000	t	73
17	7	2	2026-04-01	2026-04-30	0.0000	100.0000	t	73
17	1	2	2026-04-01	2026-04-30	340.0000	2000.0000	t	73
16	5	3	2026-04-01	2026-04-30	0.0000	100.0000	t	74
16	6	3	2026-04-01	2026-04-30	0.0000	2000.0000	t	74
16	7	3	2026-04-01	2026-04-30	0.0000	100.0000	t	74
16	1	3	2026-04-01	2026-04-30	950.0000	2000.0000	t	74
15	1	3	2026-04-01	2026-04-30	820.0000	2000.0000	t	75
14	5	2	2026-04-01	2026-04-30	0.0000	100.0000	t	76
14	6	2	2026-04-01	2026-04-30	0.0000	2000.0000	t	76
14	7	2	2026-04-01	2026-04-30	0.0000	100.0000	t	76
14	1	2	2026-04-01	2026-04-30	430.0000	2000.0000	t	76
12	5	2	2026-04-01	2026-04-30	0.0000	100.0000	t	77
12	6	2	2026-04-01	2026-04-30	0.0000	2000.0000	t	77
12	7	2	2026-04-01	2026-04-30	0.0000	100.0000	t	77
12	1	2	2026-04-01	2026-04-30	290.0000	2000.0000	t	77
11	1	1	2026-04-01	2026-04-30	980.0000	2000.0000	t	78
1	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
1	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
2	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
2	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
2	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
2	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
2	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
2	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
2	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
3	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
3	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
4	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
4	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
4	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
4	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
4	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
4	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
4	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
5	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
5	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
6	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
6	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
6	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
6	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
6	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
6	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
6	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
7	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
7	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
8	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
8	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
8	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
8	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
8	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
8	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
8	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
9	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
9	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
10	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
10	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
10	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
10	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
10	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
10	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
10	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
11	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
11	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
12	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
12	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
12	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
12	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
12	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
12	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
12	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
14	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
14	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
14	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
14	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
14	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
14	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
14	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
15	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
15	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
15	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
15	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
15	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
15	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
15	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
16	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
16	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
16	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
16	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
16	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
16	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
16	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
17	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
17	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
17	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
17	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
17	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
17	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
17	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
19	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
19	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
19	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
19	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
19	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
19	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
19	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
20	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
20	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
20	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
20	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
20	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
20	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
20	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
21	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
21	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
21	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
21	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
21	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
21	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
21	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
22	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
22	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
22	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
22	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
22	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
22	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
22	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
23	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
23	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
23	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
23	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
23	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
23	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
23	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
24	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
24	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
24	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
24	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
24	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
24	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
24	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
25	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
25	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
25	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
25	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
25	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
25	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
25	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
26	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
26	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
26	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
26	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
26	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
26	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
26	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
27	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
27	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
27	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
27	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
27	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
27	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
27	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
28	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
28	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
28	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
28	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
28	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
28	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
28	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
29	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
29	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
29	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
29	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
29	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
29	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
29	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
30	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
30	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
30	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
30	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
30	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
30	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
30	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
31	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
31	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
31	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
31	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
31	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
31	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
31	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
32	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
32	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
32	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
32	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
32	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
32	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
32	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
33	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
33	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
34	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
34	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
35	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
35	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
35	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
35	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
35	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
35	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
35	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
36	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
36	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
37	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
37	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
38	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
38	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
38	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
38	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
38	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
38	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
38	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
39	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
39	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
39	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
39	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
39	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
39	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
39	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
40	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
40	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
40	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
40	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
40	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
40	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
40	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
41	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
41	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
41	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
41	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
41	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
41	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
41	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
42	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
42	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
42	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
42	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
42	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
42	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
42	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
43	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
43	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
43	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
43	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
43	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
43	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
43	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
44	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
44	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
44	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
44	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
44	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
44	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
44	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
45	1	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
45	2	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
45	3	3	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
45	4	3	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
45	5	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
45	6	3	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
45	7	3	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
46	1	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
46	2	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
46	3	2	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
46	4	2	2026-04-29	2026-04-30	0.0000	10000.0000	f	\N
46	5	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
46	6	2	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
46	7	2	2026-04-29	2026-04-30	0.0000	100.0000	f	\N
47	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
47	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
48	1	1	2026-04-29	2026-04-30	0.0000	2000.0000	f	\N
48	3	1	2026-04-29	2026-04-30	0.0000	500.0000	f	\N
1	1	1	2026-03-01	2026-03-31	310.0000	1000.0000	t	17
1	3	1	2026-03-01	2026-03-31	42.0000	100.0000	t	17
10	2	2	2026-04-01	2026-04-30	2400.0000	10000.0000	t	33
10	3	2	2026-04-01	2026-04-30	75.0000	500.0000	t	33
10	4	2	2026-04-01	2026-04-30	40.0000	10000.0000	t	33
9	3	1	2026-04-01	2026-04-30	8.0000	500.0000	t	34
8	2	2	2026-04-01	2026-04-30	1500.0000	10000.0000	t	35
8	3	2	2026-04-01	2026-04-30	55.0000	500.0000	t	35
8	4	2	2026-04-01	2026-04-30	20.0000	10000.0000	t	35
7	3	1	2026-04-01	2026-04-30	18.0000	500.0000	t	36
6	2	2	2026-04-01	2026-04-30	3200.0000	10000.0000	t	37
6	3	2	2026-04-01	2026-04-30	110.0000	500.0000	t	37
6	4	2	2026-04-01	2026-04-30	50.0000	10000.0000	t	37
5	3	1	2026-04-01	2026-04-30	12.0000	500.0000	t	38
4	2	2	2026-04-01	2026-04-30	1800.0000	10000.0000	t	39
4	3	2	2026-04-01	2026-04-30	65.0000	500.0000	t	39
4	4	2	2026-04-01	2026-04-30	30.0000	10000.0000	t	39
3	3	1	2026-04-01	2026-04-30	22.0000	500.0000	t	40
1	1	1	2026-04-01	2026-04-30	350.0000	2000.0000	t	41
1	3	1	2026-04-01	2026-04-30	45.0000	500.0000	t	41
2	1	2	2026-04-01	2026-04-30	620.0000	2000.0000	t	42
2	2	2	2026-04-01	2026-04-30	2100.0000	10000.0000	t	42
2	3	2	2026-04-01	2026-04-30	85.0000	500.0000	t	42
2	4	2	2026-04-01	2026-04-30	50.0000	10000.0000	t	42
2	5	2	2026-04-01	2026-04-30	120.0000	100.0000	t	42
2	6	2	2026-04-01	2026-04-30	400.0000	2000.0000	t	42
2	7	2	2026-04-01	2026-04-30	30.0000	100.0000	t	42
17	2	2	2026-04-01	2026-04-30	1100.0000	10000.0000	t	73
17	3	2	2026-04-01	2026-04-30	48.0000	500.0000	t	73
17	4	2	2026-04-01	2026-04-30	10.0000	10000.0000	t	73
16	2	3	2026-04-01	2026-04-30	4900.0000	10000.0000	t	74
16	3	3	2026-04-01	2026-04-30	180.0000	500.0000	t	74
16	4	3	2026-04-01	2026-04-30	50.0000	10000.0000	t	74
15	2	3	2026-04-01	2026-04-30	3800.0000	10000.0000	t	75
15	3	3	2026-04-01	2026-04-30	145.0000	500.0000	t	75
15	4	3	2026-04-01	2026-04-30	50.0000	10000.0000	t	75
15	5	3	2026-04-01	2026-04-30	80.0000	100.0000	t	75
15	6	3	2026-04-01	2026-04-30	320.0000	2000.0000	t	75
15	7	3	2026-04-01	2026-04-30	20.0000	100.0000	t	75
14	2	2	2026-04-01	2026-04-30	1200.0000	10000.0000	t	76
14	3	2	2026-04-01	2026-04-30	60.0000	500.0000	t	76
14	4	2	2026-04-01	2026-04-30	25.0000	10000.0000	t	76
12	2	2	2026-04-01	2026-04-30	900.0000	10000.0000	t	77
12	3	2	2026-04-01	2026-04-30	35.0000	500.0000	t	77
12	4	2	2026-04-01	2026-04-30	15.0000	10000.0000	t	77
11	3	1	2026-04-01	2026-04-30	190.0000	500.0000	t	78
\.


--
-- Data for Name: file; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.file (id, parsed_flag, file_path) FROM stdin;
1	t	/tmp/cdr_april_batch1.csv
2	t	/tmp/cdr_april_batch2.csv
\.


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.invoice (id, bill_id, pdf_path, generation_date) FROM stdin;
1	1	/invoices/feb26_contract1.pdf	2026-04-29 07:41:23.397932
2	2	/invoices/feb26_contract2.pdf	2026-04-29 07:41:23.397932
3	3	/invoices/feb26_contract3.pdf	2026-04-29 07:41:23.397932
4	4	/invoices/feb26_contract4.pdf	2026-04-29 07:41:23.397932
5	5	/invoices/feb26_contract5.pdf	2026-04-29 07:41:23.397932
6	6	/invoices/feb26_contract6.pdf	2026-04-29 07:41:23.397932
7	7	/invoices/feb26_contract7.pdf	2026-04-29 07:41:23.397932
8	8	/invoices/feb26_contract8.pdf	2026-04-29 07:41:23.397932
9	9	/invoices/feb26_contract9.pdf	2026-04-29 07:41:23.397932
10	10	/invoices/feb26_contract10.pdf	2026-04-29 07:41:23.397932
11	11	/invoices/feb26_contract11.pdf	2026-04-29 07:41:23.397932
12	12	/invoices/feb26_contract12.pdf	2026-04-29 07:41:23.397932
13	13	/invoices/feb26_contract14.pdf	2026-04-29 07:41:23.397932
14	14	/invoices/feb26_contract15.pdf	2026-04-29 07:41:23.397932
15	15	/invoices/feb26_contract16.pdf	2026-04-29 07:41:23.397932
16	16	/invoices/feb26_contract17.pdf	2026-04-29 07:41:23.397932
17	17	/invoices/mar26_contract1.pdf	2026-04-29 07:41:23.397932
18	18	/invoices/mar26_contract2.pdf	2026-04-29 07:41:23.397932
19	33	/app/processed/invoices/Bill_33.pdf	2026-04-29 04:53:40.383916
20	34	/app/processed/invoices/Bill_34.pdf	2026-04-29 04:53:40.466212
21	35	/app/processed/invoices/Bill_35.pdf	2026-04-29 04:53:40.549582
22	36	/app/processed/invoices/Bill_36.pdf	2026-04-29 04:53:40.608886
23	37	/app/processed/invoices/Bill_37.pdf	2026-04-29 04:53:40.68567
24	38	/app/processed/invoices/Bill_38.pdf	2026-04-29 04:53:40.735917
25	39	/app/processed/invoices/Bill_39.pdf	2026-04-29 04:53:40.794805
26	40	/app/processed/invoices/Bill_40.pdf	2026-04-29 04:53:40.837967
27	41	/app/processed/invoices/Bill_41.pdf	2026-04-29 04:53:40.898779
28	43	/app/processed/invoices/Bill_43.pdf	2026-04-29 04:53:40.971321
29	44	/app/processed/invoices/Bill_44.pdf	2026-04-29 04:53:41.010237
30	45	/app/processed/invoices/Bill_45.pdf	2026-04-29 04:53:41.039811
31	46	/app/processed/invoices/Bill_46.pdf	2026-04-29 04:53:41.073356
32	47	/app/processed/invoices/Bill_47.pdf	2026-04-29 04:53:41.105977
33	48	/app/processed/invoices/Bill_48.pdf	2026-04-29 04:53:41.144319
34	49	/app/processed/invoices/Bill_49.pdf	2026-04-29 04:53:41.188514
35	50	/app/processed/invoices/Bill_50.pdf	2026-04-29 04:53:41.225143
36	51	/app/processed/invoices/Bill_51.pdf	2026-04-29 04:53:41.267669
37	52	/app/processed/invoices/Bill_52.pdf	2026-04-29 04:53:41.302365
38	53	/app/processed/invoices/Bill_53.pdf	2026-04-29 04:53:41.338945
39	54	/app/processed/invoices/Bill_54.pdf	2026-04-29 04:53:41.374701
40	55	/app/processed/invoices/Bill_55.pdf	2026-04-29 04:53:41.406937
41	56	/app/processed/invoices/Bill_56.pdf	2026-04-29 04:53:41.437227
42	57	/app/processed/invoices/Bill_57.pdf	2026-04-29 04:53:41.471572
43	58	/app/processed/invoices/Bill_58.pdf	2026-04-29 04:53:41.502378
44	59	/app/processed/invoices/Bill_59.pdf	2026-04-29 04:53:41.540069
45	60	/app/processed/invoices/Bill_60.pdf	2026-04-29 04:53:41.571358
46	61	/app/processed/invoices/Bill_61.pdf	2026-04-29 04:53:41.604397
47	62	/app/processed/invoices/Bill_62.pdf	2026-04-29 04:53:41.636951
48	63	/app/processed/invoices/Bill_63.pdf	2026-04-29 04:53:41.675199
49	64	/app/processed/invoices/Bill_64.pdf	2026-04-29 04:53:41.705227
50	65	/app/processed/invoices/Bill_65.pdf	2026-04-29 04:53:41.738729
51	66	/app/processed/invoices/Bill_66.pdf	2026-04-29 04:53:41.764964
52	67	/app/processed/invoices/Bill_67.pdf	2026-04-29 04:53:41.812597
53	68	/app/processed/invoices/Bill_68.pdf	2026-04-29 04:53:41.840545
54	69	/app/processed/invoices/Bill_69.pdf	2026-04-29 04:53:41.869658
55	70	/app/processed/invoices/Bill_70.pdf	2026-04-29 04:53:41.899492
56	71	/app/processed/invoices/Bill_71.pdf	2026-04-29 04:53:41.925865
57	72	/app/processed/invoices/Bill_72.pdf	2026-04-29 04:53:41.954581
58	73	/app/processed/invoices/Bill_73.pdf	2026-04-29 04:53:41.993719
59	74	/app/processed/invoices/Bill_74.pdf	2026-04-29 04:53:42.026813
60	76	/app/processed/invoices/Bill_76.pdf	2026-04-29 04:53:42.074693
61	77	/app/processed/invoices/Bill_77.pdf	2026-04-29 04:53:42.107802
62	78	/app/processed/invoices/Bill_78.pdf	2026-04-29 04:53:42.137677
\.


--
-- Data for Name: msisdn_pool; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.msisdn_pool (id, msisdn, is_available) FROM stdin;
49	201000000049	t
50	201000000050	t
51	201000000051	t
52	201000000052	t
53	201000000053	t
54	201000000054	t
55	201000000055	t
56	201000000056	t
57	201000000057	t
58	201000000058	t
59	201000000059	t
60	201000000060	t
61	201000000061	t
62	201000000062	t
63	201000000063	t
64	201000000064	t
65	201000000065	t
66	201000000066	t
67	201000000067	t
68	201000000068	t
69	201000000069	t
70	201000000070	t
71	201000000071	t
72	201000000072	t
73	201000000073	t
74	201000000074	t
75	201000000075	t
76	201000000076	t
77	201000000077	t
78	201000000078	t
79	201000000079	t
80	201000000080	t
81	201000000081	t
82	201000000082	t
83	201000000083	t
84	201000000084	t
85	201000000085	t
86	201000000086	t
87	201000000087	t
88	201000000088	t
89	201000000089	t
90	201000000090	t
91	201000000091	t
92	201000000092	t
93	201000000093	t
94	201000000094	t
95	201000000095	t
96	201000000096	t
97	201000000097	t
98	201000000098	t
99	201000000099	t
1	201000000001	f
2	201000000002	f
3	201000000003	f
4	201000000004	f
5	201000000005	f
6	201000000006	f
7	201000000007	f
8	201000000008	f
9	201000000009	f
10	201000000010	f
11	201000000011	f
12	201000000012	f
13	201000000013	f
14	201000000014	f
15	201000000015	f
16	201000000016	f
17	201000000017	f
18	201000000018	f
19	201000000019	f
20	201000000020	f
21	201000000021	f
22	201000000022	f
23	201000000023	f
24	201000000024	f
25	201000000025	f
26	201000000026	f
27	201000000027	f
28	201000000028	f
29	201000000029	f
30	201000000030	f
31	201000000031	f
32	201000000032	f
33	201000000033	f
34	201000000034	f
35	201000000035	f
36	201000000036	f
37	201000000037	f
38	201000000038	f
39	201000000039	f
40	201000000040	f
41	201000000041	f
42	201000000042	f
43	201000000043	f
44	201000000044	f
45	201000000045	f
46	201000000046	f
47	201000000047	f
48	201000000048	f
\.


--
-- Data for Name: rateplan; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.rateplan (id, name, ror_data, ror_voice, ror_sms, ror_roaming_data, ror_roaming_voice, ror_roaming_sms, price) FROM stdin;
1	Basic	0.10	0.20	0.05	\N	\N	\N	75.00
2	Premium Gold	0.05	0.10	0.02	\N	\N	\N	370.00
3	Elite Enterprise	0.02	0.05	0.01	\N	\N	\N	950.00
\.


--
-- Data for Name: rateplan_service_package; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.rateplan_service_package (rateplan_id, service_package_id) FROM stdin;
1	1
1	3
2	1
2	2
2	3
2	4
2	5
2	6
2	7
3	1
3	2
3	3
3	4
3	5
3	6
3	7
\.


--
-- Data for Name: ror_contract; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.ror_contract (contract_id, rateplan_id, starting_date, data, voice, sms, roaming_voice, roaming_data, roaming_sms, bill_id) FROM stdin;
6	2	2026-04-01	2850	40.00	3	0.00	0	0	37
5	1	2026-04-01	0	7.00	2	0.00	0	0	38
4	2	2026-04-01	2100	22.00	2	0.00	0	0	39
3	1	2026-04-01	0	11.00	2	0.00	0	0	40
1	1	2026-04-01	0	43.00	6	0.00	0	0	41
2	2	2026-04-01	3050	31.00	4	5.00	500	1	42
13	1	2026-04-01	0	0.00	0	0.00	0	0	\N
18	1	2026-04-01	0	0.00	0	0.00	0	0	\N
10	2	2026-04-01	2400	23.00	2	0.00	0	0	33
9	1	2026-04-01	0	6.00	2	0.00	0	0	34
8	2	2026-04-01	1400	19.00	2	0.00	0	0	35
7	1	2026-04-01	0	10.00	2	0.00	0	0	36
17	2	2026-04-01	1350	12.00	2	0.00	0	0	73
16	3	2026-04-01	4820	37.00	2	0.00	0	0	74
15	3	2026-04-01	4500	30.00	2	4.00	400	1	75
14	2	2026-04-01	1350	15.00	2	0.00	0	0	76
12	2	2026-04-01	550	11.00	1	0.00	0	0	77
11	1	2026-04-01	0	34.00	4	0.00	0	0	78
\.


--
-- Data for Name: service_package; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.service_package (id, name, type, amount, priority, price, is_roaming, description) FROM stdin;
1	Voice Pack	voice	2000.0000	2	75.00	f	2000 local minutes per month
2	Data Pack	data	10000.0000	2	150.00	f	10GB data per month
3	SMS Pack	sms	500.0000	2	25.00	f	500 SMS per month
4	🎁 Welcome Gift	free_units	10000.0000	1	0.00	f	10GB free data for new customers
5	Roaming Voice Pack	voice	100.0000	2	250.00	t	100 roaming minutes
6	Roaming Data Pack	data	2000.0000	2	500.00	t	2GB roaming data
7	Roaming SMS Pack	sms	100.0000	2	100.00	t	100 roaming SMS
\.


--
-- Data for Name: user_account; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.user_account (id, username, password, role, name, email, address, birthdate) FROM stdin;
1	admin	123456	admin	System Admin	admin@fmrz.com	HQ Cairo	1985-01-01
2	alice	123456	customer	Alice Smith	alice@gmail.com	123 Main St	1990-01-01
3	bob	123456	customer	Bob Johnson	bob@gmail.com	456 Elm St	1985-05-15
4	carol	123456	customer	Carol White	carol@gmail.com	789 Oak Ave	1992-03-10
5	david	123456	customer	David Brown	david@gmail.com	321 Pine Rd	1988-07-22
6	eva	123456	customer	Eva Green	eva@gmail.com	654 Maple Dr	1995-11-05
7	frank	123456	customer	Frank Miller	frank@gmail.com	987 Cedar Ln	1983-02-18
8	grace	123456	customer	Grace Lee	grace@gmail.com	147 Birch Blvd	1991-09-30
9	henry	123456	customer	Henry Wilson	henry@gmail.com	258 Walnut St	1987-04-14
10	iris	123456	customer	Iris Taylor	iris@gmail.com	369 Spruce Ave	1993-06-25
11	jack	123456	customer	Jack Davis	jack@gmail.com	741 Ash Ct	1986-12-03
12	karen	123456	customer	Karen Martinez	karen@gmail.com	852 Elm Pl	1994-08-17
13	leo	123456	customer	Leo Anderson	leo@gmail.com	963 Oak St	1989-01-29
14	mia	123456	customer	Mia Thomas	mia@gmail.com	159 Pine Ave	1996-05-08
15	noah	123456	customer	Noah Jackson	noah@gmail.com	267 Maple Rd	1984-10-21
16	olivia	123456	customer	Olivia Harris	olivia@gmail.com	348 Cedar Dr	1997-03-15
17	paul	123456	customer	Paul Clark	paul@gmail.com	426 Birch Ln	1982-07-04
18	quinn	123456	customer	Quinn Lewis	quinn@gmail.com	537 Walnut Blvd	1998-11-19
19	rachel	123456	customer	Rachel Walker	rachel@gmail.com	648 Spruce St	1981-02-27
20	mariam_101	123456	customer	Mariam Hassan	mariam.hassan11@fmrz-telecom.com	70 El-Nasr St, Cairo	2009-12-29
21	sara_102	123456	customer	Sara Hassan	sara.hassan12@fmrz-telecom.com	44 Cornish Rd, Suez	2009-08-25
22	amir_103	123456	customer	Amir Mansour	amir.mansour13@fmrz-telecom.com	38 Tahrir Sq, Cairo	1990-08-12
23	hassan_104	123456	customer	Hassan Soliman	hassan.soliman14@fmrz-telecom.com	32 Gameat El Dowal, Giza	1986-05-25
24	layla_105	123456	customer	Layla Hassan	layla.hassan15@fmrz-telecom.com	49 Makram Ebeid, Cairo	2005-12-29
25	hassan_106	123456	customer	Hassan Khattab	hassan.khattab16@fmrz-telecom.com	52 Tahrir Sq, Suez	2003-08-23
26	fatma_107	123456	customer	Fatma Wahba	fatma.wahba17@fmrz-telecom.com	83 9th Street, Luxor	2008-12-23
27	ahmed_108	123456	customer	Ahmed Said	ahmed.said18@fmrz-telecom.com	44 Cornish Rd, Mansoura	2000-10-04
28	youssef_109	123456	customer	Youssef Gaber	youssef.gaber19@fmrz-telecom.com	13 Tahrir Sq, Giza	1992-08-23
29	nour_110	123456	customer	Nour Gaber	nour.gaber20@fmrz-telecom.com	45 El-Nasr St, Cairo	1986-06-10
30	mariam_111	123456	customer	Mariam Hassan	mariam.hassan21@fmrz-telecom.com	33 9th Street, Luxor	1990-05-10
31	salma_112	123456	customer	Salma Fouad	salma.fouad22@fmrz-telecom.com	61 9th Street, Cairo	1988-11-04
32	fatma_113	123456	customer	Fatma Wahba	fatma.wahba23@fmrz-telecom.com	15 Tahrir Sq, Cairo	1991-04-01
33	hassan_114	123456	customer	Hassan Gaber	hassan.gaber24@fmrz-telecom.com	71 Cornish Rd, Alexandria	2010-03-05
34	sara_115	123456	customer	Sara Nasr	sara.nasr25@fmrz-telecom.com	56 El-Nasr St, Cairo	2010-08-14
35	omar_116	123456	customer	Omar Zaki	omar.zaki26@fmrz-telecom.com	52 Cornish Rd, Cairo	2009-12-30
36	mohamed_117	123456	customer	Mohamed Wahba	mohamed.wahba27@fmrz-telecom.com	25 Cornish Rd, Cairo	2002-05-19
37	mohamed_118	123456	customer	Mohamed Gaber	mohamed.gaber28@fmrz-telecom.com	52 Abbas El Akkad, Giza	1994-10-29
38	omar_119	123456	customer	Omar Fouad	omar.fouad29@fmrz-telecom.com	94 Makram Ebeid, Mansoura	1997-10-03
39	ziad_120	123456	customer	Ziad Zaki	ziad.zaki30@fmrz-telecom.com	69 Abbas El Akkad, Alexandria	1986-06-22
40	mohamed_121	123456	customer	Mohamed Said	mohamed.said31@fmrz-telecom.com	51 Makram Ebeid, Mansoura	2000-10-13
41	youssef_122	123456	customer	Youssef Mansour	youssef.mansour32@fmrz-telecom.com	57 Gameat El Dowal, Luxor	1986-08-06
42	ziad_123	123456	customer	Ziad Ezzat	ziad.ezzat33@fmrz-telecom.com	18 Gameat El Dowal, Luxor	1985-01-22
43	salma_124	123456	customer	Salma Nasr	salma.nasr34@fmrz-telecom.com	10 Cornish Rd, Alexandria	1996-12-23
44	sara_125	123456	customer	Sara Khattab	sara.khattab35@fmrz-telecom.com	76 Cornish Rd, Mansoura	1999-04-19
45	ziad_126	123456	customer	Ziad Ezzat	ziad.ezzat36@fmrz-telecom.com	44 Gameat El Dowal, Suez	1997-01-20
46	ibrahim_127	123456	customer	Ibrahim Fouad	ibrahim.fouad37@fmrz-telecom.com	67 Tahrir Sq, Cairo	1999-11-08
47	amir_128	123456	customer	Amir Salem	amir.salem38@fmrz-telecom.com	13 Abbas El Akkad, Cairo	1998-10-30
48	ibrahim_129	123456	customer	Ibrahim Ezzat	ibrahim.ezzat39@fmrz-telecom.com	93 Gameat El Dowal, Luxor	2001-05-05
49	omar_130	123456	customer	Omar Zaki	omar.zaki40@fmrz-telecom.com	10 Cornish Rd, Alexandria	1994-03-04
\.


--
-- Data for Name: v_msisdn; Type: TABLE DATA; Schema: public; Owner: zkhattab
--

COPY public.v_msisdn (msisdn) FROM stdin;
\.


--
-- Name: bill_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.bill_id_seq', 78, true);


--
-- Name: cdr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.cdr_id_seq', 229, true);


--
-- Name: contract_addon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.contract_addon_id_seq', 1, false);


--
-- Name: contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.contract_id_seq', 48, true);


--
-- Name: file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.file_id_seq', 5, true);


--
-- Name: invoice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.invoice_id_seq', 62, true);


--
-- Name: msisdn_pool_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.msisdn_pool_id_seq', 99, true);


--
-- Name: rateplan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.rateplan_id_seq', 3, true);


--
-- Name: service_package_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.service_package_id_seq', 7, true);


--
-- Name: user_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zkhattab
--

SELECT pg_catalog.setval('public.user_account_id_seq', 49, true);


--
-- Name: bill bill_contract_id_billing_period_start_key; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_contract_id_billing_period_start_key UNIQUE (contract_id, billing_period_start);


--
-- Name: bill bill_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_pkey PRIMARY KEY (id);


--
-- Name: cdr cdr_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.cdr
    ADD CONSTRAINT cdr_pkey PRIMARY KEY (id);


--
-- Name: contract_addon contract_addon_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_addon
    ADD CONSTRAINT contract_addon_pkey PRIMARY KEY (id);


--
-- Name: contract_consumption contract_consumption_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_pkey PRIMARY KEY (contract_id, service_package_id, rateplan_id, starting_date, ending_date);


--
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (id);


--
-- Name: file file_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.file
    ADD CONSTRAINT file_pkey PRIMARY KEY (id);


--
-- Name: invoice invoice_bill_id_key; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_bill_id_key UNIQUE (bill_id);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (id);


--
-- Name: msisdn_pool msisdn_pool_msisdn_key; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.msisdn_pool
    ADD CONSTRAINT msisdn_pool_msisdn_key UNIQUE (msisdn);


--
-- Name: msisdn_pool msisdn_pool_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.msisdn_pool
    ADD CONSTRAINT msisdn_pool_pkey PRIMARY KEY (id);


--
-- Name: rateplan rateplan_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.rateplan
    ADD CONSTRAINT rateplan_pkey PRIMARY KEY (id);


--
-- Name: rateplan_service_package rateplan_service_package_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.rateplan_service_package
    ADD CONSTRAINT rateplan_service_package_pkey PRIMARY KEY (rateplan_id, service_package_id);


--
-- Name: ror_contract ror_contract_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.ror_contract
    ADD CONSTRAINT ror_contract_pkey PRIMARY KEY (contract_id, rateplan_id, starting_date);


--
-- Name: service_package service_package_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.service_package
    ADD CONSTRAINT service_package_pkey PRIMARY KEY (id);


--
-- Name: user_account user_account_email_key; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_email_key UNIQUE (email);


--
-- Name: user_account user_account_pkey; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_pkey PRIMARY KEY (id);


--
-- Name: user_account user_account_username_key; Type: CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_username_key UNIQUE (username);


--
-- Name: contract_msisdn_active_idx; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE UNIQUE INDEX contract_msisdn_active_idx ON public.contract USING btree (msisdn) WHERE (status <> 'terminated'::public.contract_status);


--
-- Name: idx_addon_active; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_addon_active ON public.contract_addon USING btree (contract_id, is_active);


--
-- Name: idx_addon_contract; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_addon_contract ON public.contract_addon USING btree (contract_id);


--
-- Name: idx_bill_billing_date; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_bill_billing_date ON public.bill USING btree (billing_date);


--
-- Name: idx_bill_contract; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_bill_contract ON public.bill USING btree (contract_id);


--
-- Name: idx_cdr_dial_a; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_cdr_dial_a ON public.cdr USING btree (dial_a);


--
-- Name: idx_cdr_file_id; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_cdr_file_id ON public.cdr USING btree (file_id);


--
-- Name: idx_cdr_rated_flag; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_cdr_rated_flag ON public.cdr USING btree (rated_flag);


--
-- Name: idx_contract_user_account; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_contract_user_account ON public.contract USING btree (user_account_id);


--
-- Name: idx_invoice_bill; Type: INDEX; Schema: public; Owner: zkhattab
--

CREATE INDEX idx_invoice_bill ON public.invoice USING btree (bill_id);


--
-- Name: cdr trg_auto_initialize_consumption; Type: TRIGGER; Schema: public; Owner: zkhattab
--

CREATE TRIGGER trg_auto_initialize_consumption BEFORE INSERT ON public.cdr FOR EACH ROW EXECUTE FUNCTION public.auto_initialize_consumption();


--
-- Name: cdr trg_auto_rate_cdr; Type: TRIGGER; Schema: public; Owner: zkhattab
--

CREATE TRIGGER trg_auto_rate_cdr AFTER INSERT ON public.cdr FOR EACH ROW EXECUTE FUNCTION public.auto_rate_cdr();


--
-- Name: bill trg_bill_inserted; Type: TRIGGER; Schema: public; Owner: zkhattab
--

CREATE TRIGGER trg_bill_inserted AFTER INSERT ON public.bill FOR EACH ROW EXECUTE FUNCTION public.notify_bill_generation();


--
-- Name: bill trg_bill_payment; Type: TRIGGER; Schema: public; Owner: zkhattab
--

CREATE TRIGGER trg_bill_payment AFTER UPDATE ON public.bill FOR EACH ROW EXECUTE FUNCTION public.trg_restore_credit_on_payment();


--
-- Name: cdr trg_cdr_validate_contract; Type: TRIGGER; Schema: public; Owner: zkhattab
--

CREATE TRIGGER trg_cdr_validate_contract BEFORE INSERT ON public.cdr FOR EACH ROW EXECUTE FUNCTION public.validate_cdr_contract();


--
-- Name: bill bill_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: cdr cdr_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.cdr
    ADD CONSTRAINT cdr_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.file(id);


--
-- Name: cdr cdr_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.cdr
    ADD CONSTRAINT cdr_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.service_package(id);


--
-- Name: contract_addon contract_addon_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_addon
    ADD CONSTRAINT contract_addon_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: contract_addon contract_addon_service_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_addon
    ADD CONSTRAINT contract_addon_service_package_id_fkey FOREIGN KEY (service_package_id) REFERENCES public.service_package(id);


--
-- Name: contract_consumption contract_consumption_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bill(id);


--
-- Name: contract_consumption contract_consumption_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: contract_consumption contract_consumption_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- Name: contract_consumption contract_consumption_service_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_service_package_id_fkey FOREIGN KEY (service_package_id) REFERENCES public.service_package(id);


--
-- Name: contract contract_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- Name: contract contract_user_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_user_account_id_fkey FOREIGN KEY (user_account_id) REFERENCES public.user_account(id);


--
-- Name: invoice invoice_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bill(id);


--
-- Name: rateplan_service_package rateplan_service_package_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.rateplan_service_package
    ADD CONSTRAINT rateplan_service_package_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- Name: rateplan_service_package rateplan_service_package_service_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.rateplan_service_package
    ADD CONSTRAINT rateplan_service_package_service_package_id_fkey FOREIGN KEY (service_package_id) REFERENCES public.service_package(id);


--
-- Name: ror_contract ror_contract_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.ror_contract
    ADD CONSTRAINT ror_contract_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: ror_contract ror_contract_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zkhattab
--

ALTER TABLE ONLY public.ror_contract
    ADD CONSTRAINT ror_contract_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- PostgreSQL database dump complete
--

\unrestrict dG7Kti98q4JC7ooEAbgDHCu8D8JT07TUV47bhWDd8IREPnIRkzQPw3XXfH82BGX

