-- ============================================
-- COMPREHENSIVE SYSTEM UPDATE
-- ============================================
-- 1. Balance Synchronization (P2P + Dashboard)
-- 2. Referral System Redesign (6-char codes, 2% commission)
-- 3. AfriX Rebranding (GrowX → AfriX, GX → AFX)
-- ============================================

-- ============================================
-- PART 1: BALANCE SYNCHRONIZATION
-- ============================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_available_balance(UUID);

-- Create unified balance function
-- Returns available balance = total coins - locked in active sell ads
CREATE OR REPLACE FUNCTION get_available_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  total_balance NUMERIC;
  locked_balance NUMERIC;
BEGIN
  -- Get total balance from coins table
  SELECT COALESCE(SUM(amount), 0) INTO total_balance
  FROM coins
  WHERE user_id = p_user_id
  AND status = 'available';
  
  -- Get locked balance from active sell ads
  SELECT COALESCE(SUM(remaining_amount), 0) INTO locked_balance
  FROM p2p_ads
  WHERE user_id = p_user_id
  AND ad_type = 'sell'
  AND status = 'active'
  AND expires_at > NOW();
  
  RETURN total_balance - locked_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get total balance
CREATE OR REPLACE FUNCTION get_user_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
BEGIN
  RETURN COALESCE(
    (SELECT SUM(amount) FROM coins WHERE user_id = p_user_id AND status = 'available'),
    0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_available_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_balance(UUID) TO authenticated;

-- ============================================
-- PART 2: REFERRAL SYSTEM REDESIGN
-- ============================================

-- Function to generate 6-character alphanumeric referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Exclude confusing chars (0,O,1,I)
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  
  -- Check if code already exists
  WHILE EXISTS (SELECT 1 FROM profiles WHERE referral_code = result) LOOP
    result := '';
    FOR i IN 1..6 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update existing profiles with new referral codes (only if null or old format)
UPDATE profiles
SET referral_code = generate_referral_code()
WHERE referral_code IS NULL OR referral_code LIKE 'GX_%';

-- Function to process referral commission on P2P trade
CREATE OR REPLACE FUNCTION process_referral_commission_on_trade()
RETURNS TRIGGER AS $$
DECLARE
  seller_referrer_id UUID;
  commission_amount NUMERIC;
BEGIN
  -- Only process when trade is completed
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    
    -- Get seller's referrer
    SELECT referred_by INTO seller_referrer_id
    FROM profiles
    WHERE id = NEW.seller_id;
    
    IF seller_referrer_id IS NOT NULL THEN
      -- Calculate 2% commission on trade amount
      commission_amount := NEW.gx_amount * 0.02;
      
      -- Add commission to referrer's balance
      INSERT INTO coins (user_id, amount, claim_type, status)
      VALUES (seller_referrer_id, commission_amount, 'referral_trading', 'available');
      
      -- Update referral tracking
      UPDATE referrals
      SET 
        total_trading_commission = total_trading_commission + commission_amount,
        updated_at = NOW()
      WHERE referrer_id = seller_referrer_id
      AND referred_id = NEW.seller_id;
      
      -- Create transaction record
      INSERT INTO transactions (user_id, type, amount, description, related_id, status)
      VALUES (
        seller_referrer_id,
        'referral_commission',
        commission_amount,
        'Trading commission from referral',
        NEW.id,
        'completed'
      );
      
      -- Create commission record
      INSERT INTO referral_commissions (
        referrer_id,
        referred_id,
        amount,
        commission_type,
        source_id,
        status
      ) VALUES (
        seller_referrer_id,
        NEW.seller_id,
        commission_amount,
        'trading',
        NEW.id,
        'completed'
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for P2P trade commission
DROP TRIGGER IF EXISTS trigger_referral_commission_on_trade ON p2p_trades;
CREATE TRIGGER trigger_referral_commission_on_trade
  AFTER UPDATE ON p2p_trades
  FOR EACH ROW
  EXECUTE FUNCTION process_referral_commission_on_trade();

-- Function to process referral commission on mining claim
CREATE OR REPLACE FUNCTION process_referral_commission_on_mining()
RETURNS TRIGGER AS $$
DECLARE
  user_referrer_id UUID;
  commission_amount NUMERIC;
BEGIN
  -- Only process mining claims
  IF NEW.claim_type = 'mining' THEN
    
    -- Get user's referrer
    SELECT referred_by INTO user_referrer_id
    FROM profiles
    WHERE id = NEW.user_id;
    
    IF user_referrer_id IS NOT NULL THEN
      -- Calculate 1% commission on mining claim
      commission_amount := NEW.amount * 0.01;
      
      -- Add commission to referrer's balance
      INSERT INTO coins (user_id, amount, claim_type, status)
      VALUES (user_referrer_id, commission_amount, 'referral_mining', 'available');
      
      -- Update referral tracking
      UPDATE referrals
      SET 
        total_claim_commission = total_claim_commission + commission_amount,
        updated_at = NOW()
      WHERE referrer_id = user_referrer_id
      AND referred_id = NEW.user_id;
      
      -- Create transaction record
      INSERT INTO transactions (user_id, type, amount, description, related_id, status)
      VALUES (
        user_referrer_id,
        'referral_commission',
        commission_amount,
        'Mining commission from referral',
        NEW.id,
        'completed'
      );
      
      -- Create commission record
      INSERT INTO referral_commissions (
        referrer_id,
        referred_id,
        amount,
        commission_type,
        source_id,
        status
      ) VALUES (
        user_referrer_id,
        NEW.user_id,
        commission_amount,
        'mining',
        NEW.id,
        'completed'
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for mining commission
DROP TRIGGER IF EXISTS trigger_referral_commission_on_mining ON coins;
CREATE TRIGGER trigger_referral_commission_on_mining
  AFTER INSERT ON coins
  FOR EACH ROW
  EXECUTE FUNCTION process_referral_commission_on_mining();

-- ============================================
-- PART 3: AFRIX REBRANDING
-- ============================================

-- Note: Database structure remains unchanged
-- Only display names and metadata are updated
-- All table names, column names, and functions remain as-is

-- Update price table metadata (for display purposes)
COMMENT ON TABLE gx_current_price IS 'Current AFX price (formerly GX)';
COMMENT ON TABLE gx_price_history IS 'AFX price history (formerly GX)';
COMMENT ON TABLE gx_price_references IS 'AFX price references (formerly GX)';

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_coins_user_status ON coins(user_id, status);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_user_type_status ON p2p_ads(user_id, ad_type, status);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referral_commissions_referrer ON referral_commissions(referrer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_type ON transactions(user_id, type);

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION generate_referral_code() TO authenticated;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'System update completed successfully!';
  RAISE NOTICE '1. Balance synchronization functions created';
  RAISE NOTICE '2. Referral system redesigned with 6-char codes and 2%% commission';
  RAISE NOTICE '3. AfriX rebranding metadata updated';
END $$;
