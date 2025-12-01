-- =====================================================
-- DYNAMIC PRICE SYSTEM WITH GUARANTEED +1 KES DAILY
-- =====================================================
-- Modifies the price system to ensure +1 KES increase daily
-- while allowing dynamic fluctuations throughout the day

-- Create a table to track daily price targets and progress
CREATE TABLE IF NOT EXISTS daily_price_targets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reference_date DATE NOT NULL UNIQUE,
    opening_price_kes NUMERIC(10, 4) NOT NULL,
    target_price_kes NUMERIC(10, 4) NOT NULL,
    closing_price_kes NUMERIC(10, 4),
    reset_time TIMESTAMPTZ DEFAULT '15:00:00 UTC',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_targets_date ON daily_price_targets(reference_date DESC);

-- Enable RLS
ALTER TABLE daily_price_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read price targets" ON daily_price_targets;
CREATE POLICY "Anyone can read price targets"
ON daily_price_targets FOR SELECT
USING (true);

-- Function to get or create today's price target
CREATE OR REPLACE FUNCTION get_daily_price_target()
RETURNS TABLE (
    reference_date DATE,
    opening_price_kes NUMERIC,
    target_price_kes NUMERIC,
    current_progress NUMERIC
) AS $$
DECLARE
    v_current_date DATE;
    v_current_hour INTEGER;
    v_opening_price NUMERIC;
    v_target_price NUMERIC;
    v_last_closing_price NUMERIC;
BEGIN
    -- Get current date and hour in UTC
    v_current_date := CURRENT_DATE;
    v_current_hour := EXTRACT(HOUR FROM NOW() AT TIME ZONE 'UTC');

    -- Check if we have a target for today
    SELECT dt.opening_price_kes, dt.target_price_kes
    INTO v_opening_price, v_target_price
    FROM daily_price_targets dt
    WHERE dt.reference_date = v_current_date;

    -- If no target exists, create one
    IF v_opening_price IS NULL THEN
        -- Get yesterday's closing price (or last available price)
        SELECT dt.closing_price_kes
        INTO v_last_closing_price
        FROM daily_price_targets dt
        WHERE dt.reference_date < v_current_date
        ORDER BY dt.reference_date DESC
        LIMIT 1;

        -- If no history, get latest tick
        IF v_last_closing_price IS NULL THEN
            SELECT ct.price
            INTO v_last_closing_price
            FROM coin_ticks ct
            ORDER BY ct.tick_timestamp DESC
            LIMIT 1;
        END IF;

        -- Default to 13 KES if nothing found
        v_opening_price := COALESCE(v_last_closing_price, 13.00);
        
        -- Target is opening + 1 KES
        v_target_price := v_opening_price + 1.00;

        -- Insert new target
        INSERT INTO daily_price_targets (
            reference_date,
            opening_price_kes,
            target_price_kes,
            reset_time
        ) VALUES (
            v_current_date,
            v_opening_price,
            v_target_price,
            (v_current_date || ' 15:00:00 UTC')::TIMESTAMPTZ
        );
    END IF;

    -- Calculate current progress through the day (0 to 1)
    -- Progress starts at 3pm UTC (15:00)
    DECLARE
        v_minutes_since_reset INTEGER;
        v_progress_ratio NUMERIC;
    BEGIN
        IF v_current_hour >= 15 THEN
            v_minutes_since_reset := (v_current_hour - 15) * 60 + EXTRACT(MINUTE FROM NOW());
        ELSE
            v_minutes_since_reset := (24 - 15 + v_current_hour) * 60 + EXTRACT(MINUTE FROM NOW());
        END IF;

        v_progress_ratio := v_minutes_since_reset::NUMERIC / (24.0 * 60.0);

        RETURN QUERY SELECT 
            v_current_date,
            v_opening_price,
            v_target_price,
            v_progress_ratio;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update closing price at day end
CREATE OR REPLACE FUNCTION update_daily_closing_price()
RETURNS VOID AS $$
DECLARE
    v_yesterday DATE;
    v_closing_price NUMERIC;
BEGIN
    v_yesterday := CURRENT_DATE - INTERVAL '1 day';

    -- Get the last tick from yesterday
    SELECT ct.price
    INTO v_closing_price
    FROM coin_ticks ct
    WHERE DATE(ct.tick_timestamp AT TIME ZONE 'UTC') = v_yesterday
    ORDER BY ct.tick_timestamp DESC
    LIMIT 1;

    -- Update yesterday's closing price
    IF v_closing_price IS NOT NULL THEN
        UPDATE daily_price_targets
        SET 
            closing_price_kes = v_closing_price,
            updated_at = NOW()
        WHERE reference_date = v_yesterday
        AND closing_price_kes IS NULL;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_daily_price_target() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_daily_closing_price() TO authenticated;

COMMENT ON TABLE daily_price_targets IS 'Tracks daily price targets to ensure +1 KES increase per day';
COMMENT ON FUNCTION get_daily_price_target IS 'Returns current day price target and progress ratio';
COMMENT ON FUNCTION update_daily_closing_price IS 'Updates previous day closing price for accurate tracking';
