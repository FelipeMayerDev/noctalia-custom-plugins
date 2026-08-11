# AI Usage Panel

Monitor Claude, Codex, Copilot, OpenCode Zen, and Z.ai usage from the Noctalia 5 bar.

This is a Noctalia port of [gustavobragac/plasma-ai-usage-panel](https://github.com/gustavobragac/plasma-ai-usage-panel), originally a KDE Plasma 6 widget.

| Plugin | Value |
|---|---|
| ID | `felipemayerdev/ai-usage-panel` |
| Bar widget | `usage` |
| Panel | `usage-panel` |
| Service | `usage-service` |

## Usage

1. Enable `felipemayerdev/ai-usage-panel`.
2. Add **AI Usage Panel → usage** to the bar.
3. Click the widget to open the provider panel. Right-click it to open plugin settings.
4. The panel can also be opened directly:

   ```bash
   noctalia msg panel-toggle felipemayerdev/ai-usage-panel:usage-panel
   ```

The background service refreshes enabled providers on the configured interval. The panel refresh button and refresh-on-open setting request an immediate update without starting a second overlapping refresh.

## Requirements

Install the helpers for every provider you enable and make them available on `PATH`:

- `claude-usage`
- `codex-usage`
- `copilot-usage`
- `zen-balance`
- `zai-usage`

Provider browser-cookie selection remains managed by the upstream `ai-cookie-source` helper. The optional Z.ai API key setting is written to `~/.config/plasma-ai-usage-panel/zai.conf` with mode `0600` for `zai-usage` compatibility.

## Settings

| Setting | Default | Description |
|---|---:|---|
| Enabled providers | `claude`, `codex` | Provider IDs queried by the service. |
| Refresh interval | 120 seconds | Automatic refresh cadence, from 30 to 3600 seconds. |
| Icon only | Off | Hide compact usage labels in the bar. |
| Show reset time | On | Keep reset timing from helper output in bar labels. |
| Refresh on open | On | Refresh when data is at least 10 seconds old. |
| Z.ai API key | Empty | Credential consumed by `zai-usage`. |

## Network, files, and processes

The plugin executes the declared local usage helpers. Those helpers perform provider-specific browser-cookie or API requests. The plugin itself writes only the optional Z.ai compatibility file.

## Credits

Original KDE Plasma widget and CLI helpers by gustavobragac (NihilDigit). Noctalia port by FelipeMayerDev.

## License

MIT — see [LICENSE](LICENSE).
