# agentic-sdlc

A focused agentic SDLC delivery team for GitHub Copilot: seven specialist agents coordinated by ent-orchestrator, plus hooks that keep secrets and personal data out of the codebase.

Conforms to the [Agent Plugins Specification 1.0.0](https://github.com/agentplugins/agent-plugins-spec/blob/main/spec/1.0.0.md).

## Why

AI-assisted coding tends to be ad-hoc: a request goes in, a diff comes out, and nothing enforces that the work was planned, designed, verified, or safe to ship. `agentic-sdlc` wraps that loop in a lightweight engineering process — one agent per SDLC role, explicit acceptance criteria, and automated gates that fail loudly.

## Agents

| Agent | Role |
| --- | --- |
| `ent-orchestrator` | Coordinates the team, delegates work, enforces quality gates, drives delivery to verified completion |
| `ent-planner` | Turns a request into a sequenced plan with testable acceptance criteria and agent ownership |
| `ent-backend-developer` | APIs, services, business logic, data access, integrations — with tests |
| `ent-frontend-developer` | UI implementation, client state, data wiring, accessibility — with tests |
| `ent-designer` | UX flows, interaction specs, design-system-conformant component specifications |
| `ent-tester` | Test strategy and automated verification that acceptance criteria are actually met |
| `ent-devops` | CI/CD, infrastructure as code, configuration, secret management, release, observability |

Start with `ent-orchestrator` for any non-trivial change; invoke a specialist directly when the scope is already clear.

## Delivery conventions

- **Traceability.** `ent-planner` maps every plan to a GitHub issue and proposes creating or updating it — with your approval — before implementation starts.
- **Branch and PR by default.** Implementation never lands on the default branch. Developers and `ent-devops` work on a dedicated branch and open a pull request linking the tracking issue, only after validation passes.
- **GitHub Actions.** `ent-devops` assumes GitHub Actions in `.github/workflows/` as the default CI/CD system.
- **Parallel delegation.** `ent-orchestrator` groups plan tasks into waves and fans them out in parallel wherever files and contracts are disjoint.
- These agents use the GitHub MCP server (`github-mcp-server`) for issue and pull request operations.

## Hooks

Two scanners ship with the plugin. Both run cross-platform (Bash on Linux/macOS, PowerShell on Windows).

| Hook | Event | Default mode | Behavior |
| --- | --- | --- | --- |
| `guard-commit` | `preToolUse` | `block` | Scans the staged index before a `git commit` runs and **denies the commit** if secrets or PII are found |
| `scan-secrets` | `sessionEnd` | `warn` | Reports secrets in files changed during the session |
| `scan-pii` | `sessionEnd` | `warn` | Reports personal data in files changed during the session |

### What is detected

**Secrets** — AWS access/secret keys, GCP service accounts and API keys, Azure client secrets and storage keys, GitHub tokens (PAT, OAuth, app, refresh, fine-grained), private keys, generic assigned secrets and passwords, database connection strings, Slack tokens and webhooks, Stripe, SendGrid, Twilio, npm tokens, and JWTs.

**PII** — US Social Security numbers, credit card numbers, IBANs, passport and driver's licence numbers, email addresses, phone numbers, dates of birth, bank routing numbers, medical record numbers, and national/tax identifiers.

Findings are redacted in output — only the first and last three characters of a match are shown, and short matches are fully masked. Obvious placeholders (`example`, `your-key`, `changeme`, `@example.com`, and similar) are ignored.

### Configuration

| Variable | Values | Default | Purpose |
| --- | --- | --- | --- |
| `SCAN_MODE` | `warn`, `block` | `warn` (`block` for the commit guard) | Report findings, or fail on them |
| `SCAN_SCOPE` | `diff`, `staged` | `diff` (`staged` for the commit guard) | Scan working-tree changes, or the staged index |
| `SCAN_ALLOWLIST` | comma-separated substrings | unset | Suppress known false positives |
| `SKIP_SDLC_SCAN` | `true` | unset | Disable scanning entirely |

Prefer narrowing with `SCAN_ALLOWLIST` over disabling with `SKIP_SDLC_SCAN`.

> The scanners are a safety net, not a control. They reduce accidental exposure; they do not replace GitHub secret scanning, push protection, or a proper secret manager. If a real secret is detected, treat it as compromised and rotate it.

## Installation

```bash
copilot plugin marketplace add devcopilotdemo/ent-agent-plugins
copilot plugin install agentic-sdlc@ent-agent-plugins
```

Or install directly from the repository:

```bash
copilot plugin install devcopilotdemo/ent-agent-plugins:plugins/agentic-sdlc
```

## Layout

```text
agentic-sdlc/
├── plugin.json
├── .plugin/
│   └── plugin.json
├── agents/
│   ├── ent-orchestrator.agent.md
│   ├── ent-planner.agent.md
│   ├── ent-backend-developer.agent.md
│   ├── ent-frontend-developer.agent.md
│   ├── ent-designer.agent.md
│   ├── ent-tester.agent.md
│   └── ent-devops.agent.md
└── hooks/
    ├── hooks.json
    └── scripts/
        ├── scan-common.sh / scan-common.ps1
        ├── scan-secrets.sh / scan-secrets.ps1
        ├── scan-pii.sh / scan-pii.ps1
        └── guard-commit.sh / guard-commit.ps1
```

## License

[MIT](../../LICENSE)
