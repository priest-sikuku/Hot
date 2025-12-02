-- Create user_to_user_transfers table for tracking internal balance transfers
CREATE TABLE IF NOT EXISTS user_to_user_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount numeric NOT NULL CHECK (amount >= 10),
  created_at timestamp with time zone DEFAULT now(),
  status text DEFAULT 'completed',
  description text
);

-- Enable RLS for user_to_user_transfers
ALTER TABLE user_to_user_transfers ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_to_user_transfers
CREATE POLICY "users_can_view_own_transfers"
  ON user_to_user_transfers
  FOR SELECT
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "users_can_insert_transfers"
  ON user_to_user_transfers
  FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- Create function to count user's completed P2P trades
CREATE OR REPLACE FUNCTION get_completed_p2p_trades_count(p_user_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM p2p_trades
    WHERE (buyer_id = p_user_id OR seller_id = p_user_id)
    AND status = 'completed'
  );
END;
$$ LANGUAGE plpgsql;

-- Create function for user-to-user balance transfer
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
    RAISE EXCEPTION 'Receiver does not exist';
  END IF;

  -- Check if sender and receiver are different
  IF p_sender_id = p_receiver_id THEN
    RAISE EXCEPTION 'Cannot transfer to yourself';
  END IF;

  -- Check minimum amount (10 AFX)
  IF p_amount < 10 THEN
    RAISE EXCEPTION 'Minimum transfer amount is 10 AFX';
  END IF;

  -- Check if sender has completed at least 5 P2P trades
  v_trades_count := get_completed_p2p_trades_count(p_sender_id);
  IF v_trades_count < 5 THEN
    RAISE EXCEPTION 'You must complete at least 5 P2P trades before transferring';
  END IF;

  -- Get sender's dashboard balance
  SELECT amount INTO v_sender_balance
  FROM coins
  WHERE user_id = p_sender_id AND claim_type = 'dashboard' AND status = 'unlocked'
  LIMIT 1;

  IF v_sender_balance IS NULL OR v_sender_balance = 0 THEN
    RAISE EXCEPTION 'Insufficient balance for transfer';
  END IF;

  IF v_sender_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance for transfer';
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
$$ LANGUAGE plpgsql;
