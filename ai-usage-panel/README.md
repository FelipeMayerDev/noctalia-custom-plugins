# AI Usage Panel

Native quota monitoring for Claude, Codex, Copilot, OpenCode Zen, and Z.ai in the Noctalia 5 bar.

This plugin is a Noctalia port of [gustavobragac/plasma-ai-usage-panel](https://github.com/gustavobragac/plasma-ai-usage-panel), originally a KDE Plasma 6 widget. Version 1.1 replaces the mandatory Python helper backend with Noctalia's native HTTP and credential APIs for Claude, Codex, and Z.ai.

| Plugin | Value |
|---|---|
| ID | `felipemayerdev/ai-usage-panel` |
| Bar widget | `usage` |
| Panel | `usage-panel` |
| Service | `usage-service` |
| Minimum plugin API | 3 |

## Usage

1. Sign in to the CLI for each provider you want to monitor.
2. Enable `felipemayerdev/ai-usage-panel`.
3. Add **AI Usage Panel → usage** in the bar editor.
4. Click the widget to open the quota panel. Right-click to refresh.

Open the panel directly with:

```bash
noctalia msg panel-toggle felipemayerdev/ai-usage-panel:usage-panel
```

The service refreshes all enabled providers concurrently. A refresh already in progress is reused rather than duplicated. If a transient request fails after a successful refresh, the UI keeps the last result and marks it stale.
Equivalent rolling windows use the same duration labels across providers—for example, `5 hours` and `7 days`—instead of provider-specific names such as “primary” and “secondary”. Reset timestamps use one `DD/MM · HH:MM UTC` format.


## Providers

| Provider ID | Authentication and data source | Extra command |
|---|---|---|
| `claude` | Reads the active Claude Code OAuth session from `~/.claude/.credentials.json`; requests `api.anthropic.com/api/oauth/usage`. | None |
| `codex` | Reads the active Codex CLI OAuth session from `~/.codex/auth.json`; requests the Codex usage API. | None |
| `copilot` | Reads the active GitHub CLI token and requests GitHub's premium-request billing API. | `gh` |
| `zen` | Uses the upstream browser-cookie collector. | `zen-balance` |
| `zai` | Uses the API key stored in Noctalia plugin settings and requests `api.z.ai` directly. | None |

Claude and Codex are enabled by default and no longer require `claude-usage`, `codex-usage`, Python, `uv`, or `curl_cffi`. Open the corresponding CLI once if an OAuth token is missing or expired. Copilot requires a GitHub token allowed to read the account's premium-request usage; GitHub may return 404 when the account or token does not expose that endpoint.

Install the optional OpenCode Zen collector from the upstream project:

```bash
uv tool install --from plasma-ai-usage-panel zen-balance
```

## Settings

| Setting | Default | Description |
|---|---:|---|
| Enabled providers | `claude`, `codex` | Provider IDs queried by the service: `claude`, `codex`, `copilot`, `zen`, `zai`. |
| Refresh interval | 120 seconds | Automatic refresh cadence, from 30 to 3600 seconds. |
| Compact bar labels | Off | Show provider abbreviations instead of names and quota values. |
| Show reset times | On | Show each quota window's reset timestamp in the panel. |
| Refresh when opening | On | Request fresh usage whenever the panel opens. |
| Copilot monthly quota | 300 | Allowance used to calculate Copilot's displayed percentage. |
| Z.ai API key | Empty | API key from `z.ai/manage-apikey/apikey-list`. |

## Network, files, and credentials

The service reads Claude and Codex OAuth files on each refresh so CLI token rotation is picked up automatically. It passes credentials only in HTTPS authorization headers and never copies them into plugin state, logs, or compatibility files. The Z.ai key remains in Noctalia's plugin settings. The optional `gh` and `zen-balance` processes run only when their providers are enabled.

## Credits

Original KDE Plasma widget and collector work by gustavobragac (NihilDigit). Noctalia port by FelipeMayerDev.

## License

MIT — see [LICENSE](LICENSE).
