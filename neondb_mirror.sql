--
-- PostgreSQL database dump
--

\restrict RZ0XRzmeZoZ1ybGetgVu3gbLXq1chkbw5juKHuKEC0qb0oGK9XlPhTxrdlQz0Ns

-- Dumped from database version 17.8 (130b160)
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
-- Name: bill_status; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.bill_status AS ENUM (
    'draft',
    'issued',
    'paid',
    'overdue',
    'cancelled'
);


ALTER TYPE public.bill_status OWNER TO neondb_owner;

--
-- Name: contract_recurring_status; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.contract_recurring_status AS ENUM (
    'Active',
    'Suspended',
    'Cancelled',
    'Completed'
);


ALTER TYPE public.contract_recurring_status OWNER TO neondb_owner;

--
-- Name: contract_status; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.contract_status AS ENUM (
    'active',
    'suspended',
    'terminated'
);


ALTER TYPE public.contract_status OWNER TO neondb_owner;

--
-- Name: contract_status_enum; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.contract_status_enum AS ENUM (
    'Active',
    'Suspended',
    'Terminated',
    'Credit_Blocked'
);


ALTER TYPE public.contract_status_enum OWNER TO neondb_owner;

--
-- Name: cot_status_enum; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.cot_status_enum AS ENUM (
    'Active',
    'Expired',
    'Cancelled'
);


ALTER TYPE public.cot_status_enum OWNER TO neondb_owner;

--
-- Name: cr_status_enum; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.cr_status_enum AS ENUM (
    'Active',
    'Suspended',
    'Cancelled',
    'Completed'
);


ALTER TYPE public.cr_status_enum OWNER TO neondb_owner;

--
-- Name: customer_type; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.customer_type AS ENUM (
    'Individual',
    'Corporate'
);


ALTER TYPE public.customer_type OWNER TO neondb_owner;

--
-- Name: one_time_status; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.one_time_status AS ENUM (
    'Active',
    'Expired',
    'Cancelled'
);


ALTER TYPE public.one_time_status OWNER TO neondb_owner;

--
-- Name: rateplan_status; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.rateplan_status AS ENUM (
    'Active',
    'Inactive'
);


ALTER TYPE public.rateplan_status OWNER TO neondb_owner;

--
-- Name: rateplan_status_enum; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.rateplan_status_enum AS ENUM (
    'Active',
    'Inactive'
);


ALTER TYPE public.rateplan_status_enum OWNER TO neondb_owner;

--
-- Name: service_type; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.service_type AS ENUM (
    'voice',
    'data',
    'sms',
    'free_units'
);


ALTER TYPE public.service_type OWNER TO neondb_owner;

--
-- Name: service_type_enum; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.service_type_enum AS ENUM (
    'Voice',
    'Data',
    'SMS',
    'Roaming',
    'VAS',
    'Other'
);


ALTER TYPE public.service_type_enum OWNER TO neondb_owner;

--
-- Name: service_uom; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.service_uom AS ENUM (
    'Minute',
    'MB',
    'GB',
    'SMS',
    'Event'
);


ALTER TYPE public.service_uom OWNER TO neondb_owner;

--
-- Name: service_uom_enum; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.service_uom_enum AS ENUM (
    'Minute',
    'MB',
    'GB',
    'SMS',
    'Event'
);


ALTER TYPE public.service_uom_enum OWNER TO neondb_owner;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.user_role AS ENUM (
    'admin',
    'customer'
);


ALTER TYPE public.user_role OWNER TO neondb_owner;

