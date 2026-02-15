# Git Workflow

## Branching Strategy

All work branches are created from `main`. All PRs target `main`. There are no long-lived feature branches, no develop branch, no staging branch.

```
main
  |
  +-- foundation/setup         (Agent 0)
  +-- feature/backend-services  (Agent 1)
  +-- feature/mobile-app        (Agent 2)
  +-- feature/web-dashboard     (Agent 3)
  +-- feature/integration-tests (Agent 4)
```

---

## Branch Naming Convention

Each agent has exactly one branch. No deviations allowed.

| Agent | Branch | Created From |
|-------|--------|-------------|
| Agent 0 (Foundation) | `foundation/setup` | `main` |
| Agent 1 (Backend) | `feature/backend-services` | `main` (after Agent 0 merges) |
| Agent 2 (Mobile) | `feature/mobile-app` | `main` (after Agent 0 merges) |
| Agent 3 (Web Dashboard) | `feature/web-dashboard` | `main` (after Agent 0 merges) |
| Agent 4 (Integration) | `feature/integration-tests` | `main` (after Agents 1-3 merge) |

---

## One PR Per Agent

Each agent creates exactly one PR targeting `main`. The PR contains all of that agent's work.

- Agent 0: Foundation setup (monorepo, shared package, migrations, docs, CI)
- Agent 1: Backend services (Edge Functions, triggers, RLS policies)
- Agent 2: Mobile app (full Flutter mobile app with offline support)
- Agent 3: Web dashboard (Flutter web admin dashboard)
- Agent 4: Integration tests (E2E test scenarios)

---

## PR Review Process

Every PR is reviewed by **5 independent review agents**.

1. The work agent creates a PR and requests review.
2. All 5 review agents independently evaluate the PR against the **full review checklist** (see `pr-review.md`).
3. Each review agent produces a pass/fail verdict with specific findings.
4. **All 5 review agents must pass** for the PR to be merged.
5. If any review agent fails, the work agent addresses all findings and re-requests review.
6. Re-review evaluates the entire PR again.

---

## Merge Order

PRs must be merged in this order to avoid conflicts:

### Phase 1: Foundation (Sequential)

```
Agent 0 (foundation/setup) -> merge to main
```

Agent 0 must merge first. Agents 1-3 cannot start until Agent 0's PR is merged, because they depend on the shared package, database schema, and project configuration.

### Phase 2: Feature Development (Parallel Work, Sequential Merge)

```
Agent 1 (feature/backend-services) -> merge to main  (recommended first)
Agent 2 (feature/mobile-app)       -> merge to main
Agent 3 (feature/web-dashboard)    -> merge to main
```

Agents 1, 2, and 3 work in parallel but merge sequentially. Recommended merge order:
1. **Agent 1 (Backend) first** -- Backend services have no client dependencies, and later agents' integration tests may need backend in place.
2. **Agent 2 (Mobile) second** -- Core app functionality.
3. **Agent 3 (Web) third** -- Dashboard depends on backend being stable.

If an agent merges before another and creates conflicts, the later agent must rebase onto the updated `main` and resolve conflicts before merging.

### Phase 3: Integration (Sequential)

```
Agent 4 (feature/integration-tests) -> merge to main
```

Agent 4 starts only after all Phase 2 PRs are merged, since integration tests exercise the full system.

---

## Merge Strategy

**Squash merge preferred.** Each agent's PR becomes a single commit on `main`.

```bash
# GitHub merge button: "Squash and merge"
# The squash commit message should follow conventional commits format:
# feat(shared): add foundation package with models, migrations, and CI
```

If a PR has logically distinct pieces that benefit from separate commits on main, regular merge is acceptable. But squash merge is the default.

---

## Rules

### No Force Pushes

Force pushing is prohibited on all branches, especially `main`. If you need to fix a commit, create a new commit.

```bash
# Forbidden
git push --force
git push --force-with-lease

# Allowed: add a fix commit
git commit -m "fix(shared): correct plate regex pattern"
git push
```

### Atomic Commits

Each commit within a PR should be atomic and buildable. The project must compile and pass `dart analyze` after every commit.

### No Cross-Agent File Modifications

Do not modify files owned by another agent. If you discover a bug in another agent's code:
1. Document the issue in a comment on their PR or as a separate issue.
2. Do not fix it yourself unless coordinated.

### Rebase Before Merge

Before merging, ensure your branch is up to date with `main`:

```bash
git fetch origin
git rebase origin/main
# Resolve any conflicts
git push
```

### Clean History

- No merge commits from pulling `main` into your branch. Use rebase.
- No WIP commits in the final PR. Squash or amend before requesting review.
- Commit messages must follow conventional commit format (see `pr-creation.md`).

---

## Coordination

### Dependency Signals

- Agent 0 signals completion by merging their PR to `main`.
- Agents 1, 2, 3 should watch for Agent 0's merge before creating their branches.
- Agent 4 should watch for all Phase 2 merges before starting.

### Shared Package Changes

If an agent needs to modify something in `packages/shared/` (which is owned by Agent 0):
- Prefer adding new files rather than modifying existing ones to minimize conflicts.
- If modification is necessary, document the change and the reason in the PR description.
- The review agents will check for correctness.

### Conflict Resolution

If two agents modify the same file:
1. The agent merging second must rebase and resolve conflicts.
2. After resolving, re-request review from all 5 review agents.
3. The conflict resolution must not break any existing tests.
