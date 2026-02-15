# PR Review Guidelines

## Review Structure

Every PR is reviewed by **5 independent review agents** (Review Agent 1 through Review Agent 5). Each agent evaluates the PR against the **full checklist** below. The purpose of 5 reviewers is redundancy -- multiple independent perspectives to catch issues any single reviewer might miss.

### Approval Criteria

- **All 5 review agents must pass** for a PR to be merged.
- If **any** agent fails the PR, the work agent must address all findings and re-request review.
- A re-review evaluates the entire PR again, not just the fixes.

---

## Full Review Checklist

Every review agent evaluates every item below. Check each item as pass/fail with specific evidence.

### Security

- [ ] Parameterized queries only (no string interpolation in SQL)
- [ ] RLS policies present and correct for every table accessed
- [ ] JWT validation in Edge Functions
- [ ] Twilio signature verification on SMS webhook
- [ ] No hardcoded secrets (env vars only)
- [ ] File type/size validation on uploads (JPEG/PNG only, 2MB max)
- [ ] CORS restricted to web dashboard domain

### Architecture Extensibility

- [ ] Multi-park queries (filter by park_id/segment_id, never assume single park)
- [ ] Schema accommodates future per-vehicle-type thresholds
- [ ] Localization-ready strings (keys, not hardcoded English)
- [ ] Vehicle type enum defined once in shared package
- [ ] Repository pattern enforced (no direct Supabase calls from UI)
- [ ] Providers scoped correctly (no tight coupling)

### Pattern Compliance

- [ ] Models use plain Dart classes with fromJson/toJson (no freezed)
- [ ] Riverpod providers use code generation (@riverpod)
- [ ] Drift tables use Drift DSL
- [ ] Typed exceptions (not generic catch)
- [ ] AsyncValue for async state in Riverpod
- [ ] snake_case.dart file naming
- [ ] Package imports (not relative across package boundaries)
- [ ] Arrange-Act-Assert test pattern

### Connectivity Resilience

- [ ] Every write goes to local Drift first, then sync queue (never direct to Supabase from UI)
- [ ] Every read falls back to local data if Supabase unreachable
- [ ] No unhandled HTTP exceptions
- [ ] No spinners waiting for network -- show local data immediately
- [ ] SMS fallback triggered correctly (not too eager, not too late)
- [ ] Realtime subscription reconnects after connectivity loss
- [ ] Photo upload non-blocking
- [ ] Graceful degradation: full online -> core offline -> SMS last resort

### Data Integrity

- [ ] client_id generated once, never regenerated on retry
- [ ] recorded_at = camera shutter moment (not submission time)
- [ ] Sync queue FIFO processing
- [ ] Lost response handling (409 on retry = success)
- [ ] Matching is idempotent (no duplicate violations)
- [ ] Violations snapshot threshold values at time of detection
- [ ] Overstay cron does not create duplicate proactive alerts
- [ ] All timestamps stored as UTC timestamptz, displayed in Nepal Time (UTC+5:45)

---

## How to Report Findings

### Comment Format

Every finding must include:

1. **Severity** -- one of:
   - `BLOCKER`: Must be fixed before merge. Violates a checklist item.
   - `WARNING`: Should be fixed. Potential issue but not a direct checklist violation.
   - `SUGGESTION`: Optional improvement. Does not block merge.

2. **Specific file and line reference.**

3. **Explanation of what is wrong and why.**

4. **Recommended fix** (when possible).

### Example Comments

```
BLOCKER: lib/data/remote/passage_remote_source.dart:42
Raw string interpolation used in Supabase query filter.
This violates the parameterized queries rule. Use Supabase
client's .eq() / .filter() methods instead of string building.

Fix: Replace `.rpc('query', params: {'filter': 'plate=$plate'})`
with `.from('vehicle_passages').select().eq('plate_number', plate)`
```

```
WARNING: lib/presentation/screens/capture/capture_screen.dart:108
Generic `catch (e)` used without typed exception handling.
Use specific exception types (e.g., CameraException, PlatformException).
```

```
SUGGESTION: lib/domain/usecases/record_passage.dart:25
Consider extracting the validation logic into a separate method
for testability.
```

---

## Review Verdict Format

Each review agent produces a structured verdict:

```
## Review Agent [N] Verdict

**Result: PASS / FAIL**

### Checklist Results
- Security: PASS / FAIL (list any failures)
- Architecture Extensibility: PASS / FAIL (list any failures)
- Pattern Compliance: PASS / FAIL (list any failures)
- Connectivity Resilience: PASS / FAIL (list any failures)
- Data Integrity: PASS / FAIL (list any failures)

### Findings
[List all BLOCKER, WARNING, and SUGGESTION comments]

### Summary
[1-3 sentences summarizing the review]
```

---

## Checklist Applicability

Not every checklist item applies to every PR. For example:

- A shared-package-only PR does not need Connectivity Resilience checks.
- A backend-only PR does not need Pattern Compliance checks for Dart/Flutter.
- A docs-only PR may pass all items trivially.

When an item is not applicable, mark it as `N/A` with a brief reason. An `N/A` item does not count as a failure.
