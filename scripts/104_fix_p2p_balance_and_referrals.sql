-- ============================================================================
-- PART 1: UPDATE P2P TRADE FUNCTIONS TO USE COINS TABLE
-- ============================================================================

-- Drop old functions that reference total_mined
DROP FUNCTION IF EXISTS initiate_p2p_trade(UUID, UUID, UUID, NUMERIC);
DROP FUNCTION IF EXISTS release_p2p_coins(UUID, UUID);
DROP FUNCTION IF EXISTS cancel_p2p_trade(UUID, UUID);
DROP FUNCTION IF EXISTS get_available_balance(UUID);

-- Helper function to get user balance from coins table
CREATE OR REPLACE FUNCTION get_user_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
BEGIN
  RETURN COALESCE(
    (SELECT SUM(amount) FROM coins WHERE user_id = p_user_id AND status = 'active'),
    0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get available balance (excluding locked in escrow)
CREATE OR REPLACE FUNCTION get_available_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  total_balance NUMERIC;
  locked_in_escrow NUMERIC;
  locked_in_ads NUMERIC;
BEGIN
  -- Get total balance from coins table
  total_balance := get_user_balance(p_user_id);
  
  -- Get locked balance in active escrow trades (as seller)
  SELECT COALESCE(SUM(escrow_amount), 0) INTO locked_in_escrow
  FROM p2p_trades
  WHERE seller_id = p_user_id
  AND status IN ('escrowed', 'payment_sent')
  AND expires_at > NOW();
  
  -- Get locked balance in active sell ads
  SELECT COALESCE(SUM(remaining_amount), 0) INTO locked_in_ads
  FROM p2p_ads
  WHERE user_id = p_user_id
  AND ad_type = 'sell'
  AND status = 'active'
  AND expires_at > NOW();
  
  RETURN total_balance - locked_in_escrow - locked_in_ads;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Updated initiate_p2p_trade to use coins table instead of total_mined
CREATE OR REPLACE FUNCTION initiate_p2p_trade(
  p_ad_id UUID,
  p_buyer_id UUID,
  p_seller_id UUID,
  p_afx_amount NUMERIC
) RETURNS UUID AS $$
DECLARE
  v_trade_id UUID;
  v_seller_balance NUMERIC;
BEGIN
  -- Check seller has enough available balance
  v_seller_balance := get_available_balance(p_seller_id);

  IF v_seller_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Seller has insufficient balance. Available: %, Required: %', v_seller_balance, p_afx_amount;
  END IF;

  -- Create trade with escrow status
  INSERT INTO p2p_trades (ad_id, buyer_id, seller_id, afx_amount, escrow_amount, status)
  VALUES (p_ad_id, p_buyer_id, p_seller_id, p_afx_amount, p_afx_amount, 'escrowed')
  RETURNING id INTO v_trade_id;

  -- Record escrow transaction (coins are locked, not moved yet)
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (p_seller_id, 'p2p_escrow', -p_afx_amount, 'AFX locked in escrow for P2P trade', v_trade_id, 'completed');

  -- Update ad remaining amount
  UPDATE p2p_ads
  SET remaining_amount = remaining_amount - p_afx_amount,
      updated_at = NOW()
  WHERE id = p_ad_id;

  RETURN v_trade_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Updated release_p2p_coins to transfer via coins table and trigger referral commission
CREATE OR REPLACE FUNCTION release_p2p_coins(
  p_trade_id UUID,
  p_seller_id UUID
) RETURNS VOID AS $$
DECLARE
  v_buyer_id UUID;
  v_escrow_amount NUMERIC;
  v_trade_status TEXT;
  v_buyer_referrer UUID;
  v_commission_amount NUMERIC;
BEGIN
  -- Get trade details
  SELECT buyer_id, escrow_amount, status
  INTO v_buyer_id, v_escrow_amount, v_trade_status
  FROM p2p_trades
  WHERE id = p_trade_id AND seller_id = p_seller_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not the seller';
  END IF;

  IF v_trade_status NOT IN ('escrowed', 'payment_sent') THEN
    RAISE EXCEPTION 'Trade is not in a state to release coins';
  END IF;

  -- Update trade status
  UPDATE p2p_trades
  SET status = 'completed',
      coins_released_at = NOW(),
      updated_at = NOW()
  WHERE id = p_trade_id;

  -- Transfer coins via coins table: deduct from seller
  INSERT INTO coins (user_id, amount, claim_type, status)
  VALUES (p_seller_id, -v_escrow_amount, 'p2p_sell', 'active');

  -- Transfer coins via coins table: add to buyer
  INSERT INTO coins (user_id, amount, claim_type, status)
  VALUES (v_buyer_id, v_escrow_amount, 'p2p_buy', 'active');

  -- Record transaction for buyer
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (v_buyer_id, 'p2p_buy', v_escrow_amount, 'Received AFX from P2P trade', p_trade_id, 'completed');

  -- Record transaction for seller
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (p_seller_id, 'p2p_sell', -v_escrow_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed');

  -- Process referral commission for buyer (2% of trade amount)
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    v_commission_amount := v_escrow_amount * 0.02; -- 2% commission
    
    -- Add commission to referrer's balance
    INSERT INTO coins (user_id, amount, claim_type, status)
    VALUES (v_buyer_referrer, v_commission_amount, 'referral_commission', 'active');
    
    -- Record referral commission
    INSERT INTO referral_commissions (referrer_id, referred_id, amount, commission_type, source_id, status)
    VALUES (v_buyer_referrer, v_buyer_id, v_commission_amount, 'trading', p_trade_id, 'completed');
    
    -- Update referral stats
    UPDATE referrals
    SET total_trading_commission = total_trading_commission + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_buyer_id;
    
    -- Record transaction for referrer
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_buyer_referrer, 'referral_commission', v_commission_amount, 'Referral commission from P2P trade', p_trade_id, 'completed');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Updated cancel_p2p_trade to work with coins table
CREATE OR REPLACE FUNCTION cancel_p2p_trade(
  p_trade_id UUID,
  p_user_id UUID
) RETURNS VOID AS $$
DECLARE
  v_seller_id UUID;
  v_buyer_id UUID;
  v_escrow_amount NUMERIC;
  v_status TEXT;
  v_ad_id UUID;
BEGIN
  -- Get trade details
  SELECT seller_id, buyer_id, escrow_amount, status, ad_id
  INTO v_seller_id, v_buyer_id, v_escrow_amount, v_status, v_ad_id
  FROM p2p_trades
  WHERE id = p_trade_id AND (buyer_id = p_user_id OR seller_id = p_user_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found';
  END IF;

  IF v_status = 'completed' THEN
    RAISE EXCEPTION 'Cannot cancel completed trade';
  END IF;

  -- Update trade status
  UPDATE p2p_trades
  SET status = 'cancelled',
      updated_at = NOW()
  WHERE id = p_trade_id;

  -- Return locked amount to ad
  IF v_ad_id IS NOT NULL THEN
    UPDATE p2p_ads
    SET remaining_amount = remaining_amount + v_escrow_amount,
        updated_at = NOW()
    WHERE id = v_ad_id;
  END IF;

  -- Record cancellation transaction
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (v_seller_id, 'p2p_cancel', 0, 'P2P trade cancelled - coins unlocked', p_trade_id, 'completed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 2: FIX REFERRAL SYSTEM TO TRACK UPLINE/DOWNLINE
-- ============================================================================

-- Create trigger to automatically create referral relationship on signup
CREATE OR REPLACE FUNCTION create_referral_relationship()
RETURNS TRIGGER AS $$
DECLARE
  v_referrer_id UUID;
BEGIN
  -- If user signed up with a referral code, create the relationship
  IF NEW.referred_by IS NOT NULL THEN
    -- Insert into referrals table
    INSERT INTO referrals (referrer_id, referred_id, referral_code, status)
    VALUES (NEW.referred_by, NEW.id, NEW.referral_code, 'active')
    ON CONFLICT (referrer_id, referred_id) DO NOTHING;
    
    -- Update referrer's total referrals count
    UPDATE profiles
    SET total_referrals = total_referrals + 1,
        updated_at = NOW()
    WHERE id = NEW.referred_by;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_create_referral_relationship ON profiles;

-- Create trigger on profiles table
CREATE TRIGGER trigger_create_referral_relationship
  AFTER INSERT ON profiles
  FOR EACH ROW
  WHEN (NEW.referred_by IS NOT NULL)
  EXECUTE FUNCTION create_referral_relationship();

-- ============================================================================
-- PART 3: REBRAND REMAINING GX REFERENCES TO AFX IN DATABASE
-- ============================================================================

-- Update p2p_trades column name if not already done
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'p2p_trades' AND column_name = 'gx_amount'
  ) THEN
    ALTER TABLE p2p_trades RENAME COLUMN gx_amount TO afx_amount;
  END IF;
END $$;

-- Update price table names if they still use gx prefix
DO $$
BEGIN
  -- Rename gx_current_price to afx_current_price
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gx_current_price') THEN
    ALTER TABLE gx_current_price RENAME TO afx_current_price;
  END IF;
  
  -- Rename gx_price_history to afx_price_history
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gx_price_history') THEN
    ALTER TABLE gx_price_history RENAME TO afx_price_history;
  END IF;
  
  -- Rename gx_price_references to afx_price_references
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gx_price_references') THEN
    ALTER TABLE gx_price_references RENAME TO afx_price_references;
  END IF;
  
  -- Rename view if it exists
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'v_current_gx_price') THEN
    DROP VIEW IF EXISTS v_current_gx_price;
    CREATE VIEW v_current_afx_price AS
    SELECT 
      price as current_price,
      previous_price,
      change_percent,
      updated_at,
      (updated_at < NOW() - INTERVAL '5 minutes') as needs_update
    FROM afx_current_price
    ORDER BY updated_at DESC
    LIMIT 1;
  END IF;
END $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION initiate_p2p_trade(UUID, UUID, UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_p2p_trade(UUID, UUID) TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_coins_user_status ON coins(user_id, status);
CREATE INDEX IF NOT EXISTS idx_p2p_trades_seller_status ON p2p_trades(seller_id, status);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referral_commissions_referrer ON referral_commissions(referrer_id);

-- ============================================================================
-- VERIFICATION QUERIES (commented out - uncomment to test)
-- ============================================================================

-- SELECT get_user_balance('your-user-id-here');
-- SELECT get_available_balance('your-user-id-here');
-- SELECT * FROM referrals WHERE referrer_id = 'your-user-id-here';
