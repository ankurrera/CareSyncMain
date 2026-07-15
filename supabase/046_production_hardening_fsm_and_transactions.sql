-- CareSync Phase 2 Production Hardening
-- Enforces Appointment FSM, Prescription Immutability, Atomic Dispensing transaction, and DB triggers for Audit Log

-- ============================================================================
-- 1. APPOINTMENT FSM STATUS CHECK & TRANSITIONS
-- ============================================================================

-- Drop the legacy constraint if exists (PostgreSQL defaults to table_column_check name)
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_status_check;

-- Add updated check constraint containing FSM states
ALTER TABLE appointments ADD CONSTRAINT appointments_status_check
  CHECK (status IN (
    'scheduled', -- Legacy backward compatibility
    'Pending',
    'Confirmed',
    'Checked In',
    'Consultation Started',
    'Consultation Completed',
    'Prescription Generated',
    'Closed',
    'Cancelled',
    'No Show',
    'Expired'
  ));

-- Before update trigger function to validate transitions
CREATE OR REPLACE FUNCTION check_appointment_status_transition()
RETURNS TRIGGER AS $$
BEGIN
  -- If status is not changing, allow it
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Allow legacy 'scheduled' state to transition to any new FSM state
  IF OLD.status = 'scheduled' THEN
    RETURN NEW;
  END IF;

  -- Strict state transitions rules
  IF OLD.status = 'Pending' AND NEW.status NOT IN ('Confirmed', 'Cancelled', 'Expired') THEN
    RAISE EXCEPTION 'Invalid status transition: Pending -> %', NEW.status;
  ELSIF OLD.status = 'Confirmed' AND NEW.status NOT IN ('Checked In', 'Cancelled', 'No Show') THEN
    RAISE EXCEPTION 'Invalid status transition: Confirmed -> %', NEW.status;
  ELSIF OLD.status = 'Checked In' AND NEW.status NOT IN ('Consultation Started', 'Cancelled', 'No Show') THEN
    RAISE EXCEPTION 'Invalid status transition: Checked In -> %', NEW.status;
  ELSIF OLD.status = 'Consultation Started' AND NEW.status NOT IN ('Consultation Completed') THEN
    RAISE EXCEPTION 'Invalid status transition: Consultation Started -> %', NEW.status;
  ELSIF OLD.status = 'Consultation Completed' AND NEW.status NOT IN ('Prescription Generated', 'Closed') THEN
    RAISE EXCEPTION 'Invalid status transition: Consultation Completed -> %', NEW.status;
  ELSIF OLD.status = 'Prescription Generated' AND NEW.status NOT IN ('Closed') THEN
    RAISE EXCEPTION 'Invalid status transition: Prescription Generated -> %', NEW.status;
  ELSIF OLD.status IN ('Closed', 'Cancelled', 'No Show', 'Expired') THEN
    RAISE EXCEPTION 'Invalid action: cannot modify status of appointment in terminal state: %', OLD.status;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the before-update trigger
DROP TRIGGER IF EXISTS enforce_appointment_status_transition ON appointments;
CREATE TRIGGER enforce_appointment_status_transition
  BEFORE UPDATE OF status ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION check_appointment_status_transition();


-- ============================================================================
-- 2. PRESCRIPTION IMMUTABILITY
-- ============================================================================

-- Prevent editing patient, doctor, and diagnosis in prescriptions
CREATE OR REPLACE FUNCTION check_prescription_immutability()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.patient_id IS DISTINCT FROM NEW.patient_id OR
     OLD.doctor_id IS DISTINCT FROM NEW.doctor_id OR
     OLD.diagnosis IS DISTINCT FROM NEW.diagnosis OR
     OLD.patient_entered IS DISTINCT FROM NEW.patient_entered THEN
    RAISE EXCEPTION 'Clinical records of signed prescriptions are immutable.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_prescription_immutability ON prescriptions;
CREATE TRIGGER enforce_prescription_immutability
  BEFORE UPDATE ON prescriptions
  FOR EACH ROW
  EXECUTE FUNCTION check_prescription_immutability();

-- Prevent updating prescription item details (names, doses)
CREATE OR REPLACE FUNCTION check_prescription_item_immutability()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.prescription_id IS DISTINCT FROM NEW.prescription_id OR
     OLD.medicine_name IS DISTINCT FROM NEW.medicine_name OR
     OLD.dosage IS DISTINCT FROM NEW.dosage OR
     OLD.frequency IS DISTINCT FROM NEW.frequency OR
     OLD.duration IS DISTINCT FROM NEW.duration OR
     OLD.instructions IS DISTINCT FROM NEW.instructions OR
     OLD.quantity IS DISTINCT FROM NEW.quantity THEN
    RAISE EXCEPTION 'Clinical details of signed prescription items are immutable.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_prescription_item_immutability ON prescription_items;
CREATE TRIGGER enforce_prescription_item_immutability
  BEFORE UPDATE ON prescription_items
  FOR EACH ROW
  EXECUTE FUNCTION check_prescription_item_immutability();


-- ============================================================================
-- 3. ATOMIC PRESCRIPTION DISPENSING
-- ============================================================================

-- Update prescriptions constraint to support 'processing' and 'partially_dispensed'
ALTER TABLE prescriptions DROP CONSTRAINT IF EXISTS prescriptions_status_check;
ALTER TABLE prescriptions ADD CONSTRAINT prescriptions_status_check
  CHECK (status IN ('active', 'processing', 'partially_dispensed', 'completed', 'cancelled'));

