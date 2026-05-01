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
    v_overage_charge NUMERIC := 0;
    v_rated_service_id INTEGER;
    v_is_roaming BOOLEAN;
    v_period_start DATE;
BEGIN
    SELECT * INTO v_cdr FROM cdr WHERE id = p_cdr_id;
    
    SELECT * INTO v_contract FROM contract WHERE msisdn = v_cdr.dial_a AND status = 'active';
    
    IF NOT FOUND THEN
        UPDATE cdr SET rated_flag = TRUE, external_charges = 0, rated_service_id = NULL WHERE id = p_cdr_id;
        RETURN;
    END IF;

    SELECT type::TEXT INTO v_service_type FROM service_package WHERE id = v_cdr.service_id;
    v_remaining := get_cdr_usage_amount(v_cdr.duration, v_service_type::service_type);
    v_is_roaming := (v_cdr.vplmn IS NOT NULL AND v_cdr.vplmn != '');

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
                CASE WHEN v_service_type='data' THEN v_remaining ELSE 0 END,
                CASE WHEN v_service_type='sms' THEN v_remaining ELSE 0 END)
            ON CONFLICT (contract_id, rateplan_id, starting_date) DO UPDATE SET
                roaming_voice = ror_contract.roaming_voice + EXCLUDED.roaming_voice,
                roaming_data = ror_contract.roaming_data + EXCLUDED.roaming_data,
                roaming_sms = ror_contract.roaming_sms + EXCLUDED.roaming_sms;
        ELSE
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

        SELECT 
            CASE WHEN v_is_roaming THEN ror_roaming_voice ELSE ror_voice END,
            CASE WHEN v_is_roaming THEN ror_roaming_data ELSE ror_data END,
            CASE WHEN v_is_roaming THEN ror_roaming_sms ELSE ror_sms END
        INTO v_ror_rate_v, v_ror_rate_d, v_ror_rate_s
        FROM rateplan WHERE id = v_contract.rateplan_id;

        IF v_service_type = 'voice' THEN v_ror_rate := v_ror_rate_v;
        ELSIF v_service_type = 'data' THEN v_ror_rate := v_ror_rate_d;
        ELSIF v_service_type = 'sms' THEN v_ror_rate := v_ror_rate_s;
        END IF;
        
        IF v_service_type = 'data' THEN
            v_overage_charge := (v_remaining / 1073741824.0) * COALESCE(v_ror_rate, 0);
        ELSE
            v_overage_charge := (v_remaining / 60.0) * COALESCE(v_ror_rate, 0);
        END IF;

        UPDATE contract 
        SET available_credit = available_credit - v_overage_charge
        WHERE id = v_contract.id;
    END IF;

    UPDATE cdr SET rated_flag = TRUE, external_charges = v_overage_charge, rated_service_id = v_rated_service_id, cost = v_overage_charge WHERE id = p_cdr_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION release_msisdn(p_msisdn VARCHAR(20))
