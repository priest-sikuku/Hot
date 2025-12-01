-- Create function to update exchange rates (can be called via cron)
CREATE OR REPLACE FUNCTION update_afx_exchange_rates()
RETURNS TABLE(country_code VARCHAR, updated_price NUMERIC) AS $$
BEGIN
  -- This function updates exchange rates based on market conditions
  -- In production, this would integrate with an external price feed API
  
  RETURN QUERY
  INSERT INTO afx_exchange_rates (country_code, currency_code, afx_price_in_currency)
  SELECT 
    ac.code,
    ac.currency_code,
    -- Calculate price based on base KES price and exchange rate to KES
    (SELECT price FROM afx_current_price ORDER BY updated_at DESC LIMIT 1) * ac.exchange_rate_to_kes
  FROM african_countries ac
  WHERE ac.status = 'active'
  ON CONFLICT DO NOTHING
  RETURNING country_code, (SELECT price FROM afx_exchange_rates WHERE country_code = ac.code ORDER BY recorded_at DESC LIMIT 1);
END;
$$ LANGUAGE plpgsql;

-- Create view for getting current exchange rates
CREATE OR REPLACE VIEW v_country_current_prices AS
SELECT 
  ac.code as country_code,
  ac.name as country_name,
  ac.currency_code,
  ac.currency_symbol,
  COALESCE(aer.afx_price_in_currency, ac.exchange_rate_to_kes * (SELECT price FROM afx_current_price ORDER BY updated_at DESC LIMIT 1)) as current_price,
  aer.recorded_at
FROM african_countries ac
LEFT JOIN LATERAL (
  SELECT afx_price_in_currency, recorded_at
  FROM afx_exchange_rates
  WHERE country_code = ac.code
  ORDER BY recorded_at DESC
  LIMIT 1
) aer ON true
WHERE ac.status = 'active';

-- Grant permissions
GRANT SELECT ON v_country_current_prices TO authenticated;
GRANT SELECT ON v_country_current_prices TO anon;
