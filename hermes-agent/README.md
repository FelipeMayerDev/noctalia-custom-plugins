# Hermes Agent

Noctalia 5 status, chat panel, and launcher integration for [Hermes Agent](https://github.com/NousResearch/hermes-agent).

| Plugin | Value |
|---|---|
| ID | `felipemayerdev/hermes-agent` |
| Bar widget | `status` |
| Panel | `chat-panel` |
| Launcher provider | `hermes` |
| Service | `bridge` |

## Usage

1. Enable `felipemayerdev/hermes-agent`.
2. Add **Hermes Agent → status** to the bar.
3. Click the widget to open chat; right-click it to open plugin settings.
4. Type `/hermes` in the launcher to open chat, create or resume a session, or add a prompt for a one-shot request.
5. Open the panel directly when needed:

   ```bash
   noctalia msg panel-toggle felipemayerdev/hermes-agent:chat-panel
   ```

The chat panel follows streaming bridge state, sends prompts, interrupts active work, creates sessions, and answers tool-approval requests. Type a prompt and press Enter or click **Send**.

## Requirements

- `python3`
- `hermes`
- `pkill` from procps, used only to stop a local bridge started by the plugin
- Noctalia 5 with plugin API 8 or newer

The plugin ships `scripts/hermes_bridge.py`. In local mode the service starts it when the configured bridge is unavailable, polls its authenticated HTTP API, and starts the Hermes gateway when requested by settings.

## Remote client-only mode

Run the bridge on the server that has Hermes:

```bash
cd <plugin-dir>/scripts
./hermes-bridge-serve.sh 19777
```

Copy the printed bridge token, then create a local tunnel:

```bash
ssh -L 19777:127.0.0.1:19777 user@server
```

In plugin settings:

1. Enable **Client-only mode**.
2. Set **Bridge host** to `127.0.0.1` and **Bridge port** to `19777`.
3. Paste the bridge token.

Client-only mode never starts a local bridge. Status, chat, approvals, sessions, launcher actions, and gateway controls target the forwarded remote bridge.

Verify the tunnel independently:

```bash
curl -s 127.0.0.1:19777/health
curl -s -H 'X-Bridge-Token: <token>' 127.0.0.1:19777/state
```

## Settings

| Setting | Default | Description |
|---|---:|---|
| Bridge host | `127.0.0.1` | Local bridge or forwarded address. |
| Bridge port | `19777` | HTTP bridge port. |
| State file | `~/.cache/noctalia-hermes/state.json` | Local bridge state and token directory. |
| Hermes home | `~/.hermes` | Home passed to the bridge. |
| Hermes command | `hermes` | Executable used by the bridge. |
| Auto-start bridge | On | Starts the bundled bridge in local mode. |
| Auto-start gateway | On | Starts a stopped Hermes gateway. |
| Client-only mode | Off | Uses an existing bridge instead of a local process. |
| Bridge token | Empty | Required by a remote bridge. |
| Status poll interval | 30 seconds | Idle polling cadence; active sessions poll every two seconds. |
| Hide when idle | Off | Hides an online idle bar widget. |
| Show tool activity | Off | Keeps the compact activity line visible while idle. |

## Network, files, and processes

The service starts the bundled Python bridge only in local mode and stops that process when its runtime exits. It reads the bridge token beside the configured state file and sends authenticated HTTP requests to the configured bridge host. The bridge owns Hermes state files, gateway processes, sessions, and provider network access.

## Credits

Original `hermes-agent` plugin by **nomadx** ([legacy PR #934](https://github.com/noctalia-dev/legacy-v4-plugins/pull/934)). Client-only mode and the Noctalia 5 port are maintained in this fork by FelipeMayerDev.

## License

MIT — see [LICENSE](LICENSE).
