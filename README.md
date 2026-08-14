# ent-agent-plugins

Enterprise agent plugin marketplace for the **devcopilotdemo** organization.

Plugins here conform to the [Agent Plugins Specification 1.0.0](https://github.com/agentplugins/agent-plugins-spec/blob/main/spec/1.0.0.md) and work with GitHub Copilot CLI, the Copilot cloud agent, and other spec-conformant clients.

## Available plugins

| Plugin | Description |
| --- | --- |
| [`agentic-sdlc`](plugins/agentic-sdlc) | A seven-agent SDLC delivery team (orchestrator, planner, backend/frontend developers, designer, tester, devops) with secret and PII scanning hooks. |

## Using the marketplace

```bash
copilot plugin marketplace add devcopilotdemo/ent-agent-plugins
copilot plugin marketplace browse ent-agent-plugins
copilot plugin install agentic-sdlc@ent-agent-plugins
```

For enterprise-managed rollout, the marketplace and its plugins are declared in the organization's `managed-settings.json` so they are registered and preloaded automatically. See [Enterprise managed settings](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/enterprise-administrators/enterprise-managed-settings).

```json
{
  "extraKnownMarketplaces": {
    "ent-agent-plugins": {
      "source": {
        "source": "github",
        "repo": "devcopilotdemo/ent-agent-plugins"
      }
    }
  },
  "enabledPlugins": {
    "agentic-sdlc@ent-agent-plugins": true
  }
}
```

## Repository layout

```text
ent-agent-plugins/
├── .github/plugin/marketplace.json   # Marketplace catalog
└── plugins/
    └── agentic-sdlc/
        ├── plugin.json               # Agent Plugins 1.0.0 manifest
        ├── agents/                   # Custom agent definitions
        ├── skills/                   # Agent skills
        └── hooks/                    # Hook config and scanner scripts
```

## Adding a plugin

1. Create `plugins/<plugin-name>/` with a `plugin.json` manifest declaring `$schema`, `name`, `version`, and `description`.
2. Add components in the conventional locations: `agents/`, `skills/<skill>/SKILL.md`, `hooks/hooks.json`, `mcp.json`.
3. Register the plugin in `.github/plugin/marketplace.json` with its `name`, `source` path, `version`, and `description`.
4. Validate locally with `copilot plugin marketplace add .` before opening a pull request.

Plugin names must be lowercase alphanumeric with hyphens or periods, must start and end alphanumerically, and must not contain consecutive hyphens or periods.

## License

[MIT](LICENSE)
