# Noctalia Custom Plugins

Custom plugins for [Noctalia Shell 5](https://github.com/noctalia-dev/noctalia).

## Plugins

| Plugin | Description |
|---|---|
| [ai-usage-panel](ai-usage-panel/) | Monitor Claude, Codex, Copilot, OpenCode Zen, and Z.ai usage from the bar. Port of gustavobragac's plasma-ai-usage-panel. |
| [hermes-agent](hermes-agent/) | Native Noctalia status, chat panel, and launcher for Hermes Agent. Supports client-only mode through a remote bridge over SSH. Fork of [nomadx's plugin](https://github.com/noctalia-dev/legacy-v4-plugins/pull/934). |
| [hermes-ssh-chat](hermes-ssh-chat/) | Launch Hermes on a remote server in an interactive SSH terminal. |

## Noctalia 5 installation

### Settings UI

1. Open **Settings → Plugins**.
2. Add a **git** source with this location:

   ```text
   https://github.com/FelipeMayerDev/noctalia-custom-plugins
   ```

3. Update the source, then enable the desired plugin.
4. Add its widget from the bar editor. Plugin panels and launcher providers become available when the plugin is enabled.

For git sources, Noctalia 5 discovers available plugins through the root `catalog.toml` and validates each top-level `plugin.toml` when enabling it. `registry.json` and the QML `manifest.json` files are retained only for legacy Noctalia 4 installations.

### Command line

```bash
noctalia msg plugins source add custom git https://github.com/FelipeMayerDev/noctalia-custom-plugins
noctalia msg plugins enable felipemayerdev/ai-usage-panel
noctalia msg plugins enable felipemayerdev/hermes-agent
noctalia msg plugins enable felipemayerdev/hermes-ssh-chat
```

For local development, add the checkout as a path source:

```bash
noctalia msg plugins source add custom-dev path "$PWD"
```

Each plugin README documents its entries, dependencies, settings, and direct panel command.
