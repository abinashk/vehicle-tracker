# PR Creation Guidelines

## Branch Naming

Each agent uses a fixed branch name. No deviations allowed.

| Agent | Branch Name |
|-------|-------------|
| Agent 0 (Foundation) | `foundation/setup` |
| Agent 1 (Backend) | `feature/backend-services` |
| Agent 2 (Mobile) | `feature/mobile-app` |
| Agent 3 (Web Dashboard) | `feature/web-dashboard` |
| Agent 4 (Integration Tests) | `feature/integration-tests` |

All branches are created from `main`. All PRs target `main`.

---

## Commit Message Format

Use **conventional commits**. Every commit message must follow this format:

```
<type>(<scope>): <short description>

[optional body]
```

### Types

| Type | When to Use |
|------|-------------|
| `feat` | New functionality (model, screen, endpoint, migration) |
| `fix` | Bug fix |
| `docs` | Documentation only (guidelines, architecture docs, README) |
| `test` | Adding or updating tests only |
| `chore` | Build config, CI, dependency updates, tooling |
| `refactor` | Code restructuring with no behavior change |

### Scope

Use the package or area name: `shared`, `mobile`, `web`, `supabase`, `ci`, `docs`.

### Examples

```
feat(shared): add PlateNormalizer with Devanagari transliteration
fix(mobile): handle null plate_number_raw in passage form
test(shared): add SpeedCalculator boundary condition tests
docs(guidelines): create PR creation guidelines
chore(ci): add ci-shared.yml workflow for shared package
```

### Rules

- Subject line must be 72 characters or fewer.
- Use imperative mood ("add", "fix", "update" -- not "added", "fixes", "updated").
- Do not end the subject line with a period.
- Each commit should be atomic and buildable. The project must compile after every commit.

---

## PR Description Template

Every PR must use this template. Copy it into the PR body.

```markdown
## Summary

[1-3 sentences describing what this PR delivers and why.]

## Changes

- [Bullet list of significant changes]
- [Group by area: models, migrations, screens, tests, etc.]

## Testing

- [ ] Unit tests added/updated for all new business logic
- [ ] Widget tests added/updated for all new screens
- [ ] `dart analyze` passes with zero issues
- [ ] `dart test` passes for all affected packages
- [ ] Manual testing steps (if applicable):
  1. [Step 1]
  2. [Step 2]

## Checklist

- [ ] Branch name matches agent assignment
- [ ] All commits follow conventional commit format
- [ ] No hardcoded secrets or credentials
- [ ] No TODO/FIXME without a linked issue
- [ ] New public methods have at least one test
- [ ] Code follows project coding standards (see coding-standards.md)
- [ ] Offline-first rules followed (see offline-first.md)
- [ ] Security rules followed (see security.md)
```

---

## What Every PR Must Include

1. **Tests for new functionality.** A PR that adds code without corresponding tests will be rejected. This is non-negotiable.
2. **Zero analyzer warnings.** Run `dart analyze` on all affected packages before submitting.
3. **Passing CI.** All GitHub Actions workflows must pass.
4. **Only files within your agent's ownership.** Do not modify files owned by another agent. If you need a change in another agent's area, document the dependency and coordinate.

---

## PR Size

- Keep PRs focused. One PR per agent, targeting `main`.
- If a PR exceeds 2000 lines of diff, consider whether all changes are necessary and tightly related.
- Prefer smaller, well-scoped commits within the PR.
