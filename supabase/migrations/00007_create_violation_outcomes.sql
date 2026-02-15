-- Migration: Create violation_outcomes table
-- Description: Records the outcome/resolution of a violation (fine, warning, etc.)

CREATE TABLE public.violation_outcomes (
    id              uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    violation_id    uuid          NOT NULL UNIQUE REFERENCES public.violations(id) ON DELETE CASCADE,
    outcome_type    text          NOT NULL CHECK (outcome_type IN (
                                      'warned', 'fined', 'let_go', 'not_found', 'other'
                                  )),
    fine_amount     numeric(10,2),
    notes           text,
    recorded_by     uuid          NOT NULL REFERENCES public.user_profiles(id) ON DELETE RESTRICT,
    recorded_at     timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.violation_outcomes IS 'Outcome/resolution of a detected violation';
COMMENT ON COLUMN public.violation_outcomes.outcome_type IS 'How the violation was resolved: warned, fined, let_go, not_found, or other';
COMMENT ON COLUMN public.violation_outcomes.fine_amount IS 'Amount of fine in local currency, if applicable';
COMMENT ON COLUMN public.violation_outcomes.recorded_by IS 'The ranger or admin who recorded the outcome';
