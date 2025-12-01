-- =====================================================
-- AFX ADMIN PANEL - CRUD FUNCTIONS
-- =====================================================
-- Server-side functions for admin operations with audit logging

-- 1. ADMIN USER MANAGEMENT

-- Update user role/admin status
CREATE OR REPLACE FUNCTION admin_update_user(
    p_admin_id UUID,
    p_user_id UUID,
    p_is_admin BOOLEAN DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_admin_note TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Get old data
    SELECT to_jsonb(profiles.*) INTO v_old_data
    FROM profiles WHERE id = p_user_id;

    IF v_old_data IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- Update user
    UPDATE profiles SET
        is_admin = COALESCE(p_is_admin, is_admin),
        role = COALESCE(p_role, role),
        admin_note = COALESCE(p_admin_note, admin_note),
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Get new data
    SELECT to_jsonb(profiles.*) INTO v_new_data
    FROM profiles WHERE id = p_user_id;

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        'UPDATE_USER',
        'profiles',
        p_user_id,
        jsonb_build_object('old', v_old_data, 'new', v_new_data),
        p_ip_address,
        p_user_agent
    );

    RETURN jsonb_build_object(
        'success', true,
        'user', v_new_data
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Disable/Enable user (soft delete)
CREATE OR REPLACE FUNCTION admin_toggle_user_status(
    p_admin_id UUID,
    p_user_id UUID,
    p_disabled BOOLEAN,
    p_reason TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Prevent self-disable
    IF p_user_id = p_admin_id THEN
        RAISE EXCEPTION 'Cannot disable your own account';
    END IF;

    -- Update user status
    UPDATE profiles SET
        disabled = p_disabled,
        disabled_at = CASE WHEN p_disabled THEN NOW() ELSE NULL END,
        disabled_by = CASE WHEN p_disabled THEN p_admin_id ELSE NULL END,
        admin_note = COALESCE(p_reason, admin_note),
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        CASE WHEN p_disabled THEN 'DISABLE_USER' ELSE 'ENABLE_USER' END,
        'profiles',
        p_user_id,
        jsonb_build_object('reason', p_reason),
        p_ip_address,
        p_user_agent
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. ADMIN P2P AD MANAGEMENT

-- Update P2P ad
CREATE OR REPLACE FUNCTION admin_update_ad(
    p_admin_id UUID,
    p_ad_id UUID,
    p_updates JSONB,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_old_data JSONB;
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Get old data
    SELECT to_jsonb(p2p_ads.*) INTO v_old_data
    FROM p2p_ads WHERE id = p_ad_id;

    IF v_old_data IS NULL THEN
        RAISE EXCEPTION 'Ad not found';
    END IF;

    -- Update ad (only allowed fields)
    UPDATE p2p_ads SET
        min_amount = COALESCE((p_updates->>'min_amount')::NUMERIC, min_amount),
        max_amount = COALESCE((p_updates->>'max_amount')::NUMERIC, max_amount),
        is_active = COALESCE((p_updates->>'is_active')::BOOLEAN, is_active),
        updated_at = NOW()
    WHERE id = p_ad_id;

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        'UPDATE_AD',
        'p2p_ads',
        p_ad_id,
        jsonb_build_object('old', v_old_data, 'updates', p_updates),
        p_ip_address,
        p_user_agent
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Disable/Enable ad
CREATE OR REPLACE FUNCTION admin_toggle_ad_status(
    p_admin_id UUID,
    p_ad_id UUID,
    p_disabled BOOLEAN,
    p_reason TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Update ad status
    UPDATE p2p_ads SET
        disabled = p_disabled,
        disabled_at = CASE WHEN p_disabled THEN NOW() ELSE NULL END,
        disabled_by = CASE WHEN p_disabled THEN p_admin_id ELSE NULL END,
        is_active = CASE WHEN p_disabled THEN FALSE ELSE is_active END,
        updated_at = NOW()
    WHERE id = p_ad_id;

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        CASE WHEN p_disabled THEN 'DISABLE_AD' ELSE 'ENABLE_AD' END,
        'p2p_ads',
        p_ad_id,
        jsonb_build_object('reason', p_reason),
        p_ip_address,
        p_user_agent
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. ADMIN TRADE MANAGEMENT

-- Force complete trade
CREATE OR REPLACE FUNCTION admin_force_complete_trade(
    p_admin_id UUID,
    p_trade_id UUID,
    p_reason TEXT,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_trade RECORD;
    v_seller_id UUID;
    v_buyer_id UUID;
    v_amount NUMERIC;
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Get trade details
    SELECT * INTO v_trade FROM p2p_trades WHERE id = p_trade_id;
    
    IF v_trade IS NULL THEN
        RAISE EXCEPTION 'Trade not found';
    END IF;

    IF v_trade.status = 'completed' THEN
        RAISE EXCEPTION 'Trade already completed';
    END IF;

    v_seller_id := v_trade.seller_id;
    v_buyer_id := v_trade.buyer_id;
    v_amount := v_trade.afx_amount;

    -- Transfer coins from seller to buyer
    UPDATE trade_coins 
    SET amount = amount - v_amount
    WHERE user_id = v_seller_id AND amount >= v_amount;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient seller balance';
    END IF;

    -- Credit buyer
    INSERT INTO trade_coins (user_id, amount, source, reference_id)
    VALUES (v_buyer_id, v_amount, 'p2p_trade', p_trade_id)
    ON CONFLICT (user_id) DO UPDATE
    SET amount = trade_coins.amount + v_amount;

    -- Update trade status
    UPDATE p2p_trades SET
        status = 'completed',
        released_at = NOW(),
        force_completed_by = p_admin_id,
        force_completed_at = NOW(),
        admin_note = p_reason
    WHERE id = p_trade_id;

    -- Award referral commission (1.5%)
    PERFORM award_referral_commission(v_buyer_id, v_amount * 0.015, p_trade_id);

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        'FORCE_COMPLETE_TRADE',
        'p2p_trades',
        p_trade_id,
        jsonb_build_object('reason', p_reason, 'amount', v_amount),
        p_ip_address,
        p_user_agent
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Force refund trade
CREATE OR REPLACE FUNCTION admin_force_refund_trade(
    p_admin_id UUID,
    p_trade_id UUID,
    p_reason TEXT,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_trade RECORD;
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Get trade details
    SELECT * INTO v_trade FROM p2p_trades WHERE id = p_trade_id;
    
    IF v_trade IS NULL THEN
        RAISE EXCEPTION 'Trade not found';
    END IF;

    IF v_trade.status IN ('completed', 'cancelled', 'expired') THEN
        RAISE EXCEPTION 'Trade cannot be refunded';
    END IF;

    -- Unlock coins in trade_coins
    UPDATE trade_coins 
    SET status = 'available',
        locked_at = NULL,
        locked_for_trade_id = NULL
    WHERE user_id = v_trade.seller_id 
    AND locked_for_trade_id = p_trade_id;

    -- Update trade status
    UPDATE p2p_trades SET
        status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by = p_admin_id,
        admin_note = p_reason
    WHERE id = p_trade_id;

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        'FORCE_REFUND_TRADE',
        'p2p_trades',
        p_trade_id,
        jsonb_build_object('reason', p_reason),
        p_ip_address,
        p_user_agent
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. ADMIN SETTINGS MANAGEMENT

-- Update system setting
CREATE OR REPLACE FUNCTION admin_update_setting(
    p_admin_id UUID,
    p_key TEXT,
    p_value JSONB,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_old_value JSONB;
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Get old value
    SELECT value INTO v_old_value FROM admin_settings WHERE key = p_key;

    -- Update setting
    UPDATE admin_settings SET
        value = p_value,
        updated_by = p_admin_id,
        updated_at = NOW()
    WHERE key = p_key;

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        'UPDATE_SETTING',
        'admin_settings',
        NULL,
        jsonb_build_object('key', p_key, 'old_value', v_old_value, 'new_value', p_value),
        p_ip_address,
        p_user_agent
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