--
-- Name: auto_initialize_consumption(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.auto_initialize_consumption() OWNER TO neondb_owner;

--
-- Name: auto_rate_cdr(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.auto_rate_cdr() OWNER TO neondb_owner;

--
-- Name: cancel_addon(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.cancel_addon(p_addon_id integer) OWNER TO neondb_owner;

--
-- Name: change_contract_rateplan(integer, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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

        v_taxes := ROUND(0.15 * (v_prorated_recurring + v_prorated_charge), 2);
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


ALTER FUNCTION public.change_contract_rateplan(p_contract_id integer, p_new_rateplan_id integer) OWNER TO neondb_owner;

--
-- Name: change_contract_status(integer, public.contract_status); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.change_contract_status(p_contract_id integer, p_status public.contract_status) OWNER TO neondb_owner;

--
-- Name: create_admin(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.create_admin(p_username character varying, p_password character varying, p_name character varying, p_email character varying) OWNER TO neondb_owner;

--
-- Name: create_admin(character varying, character varying, character varying, character varying, text, date); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.create_admin(p_username character varying, p_password character varying, p_name character varying, p_email character varying, p_address text, p_birthdate date) OWNER TO neondb_owner;

--
-- Name: create_contract(integer, integer, character varying, double precision); Type: FUNCTION; Schema: public; Owner: neondb_owner
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
        starting_date, ending_date, consumed, is_billed
    )
    SELECT v_contract_id, rsp.service_package_id, p_rateplan_id,
           v_period_start, v_period_end, 0, FALSE
    FROM rateplan_service_package rsp
    WHERE rsp.rateplan_id = p_rateplan_id
    ON CONFLICT DO NOTHING;

    RETURN v_contract_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'create_contract failed: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.create_contract(p_user_account_id integer, p_rateplan_id integer, p_msisdn character varying, p_credit_limit double precision) OWNER TO neondb_owner;

--
-- Name: create_customer(character varying, character varying, character varying, character varying, text, date); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.create_customer(p_username character varying, p_password character varying, p_name character varying, p_email character varying, p_address text, p_birthdate date) OWNER TO neondb_owner;

--
-- Name: create_file_record(text); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.create_file_record(p_file_path text) OWNER TO neondb_owner;

--
-- Name: create_service_package(character varying, public.service_type, numeric, integer, numeric, text, boolean); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.create_service_package(p_name character varying, p_type public.service_type, p_amount numeric, p_priority integer, p_price numeric, p_description text, p_is_roaming boolean) OWNER TO neondb_owner;

--
-- Name: expire_addons(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.expire_addons() OWNER TO neondb_owner;

--
-- Name: generate_all_bills(date); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.generate_all_bills(p_period_start date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
v_contract RECORD;
    v_success  INTEGER := 0;
    v_failed   INTEGER := 0;
BEGIN
FOR v_contract IN
SELECT id FROM contract WHERE status = 'active'
    LOOP
BEGIN
            PERFORM generate_bill(v_contract.id, p_period_start);
            v_success := v_success + 1;
EXCEPTION
            WHEN OTHERS THEN
                -- Log failure but continue processing remaining contracts
                RAISE WARNING 'generate_bill failed for contract %: %', v_contract.id, SQLERRM;
                v_failed := v_failed + 1;
END;
END LOOP;

    RAISE NOTICE 'generate_all_bills complete: % succeeded, % failed', v_success, v_failed;
END;
$$;


ALTER FUNCTION public.generate_all_bills(p_period_start date) OWNER TO neondb_owner;

--
-- Name: generate_bill(integer, date); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.generate_bill(p_contract_id integer, p_billing_period_start date) RETURNS void
    LANGUAGE plpgsql
    AS $$
       DECLARE v_billing_period_end DATE;
               v_recurring_fees NUMERIC(12,2);
               v_one_time_fees NUMERIC(12,2);
               v_voice_usage INTEGER;
               v_data_usage INTEGER;
               v_sms_usage INTEGER;
               v_ROR_charge NUMERIC(12,2);
               v_taxes NUMERIC(12,2);
               v_total_amount NUMERIC(12,2);
               v_rateplan_id INTEGER;
               v_bill_id INTEGER;
BEGIN
               v_billing_period_end := (DATE_TRUNC('month', p_billing_period_start) + INTERVAL '1 month - 1 day')::DATE;
                -- Load rateplan_id for convenience
SELECT rateplan_id INTO v_rateplan_id
FROM contract
WHERE id = p_contract_id;

-- Calculate recurring fees from rateplan price
SELECT price INTO v_recurring_fees
FROM rateplan
WHERE id = v_rateplan_id;

-- Calculate usage fees from consumption and ROR
SELECT SUM(CASE WHEN sp.type = 'voice' THEN cc.consumed ELSE 0 END),
       SUM(CASE WHEN sp.type = 'data' THEN cc.consumed ELSE 0 END),
       SUM(CASE WHEN sp.type = 'sms' THEN cc.consumed ELSE 0 END)

INTO v_voice_usage, v_data_usage, v_sms_usage
FROM contract_consumption cc
         JOIN service_package sp ON sp.id = cc.service_package_id
WHERE cc.contract_id = p_contract_id
  AND cc.starting_date = p_billing_period_start
  AND cc.ending_date = v_billing_period_end
  AND cc.is_billed = FALSE;
SELECT COALESCE(
               (rc.data * rp.ror_data) + (rc.voice * rp.ror_voice) + (rc.sms * rp.ror_sms),0) INTO v_ROR_charge
FROM ror_contract rc
         JOIN rateplan rp ON rp.id = rc.rateplan_id
WHERE contract_id = p_contract_id
  AND rateplan_id = v_rateplan_id
  AND bill_id IS NULL;  -- only consider unbilled ROR

-- For simplicity, let's say taxes are 15% of (recurring + ROR)
v_one_time_fees := 0.69;  -- could include one-time charges here
v_taxes := 0.15 * (v_recurring_fees + v_ROR_charge);
v_total_amount := v_recurring_fees + v_one_time_fees + v_ROR_charge + v_taxes;

    -- Insert bill
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
    ROR_charge,
    taxes,
    total_amount,
    status,
    is_paid
)VALUES (
            p_contract_id,
            p_billing_period_start,
            v_billing_period_end,
            CURRENT_DATE,
            v_recurring_fees,
            v_one_time_fees,
            v_voice_usage,
            v_data_usage,
            v_sms_usage,
            v_ROR_charge,
            v_taxes,
            v_total_amount,
            'issued',
            FALSE
        )RETURNING id INTO v_bill_id;
-- Mark consumption and ROR rows as billed
UPDATE contract_consumption
SET is_billed = TRUE, bill_id = v_bill_id
WHERE contract_id = p_contract_id
  AND starting_date = p_billing_period_start
  AND ending_date = v_billing_period_end;
UPDATE ror_contract
SET bill_id = v_bill_id
WHERE contract_id = p_contract_id  AND rateplan_id = v_rateplan_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'generate_bill failed for contract id % and period %: %', p_contract_id, p_billing_period_start, SQLERRM;
END;
$$;


ALTER FUNCTION public.generate_bill(p_contract_id integer, p_billing_period_start date) OWNER TO neondb_owner;

--
-- Name: generate_invoice(integer, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.generate_invoice(p_bill_id integer, p_pdf_path text) OWNER TO neondb_owner;

--
-- Name: get_admin_stats(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_admin_stats() OWNER TO neondb_owner;

--
-- Name: get_all_contracts(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_all_contracts() RETURNS TABLE(id integer, msisdn character varying, status public.contract_status, available_credit numeric, customer_name character varying, rateplan_name character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            c.id,
            c.msisdn,
            c.status,
            c.available_credit,
            u.name  AS customer_name,
            r.name  AS rateplan_name
        FROM contract c
                 JOIN user_account u ON c.user_account_id = u.id
                 LEFT JOIN rateplan r ON c.rateplan_id = r.id
        ORDER BY c.id DESC;
END;
$$;


ALTER FUNCTION public.get_all_contracts() OWNER TO neondb_owner;

--
-- Name: get_all_customers(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_all_customers() RETURNS TABLE(id integer, username character varying, name character varying, email character varying, role public.user_role, address text, birthdate date)
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
        WHERE ua.role = 'customer'
        ORDER BY ua.id DESC;
END;
$$;


ALTER FUNCTION public.get_all_customers() OWNER TO neondb_owner;

--
-- Name: get_all_rateplans(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_all_rateplans() OWNER TO neondb_owner;

--
-- Name: get_all_service_packages(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_all_service_packages() OWNER TO neondb_owner;

--
-- Name: get_available_msisdns(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_available_msisdns() OWNER TO neondb_owner;

--
-- Name: get_bill(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_bill(p_bill_id integer) OWNER TO neondb_owner;

--
-- Name: get_bills_by_contract(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_bills_by_contract(p_contract_id integer) OWNER TO neondb_owner;

--
-- Name: get_cdr_usage_amount(integer, public.service_type); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_cdr_usage_amount(p_duration integer, p_service_type public.service_type) OWNER TO neondb_owner;

--
-- Name: get_cdrs(integer, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_cdrs(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, msisdn character varying, destination character varying, duration integer, "timestamp" timestamp without time zone, type integer, rated boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            c.id,
            c.dial_a   AS msisdn,
            c.dial_b   AS destination,
            c.duration,
            c.start_time AS timestamp,
            c.service_id AS type,
            c.rated_flag AS rated
        FROM cdr c
        ORDER BY c.start_time DESC
        LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION public.get_cdrs(p_limit integer, p_offset integer) OWNER TO neondb_owner;

--
-- Name: get_contract_addons(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_contract_addons(p_contract_id integer) OWNER TO neondb_owner;

--
-- Name: get_contract_by_id(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_contract_by_id(p_id integer) OWNER TO neondb_owner;

--
-- Name: get_contract_consumption(integer, date); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_contract_consumption(p_contract_id integer, p_period_start date) OWNER TO neondb_owner;

--
-- Name: get_customer_by_id(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_customer_by_id(p_id integer) OWNER TO neondb_owner;

--
-- Name: get_dashboard_stats(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_dashboard_stats() RETURNS TABLE(total_customers bigint, total_contracts bigint, active_contracts bigint, total_cdrs bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM user_account  WHERE role = 'customer'),
        (SELECT COUNT(*) FROM contract),
        (SELECT COUNT(*) FROM contract      WHERE status = 'active'),
        (SELECT COUNT(*) FROM cdr);
END;
$$;


ALTER FUNCTION public.get_dashboard_stats() OWNER TO neondb_owner;

--
-- Name: get_missing_bills(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_missing_bills() RETURNS TABLE(contract_id integer, msisdn character varying, customer_name character varying, rateplan_name character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_period_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
BEGIN
    RETURN QUERY
        SELECT
            c.id           AS contract_id,
            c.msisdn,
            u.name         AS customer_name,
            r.name         AS rateplan_name
        FROM contract c
                 JOIN user_account u ON c.user_account_id = u.id
                 LEFT JOIN rateplan r ON c.rateplan_id = r.id
        WHERE c.status = 'active'
          AND NOT EXISTS (
            SELECT 1 FROM bill b
            WHERE b.contract_id = c.id
              AND b.billing_period_start = v_period_start
        )
        ORDER BY c.id;
END;
$$;


ALTER FUNCTION public.get_missing_bills() OWNER TO neondb_owner;

--
-- Name: get_rateplan_by_id(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_rateplan_by_id(p_id integer) OWNER TO neondb_owner;

--
-- Name: get_rateplan_data(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_rateplan_data(p_rateplan_id integer) OWNER TO neondb_owner;

--
-- Name: get_service_package_by_id(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_service_package_by_id(p_id integer) OWNER TO neondb_owner;

--
-- Name: get_user_contracts(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_user_contracts(p_user_id integer) OWNER TO neondb_owner;

--
-- Name: get_user_data(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_user_data(p_user_account_id integer) OWNER TO neondb_owner;

--
-- Name: get_user_invoices(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_user_invoices(p_user_id integer) OWNER TO neondb_owner;

--
-- Name: get_user_msisdn_bill(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.get_user_msisdn_bill(p_contract_id integer) OWNER TO neondb_owner;

--
-- Name: initialize_consumption_period(date); Type: FUNCTION; Schema: public; Owner: neondb_owner
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
    is_billed
)
SELECT
    c.id,
    rsp.service_package_id,
    c.rateplan_id,
    p_period_start,
    v_period_end,
    0,
    FALSE
FROM contract c
         JOIN rateplan_service_package rsp ON rsp.rateplan_id = c.rateplan_id
WHERE c.status = 'active'
    ON CONFLICT DO NOTHING;  -- safe to re-run

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'initialize_consumption_period failed for period %: %', p_period_start, SQLERRM;
END;
$$;


ALTER FUNCTION public.initialize_consumption_period(p_period_start date) OWNER TO neondb_owner;

--
-- Name: insert_cdr(integer, character varying, character varying, timestamp without time zone, integer, integer, character varying, character varying, numeric); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.insert_cdr(p_file_id integer, p_dial_a character varying, p_dial_b character varying, p_start_time timestamp without time zone, p_duration integer, p_service_id integer, p_hplmn character varying, p_vplmn character varying, p_external_charges numeric) OWNER TO neondb_owner;

--
-- Name: login(character varying, character varying); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.login(p_username character varying, p_password character varying) OWNER TO neondb_owner;

--
-- Name: mark_bill_paid(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.mark_bill_paid(p_bill_id integer) OWNER TO neondb_owner;

--
-- Name: mark_msisdn_taken(character varying); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.mark_msisdn_taken(p_msisdn character varying) OWNER TO neondb_owner;

--
-- Name: pay_bill(integer, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.pay_bill(p_bill_id integer, p_pdf_path text) OWNER TO neondb_owner;

--
-- Name: purchase_addon(integer, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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

    -- Check not already active
    IF EXISTS (
        SELECT 1 FROM contract_addon
        WHERE contract_id        = p_contract_id
          AND service_package_id = p_service_package_id
          AND is_active          = TRUE
    ) THEN
        RAISE EXCEPTION 'Add-on already active for this contract';
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

    -- Add consumption row so rate_cdr can deduct from it
    v_period_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_period_end   := v_expiry;

    INSERT INTO contract_consumption (
        contract_id, service_package_id, rateplan_id,
        starting_date, ending_date, consumed, is_billed
    )
    SELECT
        p_contract_id,
        p_service_package_id,
        c.rateplan_id,
        v_period_start,
        v_period_end,
        0,
        FALSE
    FROM contract c
    WHERE c.id = p_contract_id
    ON CONFLICT DO NOTHING;

    RETURN v_addon_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'purchase_addon failed: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.purchase_addon(p_contract_id integer, p_service_package_id integer) OWNER TO neondb_owner;

--
-- Name: rate_cdr(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.rate_cdr(p_cdr_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
v_cdr            cdr;
    v_contract       contract;
    v_service_type   service_type;
    v_usage_amount   NUMERIC;
    v_remaining      NUMERIC;
    v_bundle         RECORD;
    v_available      NUMERIC;
    v_deduct         NUMERIC;
    v_ror_rate       NUMERIC;
    v_overage_charge NUMERIC := 0;
    v_period_start   DATE;
    v_period_end     DATE;
BEGIN
    -- Load CDR
SELECT * INTO v_cdr FROM cdr WHERE id = p_cdr_id;
IF NOT FOUND THEN
        RAISE EXCEPTION 'CDR with id % not found', p_cdr_id;
END IF;

    -- Guard: skip if already rated
    IF v_cdr.rated_flag THEN
        RAISE NOTICE 'CDR % already rated, skipping.', p_cdr_id;
        RETURN;
END IF;

    -- Resolve active contract from dial_a
SELECT * INTO v_contract
FROM contract
WHERE msisdn = v_cdr.dial_a
  AND status = 'active';
IF NOT FOUND THEN
        RAISE EXCEPTION 'No active contract found for MSISDN %', v_cdr.dial_a;
END IF;

    -- Resolve service type from the CDR's service_package
SELECT type INTO v_service_type
FROM service_package
WHERE id = v_cdr.service_id;
IF NOT FOUND THEN
        RAISE EXCEPTION 'Service package with id % not found', v_cdr.service_id;
END IF;

    -- Normalise usage into the unit used by contract_consumption
    v_usage_amount := get_cdr_usage_amount(v_cdr.duration, v_service_type);
    v_remaining    := v_usage_amount;

    -- Billing period boundaries
    v_period_start := DATE_TRUNC('month', v_cdr.start_time)::DATE;
    v_period_end   := (DATE_TRUNC('month', v_cdr.start_time) + INTERVAL '1 month - 1 day')::DATE;

    -- Deduct from bundles in priority order
FOR v_bundle IN
SELECT
    cc.service_package_id,
    cc.rateplan_id,
    cc.starting_date,
    cc.ending_date,
    sp.amount,
    sp.priority,
    cc.consumed
FROM contract_consumption cc
         JOIN service_package sp ON sp.id = cc.service_package_id
WHERE cc.contract_id   = v_contract.id
  AND cc.rateplan_id   = v_contract.rateplan_id
  AND cc.starting_date = v_period_start
  AND cc.ending_date   = v_period_end
  AND cc.is_billed     = FALSE
  AND sp.type          = v_service_type   -- only match relevant service type
ORDER BY sp.priority ASC
    LOOP
        EXIT WHEN v_remaining <= 0;

v_available := v_bundle.amount - v_bundle.consumed;

        IF v_available <= 0 THEN
            CONTINUE;  -- bundle exhausted, move to next
END IF;

        v_deduct    := LEAST(v_remaining, v_available);
        v_remaining := v_remaining - v_deduct;

UPDATE contract_consumption
SET consumed = consumed + v_deduct
WHERE contract_id        = v_contract.id
  AND service_package_id = v_bundle.service_package_id
  AND rateplan_id        = v_bundle.rateplan_id
  AND starting_date      = v_bundle.starting_date
  AND ending_date        = v_bundle.ending_date;
END LOOP;

    -- Handle overage: anything remaining after all bundles exhausted
    IF v_remaining > 0 AND v_service_type != 'free_units' THEN
SELECT CASE v_service_type
           WHEN 'voice' THEN ror_voice
           WHEN 'data'  THEN ror_data
           WHEN 'sms'   THEN ror_sms
           END INTO v_ror_rate
FROM rateplan
WHERE id = v_contract.rateplan_id;

v_overage_charge := v_remaining * COALESCE(v_ror_rate, 0);

        -- Accumulate overage units in ror_contract
INSERT INTO ror_contract (contract_id, rateplan_id, voice, data, sms)
VALUES (
           v_contract.id,
           v_contract.rateplan_id,
           CASE WHEN v_service_type = 'voice' THEN v_remaining ELSE 0 END,
           CASE WHEN v_service_type = 'data'  THEN v_remaining ELSE 0 END,
           CASE WHEN v_service_type = 'sms'   THEN v_remaining ELSE 0 END
       )
    ON CONFLICT (contract_id, rateplan_id) DO UPDATE SET
    voice = ror_contract.voice + EXCLUDED.voice,
                                                  data  = ror_contract.data  + EXCLUDED.data,
                                                  sms   = ror_contract.sms   + EXCLUDED.sms;

-- Deduct overage charge from available credit
UPDATE contract
SET available_credit = available_credit - v_overage_charge
WHERE id = v_contract.id;
END IF;

    -- Mark CDR as rated
UPDATE cdr
SET rated_flag = TRUE
WHERE id = p_cdr_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'rate_cdr failed for CDR id %: %', p_cdr_id, SQLERRM;
END;
$$;


ALTER FUNCTION public.rate_cdr(p_cdr_id integer) OWNER TO neondb_owner;

--
-- Name: release_msisdn(character varying); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.release_msisdn(p_msisdn character varying) OWNER TO neondb_owner;

--
-- Name: set_file_parsed(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.set_file_parsed(p_file_id integer) OWNER TO neondb_owner;

--
-- Name: trg_restore_credit_on_payment(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.trg_restore_credit_on_payment() OWNER TO neondb_owner;

--
-- Name: validate_cdr_contract(); Type: FUNCTION; Schema: public; Owner: neondb_owner
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


ALTER FUNCTION public.validate_cdr_contract() OWNER TO neondb_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bill; Type: TABLE; Schema: public; Owner: neondb_owner
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
    taxes numeric(12,2) DEFAULT 0 NOT NULL,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    status public.bill_status DEFAULT 'draft'::public.bill_status NOT NULL,
    is_paid boolean DEFAULT false NOT NULL
);


ALTER TABLE public.bill OWNER TO neondb_owner;

--
-- Name: bill_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.bill_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bill_id_seq OWNER TO neondb_owner;

--
-- Name: bill_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.bill_id_seq OWNED BY public.bill.id;


--
-- Name: cdr; Type: TABLE; Schema: public; Owner: neondb_owner
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
    rated_flag boolean DEFAULT false NOT NULL
);


ALTER TABLE public.cdr OWNER TO neondb_owner;

--
-- Name: cdr_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.cdr_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cdr_id_seq OWNER TO neondb_owner;

--
-- Name: cdr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.cdr_id_seq OWNED BY public.cdr.id;


--
-- Name: contract; Type: TABLE; Schema: public; Owner: neondb_owner
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


ALTER TABLE public.contract OWNER TO neondb_owner;

--
-- Name: contract_addon; Type: TABLE; Schema: public; Owner: neondb_owner
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


ALTER TABLE public.contract_addon OWNER TO neondb_owner;

--
-- Name: contract_addon_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.contract_addon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contract_addon_id_seq OWNER TO neondb_owner;

--
-- Name: contract_addon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.contract_addon_id_seq OWNED BY public.contract_addon.id;


--
-- Name: contract_consumption; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.contract_consumption (
    contract_id integer NOT NULL,
    service_package_id integer NOT NULL,
    rateplan_id integer NOT NULL,
    starting_date date NOT NULL,
    ending_date date NOT NULL,
    consumed integer DEFAULT 0 NOT NULL,
    is_billed boolean DEFAULT false NOT NULL,
    bill_id integer
);


ALTER TABLE public.contract_consumption OWNER TO neondb_owner;

--
-- Name: contract_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contract_id_seq OWNER TO neondb_owner;

--
-- Name: contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.contract_id_seq OWNED BY public.contract.id;


--
-- Name: file; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.file (
    id integer NOT NULL,
    parsed_flag boolean DEFAULT false NOT NULL,
    file_path text NOT NULL
);


ALTER TABLE public.file OWNER TO neondb_owner;

--
-- Name: file_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.file_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.file_id_seq OWNER TO neondb_owner;

--
-- Name: file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.file_id_seq OWNED BY public.file.id;


--
-- Name: invoice; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.invoice (
    id integer NOT NULL,
    bill_id integer NOT NULL,
    pdf_path text,
    generation_date timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.invoice OWNER TO neondb_owner;

--
-- Name: invoice_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.invoice_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_id_seq OWNER TO neondb_owner;

--
-- Name: invoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.invoice_id_seq OWNED BY public.invoice.id;


--
-- Name: msisdn_pool; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.msisdn_pool (
    id integer NOT NULL,
    msisdn character varying(20) NOT NULL,
    is_available boolean DEFAULT true NOT NULL
);


ALTER TABLE public.msisdn_pool OWNER TO neondb_owner;

--
-- Name: msisdn_pool_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.msisdn_pool_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.msisdn_pool_id_seq OWNER TO neondb_owner;

--
-- Name: msisdn_pool_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.msisdn_pool_id_seq OWNED BY public.msisdn_pool.id;


--
-- Name: rateplan; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.rateplan (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    ror_data numeric(10,2),
    ror_voice numeric(10,2),
    ror_sms numeric(10,2),
    price numeric(10,2)
);


ALTER TABLE public.rateplan OWNER TO neondb_owner;

--
-- Name: rateplan_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.rateplan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rateplan_id_seq OWNER TO neondb_owner;

--
-- Name: rateplan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.rateplan_id_seq OWNED BY public.rateplan.id;


--
-- Name: rateplan_service_package; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.rateplan_service_package (
    rateplan_id integer NOT NULL,
    service_package_id integer NOT NULL
);


ALTER TABLE public.rateplan_service_package OWNER TO neondb_owner;

--
-- Name: ror_contract; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.ror_contract (
    contract_id integer NOT NULL,
    rateplan_id integer NOT NULL,
    data integer,
    voice integer,
    sms integer,
    bill_id integer
);


ALTER TABLE public.ror_contract OWNER TO neondb_owner;

--
-- Name: service_package; Type: TABLE; Schema: public; Owner: neondb_owner
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


ALTER TABLE public.service_package OWNER TO neondb_owner;

--
-- Name: service_package_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.service_package_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_package_id_seq OWNER TO neondb_owner;

--
-- Name: service_package_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.service_package_id_seq OWNED BY public.service_package.id;


--
-- Name: user_account; Type: TABLE; Schema: public; Owner: neondb_owner
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


ALTER TABLE public.user_account OWNER TO neondb_owner;

--
-- Name: user_account_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.user_account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_account_id_seq OWNER TO neondb_owner;

--
-- Name: user_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.user_account_id_seq OWNED BY public.user_account.id;


--
-- Name: bill id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bill ALTER COLUMN id SET DEFAULT nextval('public.bill_id_seq'::regclass);


--
-- Name: cdr id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cdr ALTER COLUMN id SET DEFAULT nextval('public.cdr_id_seq'::regclass);


--
-- Name: contract id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract ALTER COLUMN id SET DEFAULT nextval('public.contract_id_seq'::regclass);


--
-- Name: contract_addon id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_addon ALTER COLUMN id SET DEFAULT nextval('public.contract_addon_id_seq'::regclass);


--
-- Name: file id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.file ALTER COLUMN id SET DEFAULT nextval('public.file_id_seq'::regclass);


--
-- Name: invoice id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.invoice ALTER COLUMN id SET DEFAULT nextval('public.invoice_id_seq'::regclass);


--
-- Name: msisdn_pool id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.msisdn_pool ALTER COLUMN id SET DEFAULT nextval('public.msisdn_pool_id_seq'::regclass);


--
-- Name: rateplan id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.rateplan ALTER COLUMN id SET DEFAULT nextval('public.rateplan_id_seq'::regclass);


--
-- Name: service_package id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.service_package ALTER COLUMN id SET DEFAULT nextval('public.service_package_id_seq'::regclass);


--
-- Name: user_account id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_account ALTER COLUMN id SET DEFAULT nextval('public.user_account_id_seq'::regclass);


--
-- Data for Name: bill; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bill (id, contract_id, billing_period_start, billing_period_end, billing_date, recurring_fees, one_time_fees, voice_usage, data_usage, sms_usage, ror_charge, taxes, total_amount, status, is_paid) FROM stdin;
1	1	2026-03-01	2026-03-31	2026-04-01	50.00	0.00	200	0	20	12.00	5.00	67.00	issued	f
2	2	2026-03-01	2026-03-31	2026-04-01	120.00	0.00	400	1200	60	25.00	10.00	155.00	issued	f
3	1	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	426	0	20	5.25	8.29	64.23	issued	f
4	3	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	0	0	28	0.00	7.50	58.19	issued	f
5	4	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	255	0	0	0.00	18.00	138.69	issued	f
6	6	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	0	0	28	0.00	18.00	138.69	issued	f
7	7	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	365	0	0	0.00	7.50	58.19	issued	f
8	9	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	0	0	28	0.00	7.50	58.19	issued	f
9	10	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	403	0	0	0.00	18.00	138.69	issued	f
10	12	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	0	0	28	0.00	18.00	138.69	issued	f
11	13	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	279	0	0	0.00	7.50	58.19	issued	f
12	15	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	0	0	27	0.00	7.50	58.19	issued	f
13	16	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	212	0	0	0.00	18.00	138.69	issued	f
14	18	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	0	0	27	0.00	18.00	138.69	issued	f
15	19	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	0	0	0	0.00	18.00	138.69	issued	f
16	17	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	0	0	0	2014.00	309.60	2374.29	issued	f
17	2	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	300	6000	40	294.79	62.22	477.70	issued	f
18	5	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	0	0	0	2080.00	319.50	2450.19	issued	f
19	8	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	0	6000	0	727.00	127.05	974.74	issued	f
20	11	2026-04-01	2026-04-30	2026-04-26	50.00	0.69	0	0	0	2051.00	315.15	2416.84	issued	f
21	14	2026-04-01	2026-04-30	2026-04-26	120.00	0.69	0	6000	0	448.50	85.28	654.47	issued	f
\.


--
-- Data for Name: cdr; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cdr (id, file_id, dial_a, dial_b, start_time, duration, service_id, hplmn, vplmn, external_charges, rated_flag) FROM stdin;
1	3	201000000001	201000000100	2026-04-10 10:00:00	180	1			0.00	t
2	3	201000000001	201000000200	2026-04-11 14:00:00	240	1			0.00	t
3	3	201000000001	201000000300	2026-04-13 09:00:00	600	1			0.00	t
4	3	201000000001	201000000400	2026-04-15 17:30:00	120	1			0.00	t
5	3	201000000001	201000000500	2026-04-20 11:00:00	3600	1			0.00	t
6	3	201000000001	201000000100	2026-04-10 10:05:00	1	3			0.00	t
7	3	201000000001	201000000200	2026-04-12 08:00:00	1	3			0.00	t
8	3	201000000001	201000000300	2026-04-14 19:00:00	1	3			0.00	t
9	3	201000000001	201000000400	2026-04-16 12:00:00	1	3			0.00	t
10	3	201000000001	201000000500	2026-04-18 20:00:00	1	3			0.00	t
11	4	201000000001	201000091000	2026-04-26 00:00:00	3600	1	EGY	EGY	0.00	t
12	4	201000000002	youtube.com	2026-04-26 00:02:00	80	2	EGY	EGY	0.00	t
13	4	201000000003	201000082002	2026-04-26 00:04:00	1	3	EGY	EGY	0.00	t
14	4	201000000004	201000091003	2026-04-26 00:06:00	180	1	EGY	SAU	0.00	t
15	4	201000000005	tiktok.com	2026-04-26 00:08:00	120	2	EGY	SAU	0.00	t
16	4	201000000006	201000082005	2026-04-26 00:10:00	1	3	EGY	EGY	0.00	t
17	4	201000000007	201000091006	2026-04-26 00:12:00	90	1	EGY	EGY	0.00	t
18	4	201000000008	netflix.com	2026-04-26 00:14:00	2000	2	EGY	EGY	0.00	t
19	4	201000000009	201000082008	2026-04-26 00:16:00	1	3	EGY	SAU	0.00	t
20	4	201000000010	201000091009	2026-04-26 00:18:00	3600	1	EGY	EGY	0.00	t
21	4	201000000011	facebook.com	2026-04-26 00:20:00	2000	2	EGY	EGY	0.00	t
22	4	201000000012	201000082011	2026-04-26 00:22:00	1	3	EGY	EGY	0.00	t
23	4	201000000013	201000091012	2026-04-26 00:24:00	60	1	EGY	EGY	0.00	t
24	4	201000000014	spotify.com	2026-04-26 00:26:00	1200	2	EGY	SAU	0.00	t
25	4	201000000015	201000082014	2026-04-26 00:28:00	1	3	EGY	SAU	0.00	t
26	4	201000000016	201000091015	2026-04-26 00:30:00	30	1	EGY	EGY	0.00	t
27	4	201000000017	netflix.com	2026-04-26 00:32:00	50	2	EGY	EGY	0.00	t
28	4	201000000018	201000082017	2026-04-26 00:34:00	1	3	EGY	EGY	0.00	t
29	4	201000000001	201000091018	2026-04-26 00:36:00	120	1	EGY	SAU	0.00	t
30	4	201000000002	facebook.com	2026-04-26 00:38:00	120	2	EGY	EGY	0.00	t
31	4	201000000003	201000082020	2026-04-26 00:40:00	1	3	EGY	EGY	0.00	t
32	4	201000000004	201000091021	2026-04-26 00:42:00	1800	1	EGY	EGY	0.00	t
33	4	201000000005	facebook.com	2026-04-26 00:44:00	50	2	EGY	EGY	0.00	t
34	4	201000000006	201000082023	2026-04-26 00:46:00	1	3	EGY	SAU	0.00	t
35	4	201000000007	201000091024	2026-04-26 00:48:00	120	1	EGY	SAU	0.00	t
36	4	201000000008	facebook.com	2026-04-26 00:50:00	2000	2	EGY	EGY	0.00	t
37	4	201000000009	201000082026	2026-04-26 00:52:00	1	3	EGY	EGY	0.00	t
38	4	201000000010	201000091027	2026-04-26 00:54:00	300	1	EGY	EGY	0.00	t
39	4	201000000011	news.com	2026-04-26 00:56:00	120	2	EGY	SAU	0.00	t
40	4	201000000012	201000082029	2026-04-26 00:58:00	1	3	EGY	EGY	0.00	t
41	4	201000000013	201000091030	2026-04-26 01:00:00	1800	1	EGY	EGY	0.00	t
42	4	201000000014	youtube.com	2026-04-26 01:02:00	200	2	EGY	EGY	0.00	t
43	4	201000000015	201000082032	2026-04-26 01:04:00	1	3	EGY	EGY	0.00	t
44	4	201000000016	201000091033	2026-04-26 01:06:00	90	1	EGY	SAU	0.00	t
45	4	201000000017	spotify.com	2026-04-26 01:08:00	2000	2	EGY	SAU	0.00	t
46	4	201000000018	201000082035	2026-04-26 01:10:00	1	3	EGY	EGY	0.00	t
47	4	201000000001	201000091036	2026-04-26 01:12:00	240	1	EGY	EGY	0.00	t
48	4	201000000002	instagram.com	2026-04-26 01:14:00	200	2	EGY	EGY	0.00	t
49	4	201000000003	201000082038	2026-04-26 01:16:00	1	3	EGY	SAU	0.00	t
50	4	201000000004	201000091039	2026-04-26 01:18:00	120	1	EGY	EGY	0.00	t
51	4	201000000005	netflix.com	2026-04-26 01:20:00	300	2	EGY	EGY	0.00	t
52	4	201000000006	201000082041	2026-04-26 01:22:00	1	3	EGY	EGY	0.00	t
53	4	201000000007	201000091042	2026-04-26 01:24:00	60	1	EGY	EGY	0.00	t
54	4	201000000008	netflix.com	2026-04-26 01:26:00	500	2	EGY	SAU	0.00	t
55	4	201000000009	201000082044	2026-04-26 01:28:00	1	3	EGY	SAU	0.00	t
56	4	201000000010	201000091045	2026-04-26 01:30:00	240	1	EGY	EGY	0.00	t
57	4	201000000011	x.com	2026-04-26 01:32:00	300	2	EGY	EGY	0.00	t
58	4	201000000012	201000082047	2026-04-26 01:34:00	1	3	EGY	EGY	0.00	t
59	4	201000000013	201000091048	2026-04-26 01:36:00	180	1	EGY	SAU	0.00	t
60	4	201000000014	news.com	2026-04-26 01:38:00	50	2	EGY	EGY	0.00	t
61	4	201000000015	201000082050	2026-04-26 01:40:00	1	3	EGY	EGY	0.00	t
62	4	201000000016	201000091051	2026-04-26 01:42:00	900	1	EGY	EGY	0.00	t
63	4	201000000017	spotify.com	2026-04-26 01:44:00	80	2	EGY	EGY	0.00	t
64	4	201000000018	201000082053	2026-04-26 01:46:00	1	3	EGY	SAU	0.00	t
65	4	201000000001	201000091054	2026-04-26 01:48:00	60	1	EGY	SAU	0.00	t
66	4	201000000002	google.com	2026-04-26 01:50:00	1000	2	EGY	EGY	0.00	t
67	4	201000000003	201000082056	2026-04-26 01:52:00	1	3	EGY	EGY	0.00	t
68	4	201000000004	201000091057	2026-04-26 01:54:00	3600	1	EGY	EGY	0.00	t
69	4	201000000005	api.whatsapp.com	2026-04-26 01:56:00	1200	2	EGY	SAU	0.00	t
70	4	201000000006	201000082059	2026-04-26 01:58:00	1	3	EGY	EGY	0.00	t
71	4	201000000007	201000091060	2026-04-26 02:00:00	1800	1	EGY	EGY	0.00	t
72	4	201000000008	netflix.com	2026-04-26 02:02:00	120	2	EGY	EGY	0.00	t
73	4	201000000009	201000082062	2026-04-26 02:04:00	1	3	EGY	EGY	0.00	t
74	4	201000000010	201000091063	2026-04-26 02:06:00	30	1	EGY	SAU	0.00	t
75	4	201000000011	tiktok.com	2026-04-26 02:08:00	1500	2	EGY	SAU	0.00	t
76	4	201000000012	201000082065	2026-04-26 02:10:00	1	3	EGY	EGY	0.00	t
77	4	201000000013	201000091066	2026-04-26 02:12:00	180	1	EGY	EGY	0.00	t
78	4	201000000014	tiktok.com	2026-04-26 02:14:00	80	2	EGY	EGY	0.00	t
79	4	201000000015	201000082068	2026-04-26 02:16:00	1	3	EGY	SAU	0.00	t
80	4	201000000016	201000091069	2026-04-26 02:18:00	60	1	EGY	EGY	0.00	t
81	4	201000000017	google.com	2026-04-26 02:20:00	500	2	EGY	EGY	0.00	t
82	4	201000000018	201000082071	2026-04-26 02:22:00	1	3	EGY	EGY	0.00	t
83	4	201000000001	201000091072	2026-04-26 02:24:00	600	1	EGY	EGY	0.00	t
84	4	201000000002	api.whatsapp.com	2026-04-26 02:26:00	1500	2	EGY	SAU	0.00	t
85	4	201000000003	201000082074	2026-04-26 02:28:00	1	3	EGY	SAU	0.00	t
86	4	201000000004	201000091075	2026-04-26 02:30:00	90	1	EGY	EGY	0.00	t
87	4	201000000005	api.whatsapp.com	2026-04-26 02:32:00	300	2	EGY	EGY	0.00	t
88	4	201000000006	201000082077	2026-04-26 02:34:00	1	3	EGY	EGY	0.00	t
89	4	201000000007	201000091078	2026-04-26 02:36:00	120	1	EGY	SAU	0.00	t
90	4	201000000008	google.com	2026-04-26 02:38:00	1500	2	EGY	EGY	0.00	t
91	4	201000000009	201000082080	2026-04-26 02:40:00	1	3	EGY	EGY	0.00	t
92	4	201000000010	201000091081	2026-04-26 02:42:00	3600	1	EGY	EGY	0.00	t
93	4	201000000011	netflix.com	2026-04-26 02:44:00	1500	2	EGY	EGY	0.00	t
94	4	201000000012	201000082083	2026-04-26 02:46:00	1	3	EGY	SAU	0.00	t
95	4	201000000013	201000091084	2026-04-26 02:48:00	1800	1	EGY	SAU	0.00	t
96	4	201000000014	instagram.com	2026-04-26 02:50:00	1500	2	EGY	EGY	0.00	t
97	4	201000000015	201000082086	2026-04-26 02:52:00	1	3	EGY	EGY	0.00	t
98	4	201000000016	201000091087	2026-04-26 02:54:00	900	1	EGY	EGY	0.00	t
99	4	201000000017	tiktok.com	2026-04-26 02:56:00	2000	2	EGY	SAU	0.00	t
100	4	201000000018	201000082089	2026-04-26 02:58:00	1	3	EGY	EGY	0.00	t
101	4	201000000001	201000091090	2026-04-26 03:00:00	90	1	EGY	EGY	0.00	t
102	4	201000000002	spotify.com	2026-04-26 03:02:00	800	2	EGY	EGY	0.00	t
103	4	201000000003	201000082092	2026-04-26 03:04:00	1	3	EGY	EGY	0.00	t
104	4	201000000004	201000091093	2026-04-26 03:06:00	180	1	EGY	SAU	0.00	t
105	4	201000000005	facebook.com	2026-04-26 03:08:00	1500	2	EGY	SAU	0.00	t
106	4	201000000006	201000082095	2026-04-26 03:10:00	1	3	EGY	EGY	0.00	t
107	4	201000000007	201000091096	2026-04-26 03:12:00	120	1	EGY	EGY	0.00	t
108	4	201000000008	api.whatsapp.com	2026-04-26 03:14:00	1500	2	EGY	EGY	0.00	t
109	4	201000000009	201000082098	2026-04-26 03:16:00	1	3	EGY	SAU	0.00	t
110	4	201000000010	201000091099	2026-04-26 03:18:00	30	1	EGY	EGY	0.00	t
111	4	201000000011	youtube.com	2026-04-26 03:20:00	120	2	EGY	EGY	0.00	t
112	4	201000000012	201000082101	2026-04-26 03:22:00	1	3	EGY	EGY	0.00	t
113	4	201000000013	201000091102	2026-04-26 03:24:00	240	1	EGY	EGY	0.00	t
114	4	201000000014	google.com	2026-04-26 03:26:00	500	2	EGY	SAU	0.00	t
115	4	201000000015	201000082104	2026-04-26 03:28:00	1	3	EGY	SAU	0.00	t
116	4	201000000016	201000091105	2026-04-26 03:30:00	60	1	EGY	EGY	0.00	t
117	4	201000000017	x.com	2026-04-26 03:32:00	120	2	EGY	EGY	0.00	t
118	4	201000000018	201000082107	2026-04-26 03:34:00	1	3	EGY	EGY	0.00	t
119	4	201000000001	201000091108	2026-04-26 03:36:00	240	1	EGY	SAU	0.00	t
120	4	201000000002	news.com	2026-04-26 03:38:00	120	2	EGY	EGY	0.00	t
121	4	201000000003	201000082110	2026-04-26 03:40:00	1	3	EGY	EGY	0.00	t
122	4	201000000004	201000091111	2026-04-26 03:42:00	300	1	EGY	EGY	0.00	t
123	4	201000000005	news.com	2026-04-26 03:44:00	1500	2	EGY	EGY	0.00	t
124	4	201000000006	201000082113	2026-04-26 03:46:00	1	3	EGY	SAU	0.00	t
125	4	201000000007	201000091114	2026-04-26 03:48:00	90	1	EGY	SAU	0.00	t
126	4	201000000008	instagram.com	2026-04-26 03:50:00	200	2	EGY	EGY	0.00	t
127	4	201000000009	201000082116	2026-04-26 03:52:00	1	3	EGY	EGY	0.00	t
128	4	201000000010	201000091117	2026-04-26 03:54:00	120	1	EGY	EGY	0.00	t
129	4	201000000011	facebook.com	2026-04-26 03:56:00	2000	2	EGY	SAU	0.00	t
130	4	201000000012	201000082119	2026-04-26 03:58:00	1	3	EGY	EGY	0.00	t
131	4	201000000013	201000091120	2026-04-26 04:00:00	900	1	EGY	EGY	0.00	t
132	4	201000000014	x.com	2026-04-26 04:02:00	200	2	EGY	EGY	0.00	t
133	4	201000000015	201000082122	2026-04-26 04:04:00	1	3	EGY	EGY	0.00	t
134	4	201000000016	201000091123	2026-04-26 04:06:00	300	1	EGY	SAU	0.00	t
135	4	201000000017	spotify.com	2026-04-26 04:08:00	1200	2	EGY	SAU	0.00	t
136	4	201000000018	201000082125	2026-04-26 04:10:00	1	3	EGY	EGY	0.00	t
137	4	201000000001	201000091126	2026-04-26 04:12:00	240	1	EGY	EGY	0.00	t
138	4	201000000002	instagram.com	2026-04-26 04:14:00	120	2	EGY	EGY	0.00	t
139	4	201000000003	201000082128	2026-04-26 04:16:00	1	3	EGY	SAU	0.00	t
140	4	201000000004	201000091129	2026-04-26 04:18:00	900	1	EGY	EGY	0.00	t
141	4	201000000005	netflix.com	2026-04-26 04:20:00	800	2	EGY	EGY	0.00	t
142	4	201000000006	201000082131	2026-04-26 04:22:00	1	3	EGY	EGY	0.00	t
143	4	201000000007	201000091132	2026-04-26 04:24:00	30	1	EGY	EGY	0.00	t
144	4	201000000008	instagram.com	2026-04-26 04:26:00	80	2	EGY	SAU	0.00	t
145	4	201000000009	201000082134	2026-04-26 04:28:00	1	3	EGY	SAU	0.00	t
146	4	201000000010	201000091135	2026-04-26 04:30:00	3600	1	EGY	EGY	0.00	t
147	4	201000000011	spotify.com	2026-04-26 04:32:00	100	2	EGY	EGY	0.00	t
148	4	201000000012	201000082137	2026-04-26 04:34:00	1	3	EGY	EGY	0.00	t
149	4	201000000013	201000091138	2026-04-26 04:36:00	1800	1	EGY	SAU	0.00	t
150	4	201000000014	spotify.com	2026-04-26 04:38:00	80	2	EGY	EGY	0.00	t
151	4	201000000015	201000082140	2026-04-26 04:40:00	1	3	EGY	EGY	0.00	t
152	4	201000000016	201000091141	2026-04-26 04:42:00	300	1	EGY	EGY	0.00	t
153	4	201000000017	news.com	2026-04-26 04:44:00	1200	2	EGY	EGY	0.00	t
154	4	201000000018	201000082143	2026-04-26 04:46:00	1	3	EGY	SAU	0.00	t
155	4	201000000001	201000091144	2026-04-26 04:48:00	900	1	EGY	SAU	0.00	t
156	4	201000000002	facebook.com	2026-04-26 04:50:00	200	2	EGY	EGY	0.00	t
157	4	201000000003	201000082146	2026-04-26 04:52:00	1	3	EGY	EGY	0.00	t
158	4	201000000004	201000091147	2026-04-26 04:54:00	30	1	EGY	EGY	0.00	t
159	4	201000000005	netflix.com	2026-04-26 04:56:00	1500	2	EGY	SAU	0.00	t
160	4	201000000006	201000082149	2026-04-26 04:58:00	1	3	EGY	EGY	0.00	t
161	4	201000000007	201000091150	2026-04-26 05:00:00	3600	1	EGY	EGY	0.00	t
162	4	201000000008	google.com	2026-04-26 05:02:00	1000	2	EGY	EGY	0.00	t
163	4	201000000009	201000082152	2026-04-26 05:04:00	1	3	EGY	EGY	0.00	t
164	4	201000000010	201000091153	2026-04-26 05:06:00	3600	1	EGY	SAU	0.00	t
165	4	201000000011	netflix.com	2026-04-26 05:08:00	300	2	EGY	SAU	0.00	t
166	4	201000000012	201000082155	2026-04-26 05:10:00	1	3	EGY	EGY	0.00	t
167	4	201000000013	201000091156	2026-04-26 05:12:00	180	1	EGY	EGY	0.00	t
168	4	201000000014	instagram.com	2026-04-26 05:14:00	500	2	EGY	EGY	0.00	t
169	4	201000000015	201000082158	2026-04-26 05:16:00	1	3	EGY	SAU	0.00	t
170	4	201000000016	201000091159	2026-04-26 05:18:00	600	1	EGY	EGY	0.00	t
171	4	201000000017	google.com	2026-04-26 05:20:00	50	2	EGY	EGY	0.00	t
172	4	201000000018	201000082161	2026-04-26 05:22:00	1	3	EGY	EGY	0.00	t
173	4	201000000001	201000091162	2026-04-26 05:24:00	900	1	EGY	EGY	0.00	t
174	4	201000000002	facebook.com	2026-04-26 05:26:00	100	2	EGY	SAU	0.00	t
175	4	201000000003	201000082164	2026-04-26 05:28:00	1	3	EGY	SAU	0.00	t
176	4	201000000004	201000091165	2026-04-26 05:30:00	60	1	EGY	EGY	0.00	t
177	4	201000000005	google.com	2026-04-26 05:32:00	1500	2	EGY	EGY	0.00	t
178	4	201000000006	201000082167	2026-04-26 05:34:00	1	3	EGY	EGY	0.00	t
179	4	201000000007	201000091168	2026-04-26 05:36:00	3600	1	EGY	SAU	0.00	t
180	4	201000000008	x.com	2026-04-26 05:38:00	1000	2	EGY	EGY	0.00	t
181	4	201000000009	201000082170	2026-04-26 05:40:00	1	3	EGY	EGY	0.00	t
182	4	201000000010	201000091171	2026-04-26 05:42:00	120	1	EGY	EGY	0.00	t
183	4	201000000011	api.whatsapp.com	2026-04-26 05:44:00	100	2	EGY	EGY	0.00	t
184	4	201000000012	201000082173	2026-04-26 05:46:00	1	3	EGY	SAU	0.00	t
185	4	201000000013	201000091174	2026-04-26 05:48:00	90	1	EGY	SAU	0.00	t
186	4	201000000014	facebook.com	2026-04-26 05:50:00	1000	2	EGY	EGY	0.00	t
187	4	201000000015	201000082176	2026-04-26 05:52:00	1	3	EGY	EGY	0.00	t
188	4	201000000016	201000091177	2026-04-26 05:54:00	30	1	EGY	EGY	0.00	t
189	4	201000000017	api.whatsapp.com	2026-04-26 05:56:00	1200	2	EGY	SAU	0.00	t
190	4	201000000018	201000082179	2026-04-26 05:58:00	1	3	EGY	EGY	0.00	t
191	4	201000000001	201000091180	2026-04-26 06:00:00	600	1	EGY	EGY	0.00	t
192	4	201000000002	netflix.com	2026-04-26 06:02:00	50	2	EGY	EGY	0.00	t
193	4	201000000003	201000082182	2026-04-26 06:04:00	1	3	EGY	EGY	0.00	t
194	4	201000000004	201000091183	2026-04-26 06:06:00	240	1	EGY	SAU	0.00	t
195	4	201000000005	tiktok.com	2026-04-26 06:08:00	200	2	EGY	SAU	0.00	t
196	4	201000000006	201000082185	2026-04-26 06:10:00	1	3	EGY	EGY	0.00	t
197	4	201000000007	201000091186	2026-04-26 06:12:00	30	1	EGY	EGY	0.00	t
198	4	201000000008	x.com	2026-04-26 06:14:00	120	2	EGY	EGY	0.00	t
199	4	201000000009	201000082188	2026-04-26 06:16:00	1	3	EGY	SAU	0.00	t
200	4	201000000010	201000091189	2026-04-26 06:18:00	60	1	EGY	EGY	0.00	t
201	4	201000000011	news.com	2026-04-26 06:20:00	80	2	EGY	EGY	0.00	t
202	4	201000000012	201000082191	2026-04-26 06:22:00	1	3	EGY	EGY	0.00	t
203	4	201000000013	201000091192	2026-04-26 06:24:00	60	1	EGY	EGY	0.00	t
204	4	201000000014	instagram.com	2026-04-26 06:26:00	1000	2	EGY	SAU	0.00	t
205	4	201000000015	201000082194	2026-04-26 06:28:00	1	3	EGY	SAU	0.00	t
206	4	201000000016	201000091195	2026-04-26 06:30:00	90	1	EGY	EGY	0.00	t
207	4	201000000017	news.com	2026-04-26 06:32:00	1500	2	EGY	EGY	0.00	t
208	4	201000000018	201000082197	2026-04-26 06:34:00	1	3	EGY	EGY	0.00	t
209	4	201000000001	201000091198	2026-04-26 06:36:00	900	1	EGY	SAU	0.00	t
210	4	201000000002	google.com	2026-04-26 06:38:00	100	2	EGY	EGY	0.00	t
211	4	201000000003	201000082200	2026-04-26 06:40:00	1	3	EGY	EGY	0.00	t
212	4	201000000004	201000091201	2026-04-26 06:42:00	900	1	EGY	EGY	0.00	t
213	4	201000000005	spotify.com	2026-04-26 06:44:00	1200	2	EGY	EGY	0.00	t
214	4	201000000006	201000082203	2026-04-26 06:46:00	1	3	EGY	SAU	0.00	t
215	4	201000000007	201000091204	2026-04-26 06:48:00	120	1	EGY	SAU	0.00	t
216	4	201000000008	tiktok.com	2026-04-26 06:50:00	1000	2	EGY	EGY	0.00	t
217	4	201000000009	201000082206	2026-04-26 06:52:00	1	3	EGY	EGY	0.00	t
218	4	201000000010	201000091207	2026-04-26 06:54:00	180	1	EGY	EGY	0.00	t
219	4	201000000011	api.whatsapp.com	2026-04-26 06:56:00	500	2	EGY	SAU	0.00	t
220	4	201000000012	201000082209	2026-04-26 06:58:00	1	3	EGY	EGY	0.00	t
221	4	201000000013	201000091210	2026-04-26 07:00:00	600	1	EGY	EGY	0.00	t
222	4	201000000014	news.com	2026-04-26 07:02:00	1000	2	EGY	EGY	0.00	t
223	4	201000000015	201000082212	2026-04-26 07:04:00	1	3	EGY	EGY	0.00	t
224	4	201000000016	201000091213	2026-04-26 07:06:00	60	1	EGY	SAU	0.00	t
225	4	201000000017	tiktok.com	2026-04-26 07:08:00	120	2	EGY	SAU	0.00	t
226	4	201000000018	201000082215	2026-04-26 07:10:00	1	3	EGY	EGY	0.00	t
227	4	201000000001	201000091216	2026-04-26 07:12:00	60	1	EGY	EGY	0.00	t
228	4	201000000002	youtube.com	2026-04-26 07:14:00	300	2	EGY	EGY	0.00	t
229	4	201000000003	201000082218	2026-04-26 07:16:00	1	3	EGY	SAU	0.00	t
230	4	201000000004	201000091219	2026-04-26 07:18:00	1800	1	EGY	EGY	0.00	t
231	4	201000000005	tiktok.com	2026-04-26 07:20:00	1000	2	EGY	EGY	0.00	t
232	4	201000000006	201000082221	2026-04-26 07:22:00	1	3	EGY	EGY	0.00	t
233	4	201000000007	201000091222	2026-04-26 07:24:00	1800	1	EGY	EGY	0.00	t
234	4	201000000008	youtube.com	2026-04-26 07:26:00	120	2	EGY	SAU	0.00	t
235	4	201000000009	201000082224	2026-04-26 07:28:00	1	3	EGY	SAU	0.00	t
236	4	201000000010	201000091225	2026-04-26 07:30:00	60	1	EGY	EGY	0.00	t
237	4	201000000011	youtube.com	2026-04-26 07:32:00	2000	2	EGY	EGY	0.00	t
238	4	201000000012	201000082227	2026-04-26 07:34:00	1	3	EGY	EGY	0.00	t
239	4	201000000013	201000091228	2026-04-26 07:36:00	120	1	EGY	SAU	0.00	t
240	4	201000000014	youtube.com	2026-04-26 07:38:00	80	2	EGY	EGY	0.00	t
241	4	201000000015	201000082230	2026-04-26 07:40:00	1	3	EGY	EGY	0.00	t
242	4	201000000016	201000091231	2026-04-26 07:42:00	240	1	EGY	EGY	0.00	t
243	4	201000000017	facebook.com	2026-04-26 07:44:00	80	2	EGY	EGY	0.00	t
244	4	201000000018	201000082233	2026-04-26 07:46:00	1	3	EGY	SAU	0.00	t
245	4	201000000001	201000091234	2026-04-26 07:48:00	120	1	EGY	SAU	0.00	t
246	4	201000000002	news.com	2026-04-26 07:50:00	200	2	EGY	EGY	0.00	t
247	4	201000000003	201000082236	2026-04-26 07:52:00	1	3	EGY	EGY	0.00	t
248	4	201000000004	201000091237	2026-04-26 07:54:00	120	1	EGY	EGY	0.00	t
249	4	201000000005	instagram.com	2026-04-26 07:56:00	1000	2	EGY	SAU	0.00	t
250	4	201000000006	201000082239	2026-04-26 07:58:00	1	3	EGY	EGY	0.00	t
251	4	201000000007	201000091240	2026-04-26 08:00:00	1800	1	EGY	EGY	0.00	t
252	4	201000000008	news.com	2026-04-26 08:02:00	1200	2	EGY	EGY	0.00	t
253	4	201000000009	201000082242	2026-04-26 08:04:00	1	3	EGY	EGY	0.00	t
254	4	201000000010	201000091243	2026-04-26 08:06:00	120	1	EGY	SAU	0.00	t
255	4	201000000011	spotify.com	2026-04-26 08:08:00	800	2	EGY	SAU	0.00	t
256	4	201000000012	201000082245	2026-04-26 08:10:00	1	3	EGY	EGY	0.00	t
257	4	201000000013	201000091246	2026-04-26 08:12:00	120	1	EGY	EGY	0.00	t
258	4	201000000014	netflix.com	2026-04-26 08:14:00	80	2	EGY	EGY	0.00	t
259	4	201000000015	201000082248	2026-04-26 08:16:00	1	3	EGY	SAU	0.00	t
260	4	201000000016	201000091249	2026-04-26 08:18:00	3600	1	EGY	EGY	0.00	t
261	4	201000000017	api.whatsapp.com	2026-04-26 08:20:00	500	2	EGY	EGY	0.00	t
262	4	201000000018	201000082251	2026-04-26 08:22:00	1	3	EGY	EGY	0.00	t
263	4	201000000001	201000091252	2026-04-26 08:24:00	300	1	EGY	EGY	0.00	t
264	4	201000000002	news.com	2026-04-26 08:26:00	500	2	EGY	SAU	0.00	t
265	4	201000000003	201000082254	2026-04-26 08:28:00	1	3	EGY	SAU	0.00	t
266	4	201000000004	201000091255	2026-04-26 08:30:00	30	1	EGY	EGY	0.00	t
267	4	201000000005	netflix.com	2026-04-26 08:32:00	1500	2	EGY	EGY	0.00	t
268	4	201000000006	201000082257	2026-04-26 08:34:00	1	3	EGY	EGY	0.00	t
269	4	201000000007	201000091258	2026-04-26 08:36:00	30	1	EGY	SAU	0.00	t
270	4	201000000008	api.whatsapp.com	2026-04-26 08:38:00	500	2	EGY	EGY	0.00	t
271	4	201000000009	201000082260	2026-04-26 08:40:00	1	3	EGY	EGY	0.00	t
272	4	201000000010	201000091261	2026-04-26 08:42:00	60	1	EGY	EGY	0.00	t
273	4	201000000011	tiktok.com	2026-04-26 08:44:00	120	2	EGY	EGY	0.00	t
274	4	201000000012	201000082263	2026-04-26 08:46:00	1	3	EGY	SAU	0.00	t
275	4	201000000013	201000091264	2026-04-26 08:48:00	120	1	EGY	SAU	0.00	t
276	4	201000000014	news.com	2026-04-26 08:50:00	1000	2	EGY	EGY	0.00	t
277	4	201000000015	201000082266	2026-04-26 08:52:00	1	3	EGY	EGY	0.00	t
278	4	201000000016	201000091267	2026-04-26 08:54:00	90	1	EGY	EGY	0.00	t
279	4	201000000017	instagram.com	2026-04-26 08:56:00	500	2	EGY	SAU	0.00	t
280	4	201000000018	201000082269	2026-04-26 08:58:00	1	3	EGY	EGY	0.00	t
281	4	201000000001	201000091270	2026-04-26 09:00:00	180	1	EGY	EGY	0.00	t
282	4	201000000002	tiktok.com	2026-04-26 09:02:00	800	2	EGY	EGY	0.00	t
283	4	201000000003	201000082272	2026-04-26 09:04:00	1	3	EGY	EGY	0.00	t
284	4	201000000004	201000091273	2026-04-26 09:06:00	60	1	EGY	SAU	0.00	t
285	4	201000000005	facebook.com	2026-04-26 09:08:00	800	2	EGY	SAU	0.00	t
286	4	201000000006	201000082275	2026-04-26 09:10:00	1	3	EGY	EGY	0.00	t
287	4	201000000007	201000091276	2026-04-26 09:12:00	60	1	EGY	EGY	0.00	t
288	4	201000000008	facebook.com	2026-04-26 09:14:00	50	2	EGY	EGY	0.00	t
289	4	201000000009	201000082278	2026-04-26 09:16:00	1	3	EGY	SAU	0.00	t
290	4	201000000010	201000091279	2026-04-26 09:18:00	30	1	EGY	EGY	0.00	t
291	4	201000000011	tiktok.com	2026-04-26 09:20:00	80	2	EGY	EGY	0.00	t
292	4	201000000012	201000082281	2026-04-26 09:22:00	1	3	EGY	EGY	0.00	t
293	4	201000000013	201000091282	2026-04-26 09:24:00	90	1	EGY	EGY	0.00	t
294	4	201000000014	news.com	2026-04-26 09:26:00	500	2	EGY	SAU	0.00	t
295	4	201000000015	201000082284	2026-04-26 09:28:00	1	3	EGY	SAU	0.00	t
296	4	201000000016	201000091285	2026-04-26 09:30:00	600	1	EGY	EGY	0.00	t
297	4	201000000017	spotify.com	2026-04-26 09:32:00	120	2	EGY	EGY	0.00	t
298	4	201000000018	201000082287	2026-04-26 09:34:00	1	3	EGY	EGY	0.00	t
299	4	201000000001	201000091288	2026-04-26 09:36:00	30	1	EGY	SAU	0.00	t
300	4	201000000002	spotify.com	2026-04-26 09:38:00	100	2	EGY	EGY	0.00	t
301	4	201000000003	201000082290	2026-04-26 09:40:00	1	3	EGY	EGY	0.00	t
302	4	201000000004	201000091291	2026-04-26 09:42:00	30	1	EGY	EGY	0.00	t
303	4	201000000005	google.com	2026-04-26 09:44:00	500	2	EGY	EGY	0.00	t
304	4	201000000006	201000082293	2026-04-26 09:46:00	1	3	EGY	SAU	0.00	t
305	4	201000000007	201000091294	2026-04-26 09:48:00	600	1	EGY	SAU	0.00	t
306	4	201000000008	spotify.com	2026-04-26 09:50:00	200	2	EGY	EGY	0.00	t
307	4	201000000009	201000082296	2026-04-26 09:52:00	1	3	EGY	EGY	0.00	t
308	4	201000000010	201000091297	2026-04-26 09:54:00	900	1	EGY	EGY	0.00	t
309	4	201000000011	news.com	2026-04-26 09:56:00	1500	2	EGY	SAU	0.00	t
310	4	201000000012	201000082299	2026-04-26 09:58:00	1	3	EGY	EGY	0.00	t
311	4	201000000013	201000091300	2026-04-26 10:00:00	90	1	EGY	EGY	0.00	t
312	4	201000000014	google.com	2026-04-26 10:02:00	120	2	EGY	EGY	0.00	t
313	4	201000000015	201000082302	2026-04-26 10:04:00	1	3	EGY	EGY	0.00	t
314	4	201000000016	201000091303	2026-04-26 10:06:00	120	1	EGY	SAU	0.00	t
315	4	201000000017	x.com	2026-04-26 10:08:00	50	2	EGY	SAU	0.00	t
316	4	201000000018	201000082305	2026-04-26 10:10:00	1	3	EGY	EGY	0.00	t
317	4	201000000001	201000091306	2026-04-26 10:12:00	900	1	EGY	EGY	0.00	t
318	4	201000000002	api.whatsapp.com	2026-04-26 10:14:00	50	2	EGY	EGY	0.00	t
319	4	201000000003	201000082308	2026-04-26 10:16:00	1	3	EGY	SAU	0.00	t
320	4	201000000004	201000091309	2026-04-26 10:18:00	30	1	EGY	EGY	0.00	t
321	4	201000000005	x.com	2026-04-26 10:20:00	50	2	EGY	EGY	0.00	t
322	4	201000000006	201000082311	2026-04-26 10:22:00	1	3	EGY	EGY	0.00	t
323	4	201000000007	201000091312	2026-04-26 10:24:00	600	1	EGY	EGY	0.00	t
324	4	201000000008	facebook.com	2026-04-26 10:26:00	1000	2	EGY	SAU	0.00	t
325	4	201000000009	201000082314	2026-04-26 10:28:00	1	3	EGY	SAU	0.00	t
326	4	201000000010	201000091315	2026-04-26 10:30:00	90	1	EGY	EGY	0.00	t
327	4	201000000011	facebook.com	2026-04-26 10:32:00	50	2	EGY	EGY	0.00	t
328	4	201000000012	201000082317	2026-04-26 10:34:00	1	3	EGY	EGY	0.00	t
329	4	201000000013	201000091318	2026-04-26 10:36:00	60	1	EGY	SAU	0.00	t
330	4	201000000014	netflix.com	2026-04-26 10:38:00	100	2	EGY	EGY	0.00	t
331	4	201000000015	201000082320	2026-04-26 10:40:00	1	3	EGY	EGY	0.00	t
332	4	201000000016	201000091321	2026-04-26 10:42:00	1800	1	EGY	EGY	0.00	t
333	4	201000000017	tiktok.com	2026-04-26 10:44:00	80	2	EGY	EGY	0.00	t
334	4	201000000018	201000082323	2026-04-26 10:46:00	1	3	EGY	SAU	0.00	t
335	4	201000000001	201000091324	2026-04-26 10:48:00	300	1	EGY	SAU	0.00	t
336	4	201000000002	x.com	2026-04-26 10:50:00	80	2	EGY	EGY	0.00	t
337	4	201000000003	201000082326	2026-04-26 10:52:00	1	3	EGY	EGY	0.00	t
338	4	201000000004	201000091327	2026-04-26 10:54:00	120	1	EGY	EGY	0.00	t
339	4	201000000005	x.com	2026-04-26 10:56:00	1200	2	EGY	SAU	0.00	t
340	4	201000000006	201000082329	2026-04-26 10:58:00	1	3	EGY	EGY	0.00	t
341	4	201000000007	201000091330	2026-04-26 11:00:00	30	1	EGY	EGY	0.00	t
342	4	201000000008	netflix.com	2026-04-26 11:02:00	1200	2	EGY	EGY	0.00	t
343	4	201000000009	201000082332	2026-04-26 11:04:00	1	3	EGY	EGY	0.00	t
344	4	201000000010	201000091333	2026-04-26 11:06:00	300	1	EGY	SAU	0.00	t
345	4	201000000011	x.com	2026-04-26 11:08:00	1500	2	EGY	SAU	0.00	t
346	4	201000000012	201000082335	2026-04-26 11:10:00	1	3	EGY	EGY	0.00	t
347	4	201000000013	201000091336	2026-04-26 11:12:00	1800	1	EGY	EGY	0.00	t
348	4	201000000014	api.whatsapp.com	2026-04-26 11:14:00	1000	2	EGY	EGY	0.00	t
349	4	201000000015	201000082338	2026-04-26 11:16:00	1	3	EGY	SAU	0.00	t
350	4	201000000016	201000091339	2026-04-26 11:18:00	180	1	EGY	EGY	0.00	t
351	4	201000000017	api.whatsapp.com	2026-04-26 11:20:00	120	2	EGY	EGY	0.00	t
352	4	201000000018	201000082341	2026-04-26 11:22:00	1	3	EGY	EGY	0.00	t
353	4	201000000001	201000091342	2026-04-26 11:24:00	120	1	EGY	EGY	0.00	t
354	4	201000000002	spotify.com	2026-04-26 11:26:00	200	2	EGY	SAU	0.00	t
355	4	201000000003	201000082344	2026-04-26 11:28:00	1	3	EGY	SAU	0.00	t
356	4	201000000004	201000091345	2026-04-26 11:30:00	90	1	EGY	EGY	0.00	t
357	4	201000000005	google.com	2026-04-26 11:32:00	1500	2	EGY	EGY	0.00	t
358	4	201000000006	201000082347	2026-04-26 11:34:00	1	3	EGY	EGY	0.00	t
359	4	201000000007	201000091348	2026-04-26 11:36:00	600	1	EGY	SAU	0.00	t
360	4	201000000008	netflix.com	2026-04-26 11:38:00	300	2	EGY	EGY	0.00	t
361	4	201000000009	201000082350	2026-04-26 11:40:00	1	3	EGY	EGY	0.00	t
362	4	201000000010	201000091351	2026-04-26 11:42:00	30	1	EGY	EGY	0.00	t
363	4	201000000011	x.com	2026-04-26 11:44:00	800	2	EGY	EGY	0.00	t
364	4	201000000012	201000082353	2026-04-26 11:46:00	1	3	EGY	SAU	0.00	t
365	4	201000000013	201000091354	2026-04-26 11:48:00	1800	1	EGY	SAU	0.00	t
366	4	201000000014	netflix.com	2026-04-26 11:50:00	80	2	EGY	EGY	0.00	t
367	4	201000000015	201000082356	2026-04-26 11:52:00	1	3	EGY	EGY	0.00	t
368	4	201000000016	201000091357	2026-04-26 11:54:00	900	1	EGY	EGY	0.00	t
369	4	201000000017	facebook.com	2026-04-26 11:56:00	120	2	EGY	SAU	0.00	t
370	4	201000000018	201000082359	2026-04-26 11:58:00	1	3	EGY	EGY	0.00	t
371	4	201000000001	201000091360	2026-04-26 12:00:00	180	1	EGY	EGY	0.00	t
372	4	201000000002	api.whatsapp.com	2026-04-26 12:02:00	100	2	EGY	EGY	0.00	t
373	4	201000000003	201000082362	2026-04-26 12:04:00	1	3	EGY	EGY	0.00	t
374	4	201000000004	201000091363	2026-04-26 12:06:00	60	1	EGY	SAU	0.00	t
375	4	201000000005	api.whatsapp.com	2026-04-26 12:08:00	120	2	EGY	SAU	0.00	t
376	4	201000000006	201000082365	2026-04-26 12:10:00	1	3	EGY	EGY	0.00	t
377	4	201000000007	201000091366	2026-04-26 12:12:00	180	1	EGY	EGY	0.00	t
378	4	201000000008	news.com	2026-04-26 12:14:00	100	2	EGY	EGY	0.00	t
379	4	201000000009	201000082368	2026-04-26 12:16:00	1	3	EGY	SAU	0.00	t
380	4	201000000010	201000091369	2026-04-26 12:18:00	900	1	EGY	EGY	0.00	t
381	4	201000000011	google.com	2026-04-26 12:20:00	2000	2	EGY	EGY	0.00	t
382	4	201000000012	201000082371	2026-04-26 12:22:00	1	3	EGY	EGY	0.00	t
383	4	201000000013	201000091372	2026-04-26 12:24:00	1800	1	EGY	EGY	0.00	t
384	4	201000000014	facebook.com	2026-04-26 12:26:00	1500	2	EGY	SAU	0.00	t
385	4	201000000015	201000082374	2026-04-26 12:28:00	1	3	EGY	SAU	0.00	t
386	4	201000000016	201000091375	2026-04-26 12:30:00	30	1	EGY	EGY	0.00	t
387	4	201000000017	facebook.com	2026-04-26 12:32:00	1500	2	EGY	EGY	0.00	t
388	4	201000000018	201000082377	2026-04-26 12:34:00	1	3	EGY	EGY	0.00	t
389	4	201000000001	201000091378	2026-04-26 12:36:00	180	1	EGY	SAU	0.00	t
390	4	201000000002	netflix.com	2026-04-26 12:38:00	1500	2	EGY	EGY	0.00	t
391	4	201000000003	201000082380	2026-04-26 12:40:00	1	3	EGY	EGY	0.00	t
392	4	201000000004	201000091381	2026-04-26 12:42:00	90	1	EGY	EGY	0.00	t
393	4	201000000005	netflix.com	2026-04-26 12:44:00	200	2	EGY	EGY	0.00	t
394	4	201000000006	201000082383	2026-04-26 12:46:00	1	3	EGY	SAU	0.00	t
395	4	201000000007	201000091384	2026-04-26 12:48:00	60	1	EGY	SAU	0.00	t
396	4	201000000008	facebook.com	2026-04-26 12:50:00	2000	2	EGY	EGY	0.00	t
397	4	201000000009	201000082386	2026-04-26 12:52:00	1	3	EGY	EGY	0.00	t
398	4	201000000010	201000091387	2026-04-26 12:54:00	90	1	EGY	EGY	0.00	t
399	4	201000000011	google.com	2026-04-26 12:56:00	200	2	EGY	SAU	0.00	t
400	4	201000000012	201000082389	2026-04-26 12:58:00	1	3	EGY	EGY	0.00	t
401	4	201000000013	201000091390	2026-04-26 13:00:00	1800	1	EGY	EGY	0.00	t
402	4	201000000014	api.whatsapp.com	2026-04-26 13:02:00	120	2	EGY	EGY	0.00	t
403	4	201000000015	201000082392	2026-04-26 13:04:00	1	3	EGY	EGY	0.00	t
404	4	201000000016	201000091393	2026-04-26 13:06:00	120	1	EGY	SAU	0.00	t
405	4	201000000017	google.com	2026-04-26 13:08:00	1500	2	EGY	SAU	0.00	t
406	4	201000000018	201000082395	2026-04-26 13:10:00	1	3	EGY	EGY	0.00	t
407	4	201000000001	201000091396	2026-04-26 13:12:00	900	1	EGY	EGY	0.00	t
408	4	201000000002	google.com	2026-04-26 13:14:00	800	2	EGY	EGY	0.00	t
409	4	201000000003	201000082398	2026-04-26 13:16:00	1	3	EGY	SAU	0.00	t
410	4	201000000004	201000091399	2026-04-26 13:18:00	30	1	EGY	EGY	0.00	t
411	4	201000000005	spotify.com	2026-04-26 13:20:00	80	2	EGY	EGY	0.00	t
412	4	201000000006	201000082401	2026-04-26 13:22:00	1	3	EGY	EGY	0.00	t
413	4	201000000007	201000091402	2026-04-26 13:24:00	180	1	EGY	EGY	0.00	t
414	4	201000000008	youtube.com	2026-04-26 13:26:00	50	2	EGY	SAU	0.00	t
415	4	201000000009	201000082404	2026-04-26 13:28:00	1	3	EGY	SAU	0.00	t
416	4	201000000010	201000091405	2026-04-26 13:30:00	240	1	EGY	EGY	0.00	t
417	4	201000000011	google.com	2026-04-26 13:32:00	100	2	EGY	EGY	0.00	t
418	4	201000000012	201000082407	2026-04-26 13:34:00	1	3	EGY	EGY	0.00	t
419	4	201000000013	201000091408	2026-04-26 13:36:00	90	1	EGY	SAU	0.00	t
420	4	201000000014	news.com	2026-04-26 13:38:00	2000	2	EGY	EGY	0.00	t
421	4	201000000015	201000082410	2026-04-26 13:40:00	1	3	EGY	EGY	0.00	t
422	4	201000000016	201000091411	2026-04-26 13:42:00	900	1	EGY	EGY	0.00	t
423	4	201000000017	spotify.com	2026-04-26 13:44:00	2000	2	EGY	EGY	0.00	t
424	4	201000000018	201000082413	2026-04-26 13:46:00	1	3	EGY	SAU	0.00	t
425	4	201000000001	201000091414	2026-04-26 13:48:00	900	1	EGY	SAU	0.00	t
426	4	201000000002	netflix.com	2026-04-26 13:50:00	50	2	EGY	EGY	0.00	t
427	4	201000000003	201000082416	2026-04-26 13:52:00	1	3	EGY	EGY	0.00	t
428	4	201000000004	201000091417	2026-04-26 13:54:00	60	1	EGY	EGY	0.00	t
429	4	201000000005	instagram.com	2026-04-26 13:56:00	2000	2	EGY	SAU	0.00	t
430	4	201000000006	201000082419	2026-04-26 13:58:00	1	3	EGY	EGY	0.00	t
431	4	201000000007	201000091420	2026-04-26 14:00:00	900	1	EGY	EGY	0.00	t
432	4	201000000008	api.whatsapp.com	2026-04-26 14:02:00	50	2	EGY	EGY	0.00	t
433	4	201000000009	201000082422	2026-04-26 14:04:00	1	3	EGY	EGY	0.00	t
434	4	201000000010	201000091423	2026-04-26 14:06:00	1800	1	EGY	SAU	0.00	t
435	4	201000000011	instagram.com	2026-04-26 14:08:00	1000	2	EGY	SAU	0.00	t
436	4	201000000012	201000082425	2026-04-26 14:10:00	1	3	EGY	EGY	0.00	t
437	4	201000000013	201000091426	2026-04-26 14:12:00	300	1	EGY	EGY	0.00	t
438	4	201000000014	youtube.com	2026-04-26 14:14:00	100	2	EGY	EGY	0.00	t
439	4	201000000015	201000082428	2026-04-26 14:16:00	1	3	EGY	SAU	0.00	t
440	4	201000000016	201000091429	2026-04-26 14:18:00	180	1	EGY	EGY	0.00	t
441	4	201000000017	youtube.com	2026-04-26 14:20:00	300	2	EGY	EGY	0.00	t
442	4	201000000018	201000082431	2026-04-26 14:22:00	1	3	EGY	EGY	0.00	t
443	4	201000000001	201000091432	2026-04-26 14:24:00	240	1	EGY	EGY	0.00	t
444	4	201000000002	tiktok.com	2026-04-26 14:26:00	120	2	EGY	SAU	0.00	t
445	4	201000000003	201000082434	2026-04-26 14:28:00	1	3	EGY	SAU	0.00	t
446	4	201000000004	201000091435	2026-04-26 14:30:00	3600	1	EGY	EGY	0.00	t
447	4	201000000005	api.whatsapp.com	2026-04-26 14:32:00	80	2	EGY	EGY	0.00	t
448	4	201000000006	201000082437	2026-04-26 14:34:00	1	3	EGY	EGY	0.00	t
449	4	201000000007	201000091438	2026-04-26 14:36:00	900	1	EGY	SAU	0.00	t
450	4	201000000008	x.com	2026-04-26 14:38:00	500	2	EGY	EGY	0.00	t
451	4	201000000009	201000082440	2026-04-26 14:40:00	1	3	EGY	EGY	0.00	t
452	4	201000000010	201000091441	2026-04-26 14:42:00	90	1	EGY	EGY	0.00	t
453	4	201000000011	instagram.com	2026-04-26 14:44:00	120	2	EGY	EGY	0.00	t
454	4	201000000012	201000082443	2026-04-26 14:46:00	1	3	EGY	SAU	0.00	t
455	4	201000000013	201000091444	2026-04-26 14:48:00	90	1	EGY	SAU	0.00	t
456	4	201000000014	youtube.com	2026-04-26 14:50:00	500	2	EGY	EGY	0.00	t
457	4	201000000015	201000082446	2026-04-26 14:52:00	1	3	EGY	EGY	0.00	t
458	4	201000000016	201000091447	2026-04-26 14:54:00	90	1	EGY	EGY	0.00	t
459	4	201000000017	api.whatsapp.com	2026-04-26 14:56:00	2000	2	EGY	SAU	0.00	t
460	4	201000000018	201000082449	2026-04-26 14:58:00	1	3	EGY	EGY	0.00	t
461	4	201000000001	201000091450	2026-04-26 15:00:00	300	1	EGY	EGY	0.00	t
462	4	201000000002	tiktok.com	2026-04-26 15:02:00	1500	2	EGY	EGY	0.00	t
463	4	201000000003	201000082452	2026-04-26 15:04:00	1	3	EGY	EGY	0.00	t
464	4	201000000004	201000091453	2026-04-26 15:06:00	180	1	EGY	SAU	0.00	t
465	4	201000000005	netflix.com	2026-04-26 15:08:00	100	2	EGY	SAU	0.00	t
466	4	201000000006	201000082455	2026-04-26 15:10:00	1	3	EGY	EGY	0.00	t
467	4	201000000007	201000091456	2026-04-26 15:12:00	300	1	EGY	EGY	0.00	t
468	4	201000000008	news.com	2026-04-26 15:14:00	50	2	EGY	EGY	0.00	t
469	4	201000000009	201000082458	2026-04-26 15:16:00	1	3	EGY	SAU	0.00	t
470	4	201000000010	201000091459	2026-04-26 15:18:00	120	1	EGY	EGY	0.00	t
471	4	201000000011	news.com	2026-04-26 15:20:00	120	2	EGY	EGY	0.00	t
472	4	201000000012	201000082461	2026-04-26 15:22:00	1	3	EGY	EGY	0.00	t
473	4	201000000013	201000091462	2026-04-26 15:24:00	240	1	EGY	EGY	0.00	t
474	4	201000000014	tiktok.com	2026-04-26 15:26:00	200	2	EGY	SAU	0.00	t
475	4	201000000015	201000082464	2026-04-26 15:28:00	1	3	EGY	SAU	0.00	t
476	4	201000000016	201000091465	2026-04-26 15:30:00	120	1	EGY	EGY	0.00	t
477	4	201000000017	tiktok.com	2026-04-26 15:32:00	50	2	EGY	EGY	0.00	t
478	4	201000000018	201000082467	2026-04-26 15:34:00	1	3	EGY	EGY	0.00	t
479	4	201000000001	201000091468	2026-04-26 15:36:00	300	1	EGY	SAU	0.00	t
480	4	201000000002	google.com	2026-04-26 15:38:00	300	2	EGY	EGY	0.00	t
481	4	201000000003	201000082470	2026-04-26 15:40:00	1	3	EGY	EGY	0.00	t
482	4	201000000004	201000091471	2026-04-26 15:42:00	60	1	EGY	EGY	0.00	t
483	4	201000000005	api.whatsapp.com	2026-04-26 15:44:00	200	2	EGY	EGY	0.00	t
484	4	201000000006	201000082473	2026-04-26 15:46:00	1	3	EGY	SAU	0.00	t
485	4	201000000007	201000091474	2026-04-26 15:48:00	3600	1	EGY	SAU	0.00	t
486	4	201000000008	spotify.com	2026-04-26 15:50:00	1000	2	EGY	EGY	0.00	t
487	4	201000000009	201000082476	2026-04-26 15:52:00	1	3	EGY	EGY	0.00	t
488	4	201000000010	201000091477	2026-04-26 15:54:00	3600	1	EGY	EGY	0.00	t
489	4	201000000011	api.whatsapp.com	2026-04-26 15:56:00	1000	2	EGY	SAU	0.00	t
490	4	201000000012	201000082479	2026-04-26 15:58:00	1	3	EGY	EGY	0.00	t
491	4	201000000013	201000091480	2026-04-26 16:00:00	30	1	EGY	EGY	0.00	t
492	4	201000000014	google.com	2026-04-26 16:02:00	80	2	EGY	EGY	0.00	t
493	4	201000000015	201000082482	2026-04-26 16:04:00	1	3	EGY	EGY	0.00	t
494	4	201000000016	201000091483	2026-04-26 16:06:00	90	1	EGY	SAU	0.00	t
495	4	201000000017	google.com	2026-04-26 16:08:00	1200	2	EGY	SAU	0.00	t
496	4	201000000018	201000082485	2026-04-26 16:10:00	1	3	EGY	EGY	0.00	t
497	4	201000000001	201000091486	2026-04-26 16:12:00	30	1	EGY	EGY	0.00	t
498	4	201000000002	x.com	2026-04-26 16:14:00	80	2	EGY	EGY	0.00	t
499	4	201000000003	201000082488	2026-04-26 16:16:00	1	3	EGY	SAU	0.00	t
500	4	201000000004	201000091489	2026-04-26 16:18:00	300	1	EGY	EGY	0.00	t
501	4	201000000005	api.whatsapp.com	2026-04-26 16:20:00	300	2	EGY	EGY	0.00	t
502	4	201000000006	201000082491	2026-04-26 16:22:00	1	3	EGY	EGY	0.00	t
503	4	201000000007	201000091492	2026-04-26 16:24:00	300	1	EGY	EGY	0.00	t
504	4	201000000008	facebook.com	2026-04-26 16:26:00	1200	2	EGY	SAU	0.00	t
505	4	201000000009	201000082494	2026-04-26 16:28:00	1	3	EGY	SAU	0.00	t
506	4	201000000010	201000091495	2026-04-26 16:30:00	60	1	EGY	EGY	0.00	t
507	4	201000000011	x.com	2026-04-26 16:32:00	500	2	EGY	EGY	0.00	t
508	4	201000000012	201000082497	2026-04-26 16:34:00	1	3	EGY	EGY	0.00	t
509	4	201000000013	201000091498	2026-04-26 16:36:00	120	1	EGY	SAU	0.00	t
510	4	201000000014	youtube.com	2026-04-26 16:38:00	200	2	EGY	EGY	0.00	t
\.


--
-- Data for Name: contract; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.contract (id, user_account_id, rateplan_id, msisdn, status, credit_limit, available_credit) FROM stdin;
1	1	1	201000000001	active	200.00	200.00
3	3	1	201000000003	active	200.00	200.00
4	4	2	201000000004	active	500.00	500.00
6	6	2	201000000006	active	500.00	500.00
7	7	1	201000000007	active	200.00	200.00
9	9	1	201000000009	active	200.00	200.00
10	10	2	201000000010	active	500.00	500.00
12	12	2	201000000012	active	500.00	500.00
13	13	1	201000000013	active	200.00	200.00
15	15	1	201000000015	active	200.00	200.00
16	16	2	201000000016	active	500.00	500.00
18	18	2	201000000018	active	500.00	500.00
19	24	2	201000000026	active	100.00	100.00
17	17	1	201000000017	active	200.00	-1814.00
2	2	2	201000000002	active	500.00	206.50
5	5	1	201000000005	active	200.00	-1880.00
8	8	2	201000000008	active	500.00	-227.00
11	11	1	201000000011	active	200.00	-1851.00
14	14	2	201000000014	active	500.00	51.50
\.


--
-- Data for Name: contract_addon; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.contract_addon (id, contract_id, service_package_id, purchased_date, expiry_date, is_active, price_paid) FROM stdin;
\.


--
-- Data for Name: contract_consumption; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.contract_consumption (contract_id, service_package_id, rateplan_id, starting_date, ending_date, consumed, is_billed, bill_id) FROM stdin;
1	3	1	2026-04-01	2026-04-30	20	t	3
3	1	1	2026-04-01	2026-04-30	0	t	4
4	2	2	2026-04-01	2026-04-30	0	t	5
4	3	2	2026-04-01	2026-04-30	0	t	5
4	4	2	2026-04-01	2026-04-30	0	t	5
4	5	2	2026-04-01	2026-04-30	0	t	5
4	6	2	2026-04-01	2026-04-30	0	t	5
4	7	2	2026-04-01	2026-04-30	0	t	5
6	1	2	2026-04-01	2026-04-30	0	t	6
6	2	2	2026-04-01	2026-04-30	0	t	6
6	4	2	2026-04-01	2026-04-30	0	t	6
6	5	2	2026-04-01	2026-04-30	0	t	6
6	6	2	2026-04-01	2026-04-30	0	t	6
6	7	2	2026-04-01	2026-04-30	0	t	6
7	3	1	2026-04-01	2026-04-30	0	t	7
9	1	1	2026-04-01	2026-04-30	0	t	8
10	2	2	2026-04-01	2026-04-30	0	t	9
10	3	2	2026-04-01	2026-04-30	0	t	9
10	4	2	2026-04-01	2026-04-30	0	t	9
10	5	2	2026-04-01	2026-04-30	0	t	9
10	6	2	2026-04-01	2026-04-30	0	t	9
10	7	2	2026-04-01	2026-04-30	0	t	9
12	1	2	2026-04-01	2026-04-30	0	t	10
12	2	2	2026-04-01	2026-04-30	0	t	10
12	4	2	2026-04-01	2026-04-30	0	t	10
12	5	2	2026-04-01	2026-04-30	0	t	10
12	6	2	2026-04-01	2026-04-30	0	t	10
12	7	2	2026-04-01	2026-04-30	0	t	10
13	3	1	2026-04-01	2026-04-30	0	t	11
15	1	1	2026-04-01	2026-04-30	0	t	12
16	2	2	2026-04-01	2026-04-30	0	t	13
16	3	2	2026-04-01	2026-04-30	0	t	13
16	4	2	2026-04-01	2026-04-30	0	t	13
16	5	2	2026-04-01	2026-04-30	0	t	13
16	6	2	2026-04-01	2026-04-30	0	t	13
16	7	2	2026-04-01	2026-04-30	0	t	13
18	1	2	2026-04-01	2026-04-30	0	t	14
18	2	2	2026-04-01	2026-04-30	0	t	14
18	4	2	2026-04-01	2026-04-30	0	t	14
18	5	2	2026-04-01	2026-04-30	0	t	14
18	6	2	2026-04-01	2026-04-30	0	t	14
18	7	2	2026-04-01	2026-04-30	0	t	14
19	1	2	2026-04-01	2026-04-30	0	t	15
19	2	2	2026-04-01	2026-04-30	0	t	15
19	3	2	2026-04-01	2026-04-30	0	t	15
19	4	2	2026-04-01	2026-04-30	0	t	15
19	5	2	2026-04-01	2026-04-30	0	t	15
19	6	2	2026-04-01	2026-04-30	0	t	15
19	7	2	2026-04-01	2026-04-30	0	t	15
17	1	1	2026-04-01	2026-04-30	0	t	16
17	3	1	2026-04-01	2026-04-30	0	t	16
2	1	2	2026-04-01	2026-04-30	300	t	17
2	3	2	2026-04-01	2026-04-30	40	t	17
2	4	2	2026-04-01	2026-04-30	10	t	17
2	5	2	2026-04-01	2026-04-30	0	t	17
2	7	2	2026-04-01	2026-04-30	0	t	17
5	1	1	2026-04-01	2026-04-30	0	t	18
5	3	1	2026-04-01	2026-04-30	0	t	18
8	1	2	2026-04-01	2026-04-30	0	t	19
8	3	2	2026-04-01	2026-04-30	0	t	19
8	4	2	2026-04-01	2026-04-30	0	t	19
8	5	2	2026-04-01	2026-04-30	0	t	19
8	7	2	2026-04-01	2026-04-30	0	t	19
11	1	1	2026-04-01	2026-04-30	0	t	20
11	3	1	2026-04-01	2026-04-30	0	t	20
14	1	2	2026-04-01	2026-04-30	0	t	21
2	2	2	2026-04-01	2026-04-30	5000	t	17
8	2	2	2026-04-01	2026-04-30	5000	t	19
8	6	2	2026-04-01	2026-04-30	1000	t	19
14	3	2	2026-04-01	2026-04-30	0	t	21
14	4	2	2026-04-01	2026-04-30	0	t	21
14	5	2	2026-04-01	2026-04-30	0	t	21
14	7	2	2026-04-01	2026-04-30	0	t	21
14	2	2	2026-04-01	2026-04-30	5000	t	21
14	6	2	2026-04-01	2026-04-30	1000	t	21
2	6	2	2026-04-01	2026-04-30	1000	t	17
1	1	1	2026-04-01	2026-04-30	426	t	3
3	3	1	2026-04-01	2026-04-30	28	t	4
4	1	2	2026-04-01	2026-04-30	255	t	5
6	3	2	2026-04-01	2026-04-30	28	t	6
7	1	1	2026-04-01	2026-04-30	365	t	7
9	3	1	2026-04-01	2026-04-30	28	t	8
10	1	2	2026-04-01	2026-04-30	403	t	9
12	3	2	2026-04-01	2026-04-30	28	t	10
13	1	1	2026-04-01	2026-04-30	279	t	11
15	3	1	2026-04-01	2026-04-30	27	t	12
16	1	2	2026-04-01	2026-04-30	212	t	13
18	3	2	2026-04-01	2026-04-30	27	t	14
\.


--
-- Data for Name: file; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.file (id, parsed_flag, file_path) FROM stdin;
1	f	/tmp/test_cdr_april_1.csv
2	f	/tmp/test_cdr_april_2.csv
3	t	input/test_cdr_1.csv
4	t	input/test_cdr_500_records_18_contracts.csv
\.


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.invoice (id, bill_id, pdf_path, generation_date) FROM stdin;
1	1	/tmp/invoice_march_1.pdf	2026-04-26 18:10:12.406634
2	2	/tmp/invoice_march_2.pdf	2026-04-26 18:10:12.406634
\.


--
-- Data for Name: msisdn_pool; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.msisdn_pool (id, msisdn, is_available) FROM stdin;
19	201000000019	t
20	201000000020	t
21	201000000021	t
22	201000000022	t
23	201000000023	t
24	201000000024	t
25	201000000025	t
27	201000000027	t
28	201000000028	t
29	201000000029	t
30	201000000030	t
31	201000000031	t
32	201000000032	t
33	201000000033	t
34	201000000034	t
35	201000000035	t
36	201000000036	t
37	201000000037	t
38	201000000038	t
39	201000000039	t
40	201000000040	t
41	201000000041	t
42	201000000042	t
43	201000000043	t
44	201000000044	t
45	201000000045	t
46	201000000046	t
47	201000000047	t
48	201000000048	t
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
26	201000000026	f
\.


--
-- Data for Name: rateplan; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.rateplan (id, name, ror_data, ror_voice, ror_sms, price) FROM stdin;
1	Basic	0.10	0.20	0.05	50.00
2	Premium Gold	0.05	0.10	0.02	120.00
3	Enterprise Elite	0.02	0.05	0.01	349.00
\.


--
-- Data for Name: rateplan_service_package; Type: TABLE DATA; Schema: public; Owner: neondb_owner
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
-- Data for Name: ror_contract; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.ror_contract (contract_id, rateplan_id, data, voice, sms, bill_id) FROM stdin;
1	1	10	20	5	3
3	1	0	0	0	4
4	2	0	0	0	5
6	2	0	0	0	6
7	1	0	0	0	7
9	1	0	0	0	8
10	2	0	0	0	9
12	2	0	0	0	10
13	1	0	0	0	11
15	1	0	0	0	12
16	2	0	0	0	13
18	2	0	0	0	14
19	2	0	0	0	15
17	1	20140	0	0	16
2	2	5875	10	2	17
5	1	20800	0	0	18
8	2	14540	0	0	19
11	1	20510	0	0	20
14	2	8970	0	0	21
\.


--
-- Data for Name: service_package; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.service_package (id, name, type, amount, priority, price, is_roaming, description) FROM stdin;
1	Voice Pack	voice	1000.0000	1	20.00	f	\N
2	Data Pack	data	5000.0000	1	30.00	f	\N
3	SMS Pack	sms	200.0000	1	41.00	f	\N
5	Roaming Voice Pack	voice	200.0000	1	2.00	t	\N
7	Roaming SMS Pack	sms	50.0000	1	7.00	t	\N
4	Welcome Bonus	free_units	50.0000	2	21.00	f	\N
6	Roaming Data Pack	data	1000.0000	1	5.00	t	\N
\.


--
-- Data for Name: user_account; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_account (id, username, password, role, name, email, address, birthdate) FROM stdin;
1	alice	password1	customer	Alice Smith	alice@gmail.com	123 Main St	1990-01-01
2	bob	password2	customer	Bob Johnson	bob@gmail.com	456 Elm St	1985-05-15
3	carol	password3	customer	Carol White	carol@gmail.com	789 Oak Ave	1992-03-10
4	david	password4	customer	David Brown	david@gmail.com	321 Pine Rd	1988-07-22
5	eva	password5	customer	Eva Green	eva@gmail.com	654 Maple Dr	1995-11-05
6	frank	password6	customer	Frank Miller	frank@gmail.com	987 Cedar Ln	1983-02-18
7	grace	password7	customer	Grace Lee	grace@gmail.com	147 Birch Blvd	1991-09-30
8	henry	password8	customer	Henry Wilson	henry@gmail.com	258 Walnut St	1987-04-14
9	iris	password9	customer	Iris Taylor	iris@gmail.com	369 Spruce Ave	1993-06-25
10	jack	password10	customer	Jack Davis	jack@gmail.com	741 Ash Ct	1986-12-03
11	karen	password11	customer	Karen Martinez	karen@gmail.com	852 Elm Pl	1994-08-17
12	leo	password12	customer	Leo Anderson	leo@gmail.com	963 Oak St	1989-01-29
13	mia	password13	customer	Mia Thomas	mia@gmail.com	159 Pine Ave	1996-05-08
14	noah	password14	customer	Noah Jackson	noah@gmail.com	267 Maple Rd	1984-10-21
15	olivia	password15	customer	Olivia Harris	olivia@gmail.com	348 Cedar Dr	1997-03-15
16	paul	password16	customer	Paul Clark	paul@gmail.com	426 Birch Ln	1982-07-04
17	quinn	password17	customer	Quinn Lewis	quinn@gmail.com	537 Walnut Blvd	1998-11-19
18	rachel	password18	customer	Rachel Walker	rachel@gmail.com	648 Spruce St	1981-02-27
24	mohsen	123456	customer	mohsen bygrb	mohsen@gmail.com	123 main st.	2002-07-23
22	admin	admin123	admin	admin	admin@example.com	\N	\N
\.


--
-- Name: bill_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.bill_id_seq', 97, true);


--
-- Name: cdr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.cdr_id_seq', 510, true);


--
-- Name: contract_addon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.contract_addon_id_seq', 1, false);


--
-- Name: contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.contract_id_seq', 19, true);


--
-- Name: file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.file_id_seq', 4, true);


--
-- Name: invoice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.invoice_id_seq', 2, true);


--
-- Name: msisdn_pool_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.msisdn_pool_id_seq', 99, true);


--
-- Name: rateplan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.rateplan_id_seq', 2, true);


--
-- Name: service_package_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.service_package_id_seq', 7, true);


--
-- Name: user_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.user_account_id_seq', 24, true);


--
-- Name: bill bill_contract_id_billing_period_start_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_contract_id_billing_period_start_key UNIQUE (contract_id, billing_period_start);


--
-- Name: bill bill_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_pkey PRIMARY KEY (id);


--
-- Name: cdr cdr_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cdr
    ADD CONSTRAINT cdr_pkey PRIMARY KEY (id);


--
-- Name: contract_addon contract_addon_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_addon
    ADD CONSTRAINT contract_addon_pkey PRIMARY KEY (id);


--
-- Name: contract_consumption contract_consumption_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_pkey PRIMARY KEY (contract_id, service_package_id, rateplan_id, starting_date, ending_date);


--
-- Name: contract contract_msisdn_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_msisdn_key UNIQUE (msisdn);


--
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (id);


--
-- Name: file file_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.file
    ADD CONSTRAINT file_pkey PRIMARY KEY (id);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (id);


--
-- Name: msisdn_pool msisdn_pool_msisdn_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.msisdn_pool
    ADD CONSTRAINT msisdn_pool_msisdn_key UNIQUE (msisdn);


--
-- Name: msisdn_pool msisdn_pool_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.msisdn_pool
    ADD CONSTRAINT msisdn_pool_pkey PRIMARY KEY (id);


--
-- Name: rateplan rateplan_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.rateplan
    ADD CONSTRAINT rateplan_pkey PRIMARY KEY (id);


--
-- Name: rateplan_service_package rateplan_service_package_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.rateplan_service_package
    ADD CONSTRAINT rateplan_service_package_pkey PRIMARY KEY (rateplan_id, service_package_id);


--
-- Name: ror_contract ror_contract_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.ror_contract
    ADD CONSTRAINT ror_contract_pkey PRIMARY KEY (contract_id, rateplan_id);


--
-- Name: service_package service_package_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.service_package
    ADD CONSTRAINT service_package_pkey PRIMARY KEY (id);


--
-- Name: user_account user_account_email_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_email_key UNIQUE (email);


--
-- Name: user_account user_account_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_pkey PRIMARY KEY (id);


--
-- Name: user_account user_account_username_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_username_key UNIQUE (username);


--
-- Name: idx_addon_active; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_addon_active ON public.contract_addon USING btree (contract_id, is_active);


--
-- Name: idx_addon_contract; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_addon_contract ON public.contract_addon USING btree (contract_id);


--
-- Name: idx_bill_billing_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bill_billing_date ON public.bill USING btree (billing_date);


--
-- Name: idx_bill_contract; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bill_contract ON public.bill USING btree (contract_id);


--
-- Name: idx_cdr_dial_a; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cdr_dial_a ON public.cdr USING btree (dial_a);


--
-- Name: idx_cdr_file_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cdr_file_id ON public.cdr USING btree (file_id);


--
-- Name: idx_cdr_rated_flag; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cdr_rated_flag ON public.cdr USING btree (rated_flag);


--
-- Name: idx_contract_msisdn; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_contract_msisdn ON public.contract USING btree (msisdn);


--
-- Name: idx_contract_user_account; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_contract_user_account ON public.contract USING btree (user_account_id);


--
-- Name: idx_invoice_bill; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_invoice_bill ON public.invoice USING btree (bill_id);


--
-- Name: cdr trg_auto_initialize_consumption; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_auto_initialize_consumption BEFORE INSERT ON public.cdr FOR EACH ROW EXECUTE FUNCTION public.auto_initialize_consumption();


--
-- Name: cdr trg_auto_rate_cdr; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_auto_rate_cdr AFTER INSERT ON public.cdr FOR EACH ROW EXECUTE FUNCTION public.auto_rate_cdr();


--
-- Name: bill trg_bill_payment; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_bill_payment AFTER UPDATE ON public.bill FOR EACH ROW EXECUTE FUNCTION public.trg_restore_credit_on_payment();


--
-- Name: cdr trg_cdr_validate_contract; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_cdr_validate_contract BEFORE INSERT ON public.cdr FOR EACH ROW EXECUTE FUNCTION public.validate_cdr_contract();


--
-- Name: bill bill_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: cdr cdr_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cdr
    ADD CONSTRAINT cdr_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.file(id);


--
-- Name: cdr cdr_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cdr
    ADD CONSTRAINT cdr_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.service_package(id);


--
-- Name: contract_addon contract_addon_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_addon
    ADD CONSTRAINT contract_addon_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: contract_addon contract_addon_service_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_addon
    ADD CONSTRAINT contract_addon_service_package_id_fkey FOREIGN KEY (service_package_id) REFERENCES public.service_package(id);


--
-- Name: contract_consumption contract_consumption_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bill(id);


--
-- Name: contract_consumption contract_consumption_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: contract_consumption contract_consumption_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- Name: contract_consumption contract_consumption_service_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract_consumption
    ADD CONSTRAINT contract_consumption_service_package_id_fkey FOREIGN KEY (service_package_id) REFERENCES public.service_package(id);


--
-- Name: contract contract_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- Name: contract contract_user_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_user_account_id_fkey FOREIGN KEY (user_account_id) REFERENCES public.user_account(id);


--
-- Name: invoice invoice_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bill(id);


--
-- Name: rateplan_service_package rateplan_service_package_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.rateplan_service_package
    ADD CONSTRAINT rateplan_service_package_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- Name: rateplan_service_package rateplan_service_package_service_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.rateplan_service_package
    ADD CONSTRAINT rateplan_service_package_service_package_id_fkey FOREIGN KEY (service_package_id) REFERENCES public.service_package(id);


--
-- Name: ror_contract ror_contract_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.ror_contract
    ADD CONSTRAINT ror_contract_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bill(id);


--
-- Name: ror_contract ror_contract_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.ror_contract
    ADD CONSTRAINT ror_contract_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: ror_contract ror_contract_rateplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.ror_contract
    ADD CONSTRAINT ror_contract_rateplan_id_fkey FOREIGN KEY (rateplan_id) REFERENCES public.rateplan(id);


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO neon_superuser WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON TABLES TO neon_superuser WITH GRANT OPTION;


--
-- PostgreSQL database dump complete
--

\unrestrict RZ0XRzmeZoZ1ybGetgVu3gbLXq1chkbw5juKHuKEC0qb0oGK9XlPhTxrdlQz0Ns

