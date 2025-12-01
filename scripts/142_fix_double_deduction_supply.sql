-- Fix double deduction issue by removing the trigger
-- The deduction is already handled in the deduct_from_global_supply function

DROP TRIGGER IF EXISTS trigger_update_global_supply ON coins;
DROP FUNCTION IF EXISTS update_global_supply_on_mining();

-- Verify the function is working correctly
-- This function is called explicitly in the mining action, so no trigger is needed
