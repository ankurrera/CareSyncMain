-- Migration 040: Add emergency vitals read policy for authenticated users (first responders)
DROP POLICY IF EXISTS "First responders can view vitals in emergency" ON vitals;
CREATE POLICY "First responders can view vitals in emergency"
    ON vitals FOR SELECT
    TO authenticated
    USING (true);
