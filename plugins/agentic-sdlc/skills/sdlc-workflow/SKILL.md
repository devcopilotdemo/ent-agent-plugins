---
name: sdlc-workflow
description: Run a feature, bug fix, or refactor through the agentic SDLC delivery loop - plan, design, build, verify, ship - with the right specialist agent owning each stage. Use when starting non-trivial work, or when you need to know which agent should handle a task.
---

# Agentic SDLC workflow

This skill describes the delivery loop the `agentic-sdlc` plugin implements, and how to route work through it.

## The loop

| Stage | Owner | Exit condition |
| --- | --- | --- |
| Plan | `planner` | Every task has an owner and a testable acceptance criterion |
| Design | `designer` | Flow, component, and state specs exist for all user-facing change |
| Build | `backend-developer`, `frontend-developer` | Code implements the criteria and its tests pass locally |
| Verify | `tester` | Automated tests cover every acceptance criterion and pass |
| Ship | `devops` | CI is green, the change is deployable, and rollback is documented |

`orchestrator` owns the loop itself: it delegates, checks exit conditions, and decides when to move between stages.

## Routing

Ask two questions to route a task:

1. **Is this decided yet?** If requirements, sequencing, or acceptance criteria are unclear, go to `planner` first. If the user experience is undefined and the change is user-facing, go to `designer` before implementation.
2. **Where does the change live?** Server, data, or integration work goes to `backend-developer`. UI and client work goes to `frontend-developer`. Pipelines, infrastructure, configuration, and release work goes to `devops`. Verification always goes to `tester`.

Skip stages only when they are genuinely inapplicable - a config-only change needs no design stage. Never skip verification.

## Gates

These are non-negotiable regardless of stage:

- **No acceptance criterion, no implementation.** Work that cannot be verified cannot be declared done.
- **No contract drift.** An API change lands together with its schema/spec update and its consumer updates.
- **No unverified completion.** Evidence means a passing test or a command output, not a plausible diff.
- **No secrets or personal data in the repository.** The plugin's `preToolUse` hook blocks commits containing detected secrets or PII, and `sessionEnd` hooks report anything that slipped through. Remediate findings; never bypass a hook.
- **Least privilege by default.** New credentials, tokens, roles, and permissions are scoped to the minimum needed and reviewed explicitly.

## Handoff format

When delegating, give the receiving agent everything it needs - it has no memory of the conversation:

```
Task: <what to do>
Context: <relevant files, prior decisions, constraints>
Acceptance criteria: <observable, verifiable outcome>
Out of scope: <what not to touch>
```

## Scanner controls

The secret and PII scanners are configured through environment variables:

| Variable | Values | Purpose |
| --- | --- | --- |
| `SCAN_MODE` | `warn`, `block` | Report findings, or fail on them |
| `SCAN_SCOPE` | `diff`, `staged` | Scan working-tree changes, or the staged index |
| `SCAN_ALLOWLIST` | comma-separated substrings | Suppress known false positives |
| `SKIP_SDLC_SCAN` | `true` | Disable scanning entirely - requires justification |

Prefer narrowing with `SCAN_ALLOWLIST` over disabling with `SKIP_SDLC_SCAN`.
