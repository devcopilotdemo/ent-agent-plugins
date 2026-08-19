# ent-agent-plugins

Enterprise agent plugin marketplace for the **devcopilotdemo** organization.

Plugins here conform to the [Agent Plugins Specification 1.0.0](https://github.com/agentplugins/agent-plugins-spec/blob/main/spec/1.0.0.md) and work with GitHub Copilot CLI, the Copilot cloud agent, and other spec-conformant clients.

## Available plugins

| Plugin | Description |
| --- | --- |
| [`agentic-sdlc`](plugins/agentic-sdlc) | A seven-agent SDLC delivery team (ent-orchestrator, ent-planner, ent-backend-developer/ent-frontend-developer, ent-designer, ent-tester, ent-devops) with end-of-session secret and PII warnings. |

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
        ├── plugin.json               # Root fallback manifest
        ├── .plugin/plugin.json       # Copilot-format manifest used by VS Code
        ├── agents/                   # Custom agent definitions
        └── hooks/
            ├── hooks.json            # Hook configuration
            └── scripts/              # Scanner scripts
```

> **Note on `$schema`:** do not add the Agent Plugins 1.0 `$schema` field to a plugin that ships
> agents or hooks. Those are client-specific component types, not part of the 1.0 standard, and
> VS Code ignores them when a plugin declares the canonical schema. Omitting `$schema` keeps the
> plugin in Copilot format, where agents and hooks load correctly.

> **Note on agent `tools:`:** avoid pinning a `tools:` list in agent frontmatter unless the plugin
> targets a single client. Tool names are client-specific: Copilot CLI uses `view`, `grep`, `glob`,
> and `shell`, while VS Code uses `search`, `edit`, `runCommands`, and `<server>/*` for MCP tools.
> A list written for one client is rejected as invalid by the other. Omitting `tools:` grants the
> agent the client's default set, which keeps the plugin portable. Describe the intended capability
> in the agent body instead.

## Adding a plugin

1. Create `plugins/<plugin-name>/` with a `plugin.json` manifest declaring `name`, `version`, and `description`. Do not declare `$schema` (see the note above).
2. Add components in the conventional locations: `agents/`, `skills/<skill>/SKILL.md`, `hooks.json`, `mcp.json`.
3. Register the plugin in `.github/plugin/marketplace.json` with its `name`, `source` path, `version`, and `description`. Write `source` as a relative path starting with `./` (for example `./plugins/my-plugin`). Copilot CLI accepts the path with or without the prefix, but VS Code follows the Claude marketplace schema, which requires it and otherwise fails with "Plugin source directory not found in repository".
4. Keep the `version` in `marketplace.json` in sync with the plugin's own `plugin.json`. Clients use it to detect updates.
5. Validate locally with `copilot plugin marketplace add .` before opening a pull request.

Plugin names must be lowercase alphanumeric with hyphens or periods, must start and end alphanumerically, and must not contain consecutive hyphens or periods.

### Referencing hook scripts

Plugins are installed outside the workspace, so hook commands cannot use paths relative to the working directory. A `"cwd": "."` in `hooks.json` resolves to the *workspace* root, not the plugin directory, so a bare `hooks/scripts/foo.ps1` fails with "does not exist".

VS Code chooses its hook parser from the manifest location. A root-only `plugin.json` uses the legacy parser, which currently does not expand plugin-root placeholders in hook commands. Add `.plugin/plugin.json` and place the hook configuration at `hooks/hooks.json` to select the Copilot plugin parser that expands `${PLUGIN_ROOT}` and injects the corresponding environment variable.

Use VS Code's documented `command` and OS-specific override fields with `${PLUGIN_ROOT}`. Retain the legacy `bash` and `powershell` fields for Copilot CLI compatibility:

```jsonc
"command": "bash \"${PLUGIN_ROOT}/hooks/scripts/foo.sh\"",
"windows": "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${PLUGIN_ROOT}/hooks/scripts/foo.ps1\"",
"linux": "bash \"${PLUGIN_ROOT}/hooks/scripts/foo.sh\"",
"osx": "bash \"${PLUGIN_ROOT}/hooks/scripts/foo.sh\"",
"bash": "bash \"${PLUGIN_ROOT}/hooks/scripts/foo.sh\"",
"powershell": "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${PLUGIN_ROOT}/hooks/scripts/foo.ps1\""
```

Always quote the resulting path. Do not embed PowerShell `$variables` inside a nested double-quoted `-Command` string: the outer PowerShell process expands them before the child process starts.

## License

[MIT](LICENSE)