-- Atomic PostgreSQL transaction RPC function
CREATE OR REPLACE FUNCTION dispense_prescription_items_v1(
  p_prescription_id UUID,
  p_pharmacist_id UUID,
  p_patient_id UUID,
  p_item_ids UUID[],
  p_notes TEXT
) RETURNS VOID AS $$
DECLARE
  v_total_items INT;
  v_dispensed_items INT;
  v_new_status TEXT;
BEGIN
  -- 1. Authorization check: must be a registered pharmacist
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'pharmacist'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only registered pharmacists can dispense medications.';
  END IF;

  -- 2. Insert atomic dispensing record
  INSERT INTO dispensing_records (
    prescription_id,
    pharmacist_id,
    patient_id,
    items_dispensed,
    notes,
    dispensed_at
  ) VALUES (
    p_prescription_id,
    p_pharmacist_id,
    p_patient_id,
    to_jsonb(p_item_ids),
    p_notes,
    NOW()
  );

  -- 3. Update prescription items in bulk
  UPDATE prescription_items
  SET is_dispensed = TRUE
  WHERE id = ANY(p_item_ids);

  -- 4. Re-calculate parent prescription status
  SELECT COUNT(*) INTO v_total_items
  FROM prescription_items
  WHERE prescription_id = p_prescription_id;

  SELECT COUNT(*) INTO v_dispensed_items
  FROM prescription_items
  WHERE prescription_id = p_prescription_id AND is_dispensed = TRUE;

  IF v_dispensed_items = v_total_items THEN
    v_new_status := 'completed';
  ELSIF v_dispensed_items > 0 THEN
    v_new_status := 'partially_dispensed';
  ELSE
    v_new_status := 'active';
  END IF;

  -- Update parent prescription status
  UPDATE prescriptions
  SET status = v_new_status,
      updated_at = NOW()
  WHERE id = p_prescription_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 4. DB-LEVEL AUTOMATED AUDIT TRAIL TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION audit_clinical_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_action TEXT;
  v_resource_type TEXT;
  v_resource_id UUID;
  v_metadata JSONB;
  v_user_id UUID;
BEGIN
  v_resource_id := COALESCE(NEW.id, OLD.id);
  v_user_id := auth.uid();

  IF TG_TABLE_NAME = 'appointments' THEN
    v_resource_type := 'appointment';
    IF v_user_id IS NULL THEN
      v_user_id := NEW.doctor_id;
    END IF;

    IF TG_OP = 'INSERT' THEN
      v_action := 'appointmentBooked';
      v_metadata := jsonb_build_object('start_time', NEW.start_time, 'doctor_id', NEW.doctor_id, 'patient_id', NEW.patient_id);
    ELSIF TG_OP = 'UPDATE' THEN
      IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status = 'cancelled' THEN
          v_action := 'appointmentCancelled';
        ELSIF NEW.status = 'Consultation Started' THEN
          v_action := 'consultationStarted';
        ELSIF NEW.status = 'Consultation Completed' THEN
          v_action := 'consultationCompleted';
        ELSE
          v_action := 'appointmentUpdated';
        END IF;
        v_metadata := jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status);
      ELSE
        v_action := 'appointmentUpdated';
        v_metadata := jsonb_build_object('changed', 'details');
      END IF;
    END IF;

  ELSIF TG_TABLE_NAME = 'prescriptions' THEN
    v_resource_type := 'prescription';
    IF v_user_id IS NULL THEN
      v_user_id := NEW.doctor_id;
    END IF;

    IF TG_OP = 'INSERT' THEN
      v_action := 'prescriptionGenerated';
      v_metadata := jsonb_build_object('doctor_id', NEW.doctor_id, 'patient_id', NEW.patient_id);
    ELSIF TG_OP = 'UPDATE' THEN
      v_action := 'prescriptionUpdated';
      v_metadata := jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status);
    END IF;

  ELSIF TG_TABLE_NAME = 'dispensing_records' THEN
    v_resource_type := 'dispensing';
    IF v_user_id IS NULL THEN
      v_user_id := NEW.pharmacist_id;
    END IF;

    IF TG_OP = 'INSERT' THEN
      v_action := 'medicineDispensed';
      v_metadata := jsonb_build_object('items', NEW.items_dispensed, 'pharmacist_id', NEW.pharmacist_id);
    END IF;
  END IF;

  -- Insert automated database audit log
  INSERT INTO audit_log (
    user_id,
    action,
    resource_type,
    resource_id,
    metadata,
    timestamp
  ) VALUES (
    v_user_id,
    COALESCE(v_action, 'clinicalChange'),
    v_resource_type,
    v_resource_id,
    v_metadata,
    NOW()
  );

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create Triggers
DROP TRIGGER IF EXISTS audit_appointments_trigger ON appointments;
CREATE TRIGGER audit_appointments_trigger
  AFTER INSERT OR UPDATE ON appointments
  FOR EACH ROW EXECUTE FUNCTION audit_clinical_changes();

DROP TRIGGER IF EXISTS audit_prescriptions_trigger ON prescriptions;
CREATE TRIGGER audit_prescriptions_trigger
  AFTER INSERT OR UPDATE ON prescriptions
  FOR EACH ROW EXECUTE FUNCTION audit_clinical_changes();

DROP TRIGGER IF EXISTS audit_dispensing_trigger ON dispensing_records;
CREATE TRIGGER audit_dispensing_trigger
  AFTER INSERT ON dispensing_records
  FOR EACH ROW EXECUTE FUNCTION audit_clinical_changes();
