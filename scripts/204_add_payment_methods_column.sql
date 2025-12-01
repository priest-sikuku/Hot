-- Add payment_methods_selected column to store selected payment methods as JSONB
ALTER TABLE public.p2p_ads
ADD COLUMN IF NOT EXISTS payment_methods_selected JSONB DEFAULT '[]'::jsonb;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_p2p_ads_payment_methods ON public.p2p_ads USING GIN (payment_methods_selected);

-- Update existing ads to have empty array if null
UPDATE public.p2p_ads 
SET payment_methods_selected = '[]'::jsonb 
WHERE payment_methods_selected IS NULL;

-- Fetch payment methods for an ad (works for both buy and sell ads)
CREATE OR REPLACE FUNCTION get_p2p_ad_payment_methods(p_ad_id UUID)
RETURNS TABLE (method_name TEXT, method_code TEXT) AS $$
DECLARE
  v_ad RECORD;
BEGIN
  SELECT * INTO v_ad FROM public.p2p_ads WHERE id = p_ad_id;
  
  IF v_ad IS NULL THEN
    RETURN;
  END IF;
  
  -- Check payment_methods_selected JSONB first (for buy ads and new sell ads)
  IF v_ad.payment_methods_selected != '[]'::jsonb THEN
    RETURN QUERY
    SELECT 
      CASE 
        WHEN method->>'code' = 'mpesa' THEN 'M-Pesa (Personal)'
        WHEN method->>'code' = 'mpesa_paybill' THEN 'M-Pesa Paybill'
        WHEN method->>'code' = 'bank_transfer' THEN 'Bank Transfer'
        WHEN method->>'code' = 'airtel_money' THEN 'Airtel Money'
        ELSE method->>'name'
      END as method_name,
      method->>'code' as method_code
    FROM jsonb_array_elements(v_ad.payment_methods_selected) as method;
  ELSE
    -- Fallback to individual payment method columns (for legacy ads)
    IF v_ad.mpesa_number IS NOT NULL AND v_ad.mpesa_number != '' THEN
      RETURN QUERY SELECT 'M-Pesa (Personal)'::TEXT, 'mpesa'::TEXT;
    END IF;
    
    IF v_ad.paybill_number IS NOT NULL AND v_ad.paybill_number != '' THEN
      RETURN QUERY SELECT 'M-Pesa Paybill'::TEXT, 'mpesa_paybill'::TEXT;
    END IF;
    
    IF v_ad.airtel_money IS NOT NULL AND v_ad.airtel_money != '' THEN
      RETURN QUERY SELECT 'Airtel Money'::TEXT, 'airtel_money'::TEXT;
    END IF;
    
    IF v_ad.account_number IS NOT NULL AND v_ad.account_number != '' THEN
      RETURN QUERY SELECT 'Bank Transfer'::TEXT, 'bank_transfer'::TEXT;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- View to get all ads with their payment methods
CREATE OR REPLACE VIEW p2p_ads_with_payment_methods AS
SELECT 
  pa.id,
  pa.user_id,
  pa.ad_type,
  pa.afx_amount,
  pa.remaining_amount,
  pa.price_per_afx,
  pa.min_amount,
  pa.max_amount,
  pa.mpesa_number,
  pa.paybill_number,
  pa.airtel_money,
  pa.account_number,
  pa.payment_methods_selected,
  pa.terms_of_trade,
  pa.status,
  pa.created_at,
  pa.expires_at,
  (
    SELECT jsonb_agg(jsonb_build_object('name', method_name, 'code', method_code))
    FROM get_p2p_ad_payment_methods(pa.id)
  ) as payment_methods
FROM public.p2p_ads pa;
