-- =====================================================
-- NEW REFERRAL REWARD SYSTEM
-- =====================================================
-- 1. Upline gets 1 AFX when downline registers AND completes 1 mining circle
-- 2. Upline gets 2 AFX when downline completes 1 P2P trade
-- =====================================================

-- Add column to track if signup reward has been given
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS signup_reward_given BOOLEAN DEFAULT FALSE;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS first_mining_reward_given BOOLEAN DEFAULT FALSE;

-- Function to award 1 AFX upon first mining claim (signup bonus)
CREATE OR REPLACE FUNCTION award_referral_signup_bonus()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
  v_reward_amount NUMERIC := 1.0; -- 1 AFX reward
BEGIN
  -- Only trigger on mining claims
  IF NEW.claim_type != 'mining' THEN
    RETURN NEW;
  END IF;
  
  -- Get referrer for this user
  SELECT referred_by INTO v_referrer_id
  FROM profiles
  WHERE id = NEW.user_id;
  
  IF v_referrer_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if this is the first mining claim and reward hasn't been given
  IF NOT EXISTS (
    SELECT 1 FROM referrals
    WHERE referrer_id = v_referrer_id 
      AND referred_id = NEW.user_id 
      AND first_mining_reward_given = TRUE
  ) THEN
    -- Award 1 AFX to upline's P2P balance (trade_coins)
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_referrer_id, v_reward_amount, 'available', 'referral_commission', NEW.id);
    
    -- Record the commission
    INSERT INTO referral_commissions (
      referrer_id, 
      referred_id, 
      amount, 
      commission_type, 
      source_id, 
      status
    ) VALUES (
      v_referrer_id, 
      NEW.user_id, 
      v_reward_amount, 
      'signup_mining', 
      NEW.id, 
      'completed'
    );
    
    -- Mark reward as given
    UPDATE referrals
    SET first_mining_reward_given = TRUE,
        updated_at = NOW()
    WHERE referrer_id = v_referrer_id AND referred_id = NEW.user_id;
    
    -- Record transaction
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (
      v_referrer_id, 
      'referral_commission', 
      v_reward_amount, 
      'Referral signup bonus: 1 AFX (downline completed first mining)', 
      NEW.user_id, 
      'completed'
    );
    
    RAISE NOTICE 'Awarded 1 AFX signup bonus to referrer % for referred user %', v_referrer_id, NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for mining signup bonus
DROP TRIGGER IF EXISTS trigger_referral_signup_bonus ON coins;
CREATE TRIGGER trigger_referral_signup_bonus
  AFTER INSERT ON coins
  FOR EACH ROW
  WHEN (NEW.claim_type = 'mining')
  EXECUTE FUNCTION award_referral_signup_bonus();

-- Update release_p2p_coins to give fixed 2 AFX (instead of 1%)
CREATE OR REPLACE FUNCTION release_p2p_coins(
  p_trade_id UUID,
  p_seller_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade p2p_trades%ROWTYPE;
  v_buyer_referrer UUID;
  v_commission_amount NUMERIC := 2.0; -- Fixed 2 AFX reward
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id AND seller_id = p_seller_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not the seller';
  END IF;

  IF v_trade.is_paid IS NOT TRUE THEN
    RAISE EXCEPTION 'Buyer must mark payment as sent before you can release coins';
  END IF;

  IF v_trade.status NOT IN ('payment_sent', 'escrowed', 'pending') THEN
    RAISE EXCEPTION 'Trade is not in a state to release coins';
  END IF;

  -- Update trade status to completed
  UPDATE p2p_trades
  SET 
    status = 'completed',
    released_at = NOW(),
    coins_released_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Transfer coins from seller to buyer
  UPDATE trade_coins
  SET 
    user_id = v_trade.buyer_id,
    status = 'available',
    locked_at = NULL,
    locked_for_trade_id = NULL,
    updated_at = NOW()
  WHERE user_id = v_trade.seller_id
    AND status = 'locked'
    AND locked_for_trade_id = p_trade_id;

  IF NOT FOUND THEN
    -- Deduct from seller's available balance
    WITH deducted AS (
      SELECT id FROM trade_coins
      WHERE user_id = v_trade.seller_id 
        AND status = 'available'
        AND amount >= v_trade.afx_amount
      ORDER BY created_at ASC
      LIMIT 1
      FOR UPDATE
    )
    UPDATE trade_coins
    SET amount = amount - v_trade.afx_amount,
        updated_at = NOW()
    WHERE id = (SELECT id FROM deducted);

    -- Credit to buyer
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_trade.buyer_id, v_trade.afx_amount, 'available', 'p2p_trade', p_trade_id);
  END IF;

  -- Log the action
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (p_trade_id, p_seller_id, 'coins_released', v_trade.afx_amount);

  -- Record transactions
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES 
    (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from P2P trade', p_trade_id, 'completed'),
    (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed');

  -- Process fixed 2 AFX referral commission to upline's P2P balance
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    -- Credit 2 AFX to upline's trade_coins (P2P balance)
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_buyer_referrer, v_commission_amount, 'available', 'referral_commission', p_trade_id);
    
    -- Record commission
    INSERT INTO referral_commissions (referrer_id, referred_id, amount, commission_type, source_id, status)
    VALUES (v_buyer_referrer, v_trade.buyer_id, v_commission_amount, 'trading', p_trade_id, 'completed');
    
    -- Update referral totals
    UPDATE referrals
    SET total_trading_commission = COALESCE(total_trading_commission, 0) + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_trade.buyer_id;
    
    -- Record transaction
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_buyer_referrer, 'referral_commission', v_commission_amount, 'Referral P2P trade reward: 2 AFX', p_trade_id, 'completed');
    
    RAISE NOTICE 'Awarded 2 AFX P2P trade commission to referrer % for referred user %', v_buyer_referrer, v_trade.buyer_id;
  END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION award_referral_signup_bonus() TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;

-- Add comment
COMMENT ON FUNCTION award_referral_signup_bonus IS 'Awards 1 AFX to upline when downline completes first mining claim';
COMMENT ON FUNCTION release_p2p_coins IS 'Release coins from seller to buyer. Awards fixed 2 AFX referral commission to upline P2P balance.';

-- Update referral_commissions to track new types
ALTER TABLE referral_commissions 
  DROP CONSTRAINT IF EXISTS referral_commissions_commission_type_check;

ALTER TABLE referral_commissions 
  ADD CONSTRAINT referral_commissions_commission_type_check 
  CHECK (commission_type IN ('trading', 'claim', 'signup_mining'));
