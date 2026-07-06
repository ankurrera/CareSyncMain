-- ============================================================================
-- UPDATE MEDICAL CONDITIONS SEVERITY CHECK CONSTRAINT
-- Adds 'low' to allow compatibility for both old ('low') and new ('mild') UI values.
-- ============================================================================

-- 1. Drop the existing severity check constraint
ALTER TABLE medical_conditions 
DROP CONSTRAINT IF EXISTS medical_conditions_severity_check;

-- 2. Create the updated constraint including both 'low' and 'mild'
ALTER TABLE medical_conditions 
ADD CONSTRAINT medical_conditions_severity_check 
CHECK (severity IN ('low', 'mild', 'moderate', 'severe', 'critical'));
