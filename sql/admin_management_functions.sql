--==========================================================
--       Function for adding new service package 
--
--==========================================================

CREATE OR REPLACE FUNCTION add_new_service_package(
    p_name character varying,
    p_type public.service_type,
    p_amount numeric,
    p_priority integer,
    p_price numeric,
    p_description text DEFAULT NULL,
    p_is_roaming boolean DEFAULT false
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    INSERT INTO service_package (name, type, amount, priority, price, description, is_roaming)
    VALUES (p_name, p_type, p_amount, p_priority, p_price, p_description, p_is_roaming)
    RETURNING id INTO v_new_id;
    
    RETURN v_new_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'add_new_service_package failed: %', SQLERRM;
END;
$$;

--==========================================================
--       Function for update service package 
--
--==========================================================
CREATE OR REPLACE FUNCTION update_service_package(
    p_id INTEGER,
    p_name VARCHAR(255),
    p_type service_type,
    p_amount NUMERIC(12,4),
    p_priority INTEGER,
    p_price NUMERIC(12,2),
    p_description TEXT,
    p_is_roaming BOOLEAN DEFAULT FALSE
) RETURNS TABLE(
    id INTEGER,
    name VARCHAR(255),
    type service_type,
    amount NUMERIC(12,4),
    priority INTEGER,
    price NUMERIC(12,2),
    description TEXT,
    is_roaming BOOLEAN
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        UPDATE service_package 
        SET 
            name = p_name,
            type = p_type,
            amount = p_amount,
            priority = p_priority,
            price = p_price,
            description = p_description,
            is_roaming = p_is_roaming
        WHERE service_package.id = p_id
        RETURNING 
            service_package.id,
            service_package.name,
            service_package.type,
            service_package.amount,
            service_package.priority,
            service_package.price,
            service_package.description,
            service_package.is_roaming;
            
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service package with id % not found', p_id;
    END IF;
END;
$$;

--==========================================================
--       Function for delete service package 
--
--==========================================================

CREATE OR REPLACE FUNCTION delete_service_package(p_id INTEGER) 
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    -- Check if service package is referenced in any active contracts or addons
    IF EXISTS (
        SELECT 1 FROM contract_consumption cc 
        WHERE cc.service_package_id = p_id AND cc.is_billed = FALSE
    ) THEN
        RAISE EXCEPTION 'Cannot delete service package: it has active consumption records';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM contract_addon ca 
        WHERE ca.service_package_id = p_id AND ca.is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'Cannot delete service package: it has active addons';
    END IF;
    
    DELETE FROM service_package WHERE id = p_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service package with id % not found', p_id;
    END IF;
END;
$$;

--==========================================================
--       Function for adding new rate_plan 
--
--==========================================================
CREATE OR REPLACE FUNCTION create_rateplan_with_packages(
    p_name VARCHAR(255),
    p_ror_voice NUMERIC(10,2),
    p_ror_data NUMERIC(10,2), 
    p_ror_sms NUMERIC(10,2),
    p_price NUMERIC(10,2),
    p_service_package_ids INTEGER[]
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_rateplan_id INTEGER;
    v_package_id INTEGER;
BEGIN
    -- Create the rateplan
    INSERT INTO rateplan (name, ror_voice, ror_data, ror_sms, price)
    VALUES (p_name, p_ror_voice, p_ror_data, p_ror_sms, p_price)
    RETURNING id INTO v_rateplan_id;
    
    -- Link service packages to the rateplan
    IF p_service_package_ids IS NOT NULL THEN
        FOREACH v_package_id IN ARRAY p_service_package_ids
        LOOP
            IF NOT EXISTS (SELECT 1 FROM service_package WHERE id = v_package_id) THEN
                RAISE EXCEPTION 'Service package with id % does not exist', v_package_id;
            END IF;
            
            INSERT INTO rateplan_service_package (rateplan_id, service_package_id)
            VALUES (v_rateplan_id, v_package_id);
        END LOOP;
    END IF;
    
    RETURN v_rateplan_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'create_rateplan_with_packages failed: %', SQLERRM;
END;
$$;

--==========================================================
--       Function for delete rate_plan 
--
--==========================================================



CREATE OR REPLACE FUNCTION delete_rateplan(p_rateplan_id INTEGER) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if rateplan is used by any active contracts
    IF EXISTS (SELECT 1 FROM contract WHERE rateplan_id = p_rateplan_id) THEN
        RAISE EXCEPTION 'Cannot delete rateplan: it is assigned to active contracts';
    END IF;
    
    -- Delete service package associations first
    DELETE FROM rateplan_service_package WHERE rateplan_id = p_rateplan_id;
    
    -- Delete the rateplan
    DELETE FROM rateplan WHERE id = p_rateplan_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rateplan with id % not found', p_rateplan_id;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'delete_rateplan failed: %', SQLERRM;
END;
$$;
--==========================================================
--       Function for update rate_plan 
--
--==========================================================


CREATE OR REPLACE FUNCTION update_rateplan(
    p_rateplan_id INTEGER,
    p_name VARCHAR(255) DEFAULT NULL,
    p_ror_voice NUMERIC(10,2) DEFAULT NULL,
    p_ror_data NUMERIC(10,2) DEFAULT NULL,
    p_ror_sms NUMERIC(10,2) DEFAULT NULL,
    p_price NUMERIC(10,2) DEFAULT NULL,
    p_service_package_ids INTEGER[] DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_package_id INTEGER;
BEGIN
    -- Check if rateplan exists
    IF NOT EXISTS (SELECT 1 FROM rateplan WHERE id = p_rateplan_id) THEN
        RAISE EXCEPTION 'Rateplan with id % does not exist', p_rateplan_id;
    END IF;
    
    -- Update rateplan fields (only non-null values)
    UPDATE rateplan 
    SET 
        name = COALESCE(p_name, name),
        ror_voice = COALESCE(p_ror_voice, ror_voice),
        ror_data = COALESCE(p_ror_data, ror_data),
        ror_sms = COALESCE(p_ror_sms, ror_sms),
        price = COALESCE(p_price, price)
    WHERE id = p_rateplan_id;
    
    -- Update service package associations if provided
    IF p_service_package_ids IS NOT NULL THEN
        -- Remove existing associations
        DELETE FROM rateplan_service_package WHERE rateplan_id = p_rateplan_id;
        
        -- Add new associations
        FOREACH v_package_id IN ARRAY p_service_package_ids
        LOOP
            IF NOT EXISTS (SELECT 1 FROM service_package WHERE id = v_package_id) THEN
                RAISE EXCEPTION 'Service package with id % does not exist', v_package_id;
            END IF;
            
            INSERT INTO rateplan_service_package (rateplan_id, service_package_id)
            VALUES (p_rateplan_id, v_package_id);
        END LOOP;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'update_rateplan failed: %', SQLERRM;
END;
$$;
