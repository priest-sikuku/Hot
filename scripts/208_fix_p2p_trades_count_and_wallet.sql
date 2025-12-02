-- Fix the get_completed_p2p_trades_count function to ensure it counts correctly
-- and add wallet_address column to profiles if not exists

-- Add wallet_address column to profiles if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS wallet_address TEXT;

-- Add comment
COMMENT ON COLUMN profiles.wallet_address IS 'User cryptocurrency wallet address for receiving transfers';

-- Drop and recreate the function with better logic
DROP FUNCTION IF EXISTS get_completed_p2p_trades_count(uuid);

CREATE OR REPLACE FUNCTION get_completed_p2p_trades_count(p_user_id uuid)
RETURNS integer AS $$
DECLARE
  v_count integer;
BEGIN
  -- Count trades where user is either buyer or seller AND status is 'completed'
  SELECT COUNT(*)::integer INTO v_count
  FROM p2p_trades
  WHERE (buyer_id = p_user_id OR seller_id = p_user_id)
  AND status = 'completed'
  AND coins_released_at IS NOT NULL;
  
  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_completed_p2p_trades_count(uuid) TO authenticated;

-- Create an index for faster counting
CREATE INDEX IF NOT EXISTS idx_p2p_trades_completed_user 
ON p2p_trades(buyer_id, seller_id, status) 
WHERE status = 'completed';

-- Update transfer function to use the fixed counting logic
DROP FUNCTION IF EXISTS transfer_balance_to_user(uuid, uuid, numeric);

CREATE OR REPLACE FUNCTION transfer_balance_to_user(
  p_sender_id uuid,
  p_receiver_id uuid,
  p_amount numeric
)
RETURNS jsonb AS $$
DECLARE
  v_sender_balance numeric;
  v_receiver_exists boolean;
  v_trades_count integer;
  v_response jsonb;
BEGIN
  -- Check if receiver exists
  SELECT EXISTS(SELECT 1 FROM profiles WHERE id = p_receiver_id)
  INTO v_receiver_exists;
  
  IF NOT v_receiver_exists THEN
    v_response := jsonb_build_object(
      'success', false,
      'error', 'Receiver does not exist'
    );
    RETURN v_response;
  END IF;

  -- Check if sender and receiver are different
  IF p_sender_id = p_receiver_id THEN
    v_response := jsonb_build_object(
      'success', false,
      'error', 'Cannot transfer to yourself'
    );
    RETURN v_response;
  END IF;

  -- Check minimum amount (10 AFX)
  IF p_amount < 10 THEN
    v_response := jsonb_build_object(
      'success', false,
      'error', 'Minimum transfer amount is 10 AFX'
    );
    RETURN v_response;
  END IF;

  -- Check if sender has completed at least 5 P2P trades
  v_trades_count := get_completed_p2p_trades_count(p_sender_id);
  IF v_trades_count < 5 THEN
    v_response := jsonb_build_object(
      'success', false,
      'error', format('You must complete at least 5 P2P trades before transferring. Current: %s/5', v_trades_count)
    );
    RETURN v_response;
  END IF;

  -- Get sender's dashboard balance
  SELECT amount INTO v_sender_balance
  FROM coins
  WHERE user_id = p_sender_id AND claim_type = 'dashboard' AND status = 'unlocked'
  LIMIT 1;

  IF v_sender_balance IS NULL OR v_sender_balance = 0 THEN
    v_response := jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance for transfer'
    );
    RETURN v_response;
  END IF;

  IF v_sender_balance < p_amount THEN
    v_response := jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Available: %s AFX', v_sender_balance)
    );
    RETURN v_response;
  END IF;

  -- Begin transaction: deduct from sender
  UPDATE coins
  SET amount = amount - p_amount,
      updated_at = now()
  WHERE user_id = p_sender_id AND claim_type = 'dashboard' AND status = 'unlocked'
  LIMIT 1;

  -- Add to receiver's dashboard balance
  INSERT INTO coins (user_id, amount, claim_type, status, created_at, updated_at)
  VALUES (p_receiver_id, p_amount, 'dashboard', 'unlocked', now(), now())
  ON CONFLICT DO NOTHING;

  -- If insert failed (receiver already has a record), update instead
  UPDATE coins
  SET amount = amount + p_amount,
      updated_at = now()
  WHERE user_id = p_receiver_id AND claim_type = 'dashboard' AND status = 'unlocked';

  -- Record the transfer
  INSERT INTO user_to_user_transfers (sender_id, receiver_id, amount, description)
  VALUES (p_sender_id, p_receiver_id, p_amount, 'User-to-user balance transfer');

  -- Record transactions for both users
  INSERT INTO transactions (user_id, type, amount, description, status)
  VALUES 
    (p_sender_id, 'transfer_out', p_amount, 'Transferred to user', 'completed'),
    (p_receiver_id, 'transfer_in', p_amount, 'Received from user', 'completed');

  v_response := jsonb_build_object(
    'success', true,
    'message', 'Transfer completed successfully',
    'amount', p_amount,
    'receiver_id', p_receiver_id
  );

  RETURN v_response;
EXCEPTION WHEN OTHERS THEN
  v_response := jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
  RETURN v_response;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION transfer_balance_to_user(uuid, uuid, numeric) TO authenticated;
