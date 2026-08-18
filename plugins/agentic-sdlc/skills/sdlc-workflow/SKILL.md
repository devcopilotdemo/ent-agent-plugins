---
name: sdlc-workflow
description: Run a feature, bug fix, or refactor through the agentic SDLC delivery loop - plan, design, build, verify, ship - with the right specialist agent owning each stage. Use when starting non-trivial work, or when you need to know which agent should handle a task.
---

# Agentic SDLC workflow

This skill describes the delivery loop the `agentic-sdlc` plugin implements, and how to route work through it.

## The loop

| Stage | Owner | Exit condition |
| --- | --- | --- |
| Plan | `ent-planner` | Every task has an owner, a testable acceptance criterion, and a GitHub issue it traces to |
| Design | `ent-designer` | Flow, component, and state specs exist for all user-facing change |
| Build | `ent-backend-developer`, `ent-frontend-developer` | Code lands on a dedicated branch, implements the criteria, and its tests pass locally |
| Verify | `ent-tester` | Automated tests cover every acceptance criterion and pass |
| Ship | `ent-devops` | GitHub Actions CI is green, a PR linking the issue is open, the change is deployable, and rollback is documented |

`ent-orchestrator` owns the loop itself: it delegates, checks exit conditions, and decides when to move between stages.

## Routing

Ask two questions to route a task:

1. **Is this decided yet?** If requirements, sequencing, or acceptance criteria are unclear, go to `ent-planner` first. If the user experience is undefined and the change is user-facing, go to `ent-designer` before implementation.
2. **Where does the change live?** Server, data, or integration work goes to `ent-backend-developer`. UI and client work goes to `ent-frontend-developer`. Pipelines, infrastructure, configuration, and release work goes to `ent-devops`. Verification always goes to `ent-tester`.

Skip stages only when they are genuinely inapplicable - a config-only change needs no design stage. Never skip verification.

## Gates

These are non-negotiable regardless of stage:

- **No acceptance criterion, no implementation.** Work that cannot be verified cannot be declared done.
- **No contract drift.** An API change lands together with its schema/spec update and its consumer updates.
- **No unverified completion.** Evidence means a passing test or a command output, not a plausible diff.
- **No work on the default branch.** Implementation lands on a dedicated branch and is delivered as a pull request, opened only after validation passes and linking its tracking issue.
- **No untraceable change.** Every plan maps to a GitHub issue, created or updated with the user's approval.
- **Fork is the default target.** Issues and pull requests go to the `origin` remote of the working repository, not the upstream parent. Resolve the target explicitly rather than letting `gh` fall back to upstream.
- **No secrets or personal data in the repository.** The plugin's `preToolUse` hook blocks commits containing detected secrets or PII, and `sessionEnd` hooks report anything that slipped through. Remediate findings; never bypass a hook.
- **Least privilege by default.** New credentials, tokens, roles, and permissions are scoped to the minimum needed and reviewed explicitly.

## Handoff format

When delegating, give the receiving agent everything it needs - it has no memory of the conversation:

```
Task: <what to do>
Context: <relevant files, prior decisions, constraints>
Branch: <working branch>
Repository: <owner/repo of the fork to target for issues and PRs>
Issue: <#n>
Acceptance criteria: <observable, verifiable outcome>
Out of scope: <what not to touch>
```

## Parallelization

`ent-orchestrator` groups tasks into waves from the plan's dependency graph and delegates each wave in a single batch. Two tasks belong in the same wave only when they touch disjoint files and share no undefined contract (API schema, migration, shared type, design token). Settle shared contracts in an earlier wave, then fan out the consumers. Serialize anything with a real dependency - migrations before the code that reads them, implementation before verification.

## Scanner controls

The secret and PII scanners are configured through environment variables:

| Variable | Values | Purpose |
| --- | --- | --- |
| `SCAN_MODE` | `warn`, `block` | Report findings, or fail on them |
| `SCAN_SCOPE` | `diff`, `staged` | Scan working-tree changes, or the staged index |
| `SCAN_ALLOWLIST` | comma-separated substrings | Suppress known false positives |
| `SKIP_SDLC_SCAN` | `true` | Disable scanning entirely - requires justification |

Prefer narrowing with `SCAN_ALLOWLIST` over disabling with `SKIP_SDLC_SCAN`.
