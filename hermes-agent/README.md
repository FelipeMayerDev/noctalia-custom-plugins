# Hermes Agent

Native Noctalia plugin for [Hermes Agent](https://github.com/noctalia-dev/legacy-v4-plugins).

Shows live Hermes status in the bar, provides a full chat panel with streaming responses, tool-event activity, approval prompts, interrupt, one-shot prompts, and a launcher provider using `>hermes`.

## Features

- **Bar widget**: traffic-light status indicator (online / busy / needs you / degraded / offline) with click-to-expand summary popup.
- **Panel**: persistent chat with Hermes — send prompts, watch streaming responses, approve tool calls, interrupt, start / resume sessions.
- **Launcher provider**: type `>hermes` in the Noctalia launcher to open the panel, start a session, resume the latest session, or send a one-shot prompt.
- **Settings UI**: configure bridge host / port, state file, Hermes home, poll interval, default provider / model, auto-start bridge, hide-when-idle, pin panel, show tool activity.

## Requirements

- [Hermes Agent](https://github.com/noctalia-dev/legacy-v4-plugins) installed and on `PATH` (or set `hermesCommand` in settings).
- Noctalia 4.4.1 or newer.

## How it works

The plugin ships a small Python bridge (`scripts/hermes_bridge.py`) that exposes local HTTP endpoints for health, state, session, prompt, interrupt, approvals, and one-shot commands. The QML surfaces talk to the bridge and render state from a watched state file.

## Client-only mode (remote Hermes over SSH)

When Hermes runs on a **remote server**, the client machine has no bridge script,
no `~/.hermes`, and no token file — so the default local mode does not work.
Client-only mode keeps every feature (status, chat, approvals, sessions,
launcher) but drives a bridge running on the server, reached over an SSH tunnel.

The bridge binds to `127.0.0.1` on the server (no exposed port, token never
travels in plaintext); the SSH tunnel forwards it to the client.

**On the server** (where Hermes lives):

```bash
cd <plugin-dir>/scripts
./hermes-bridge-serve.sh 19777
```

It starts the bridge and prints the **bridge token**. Copy it.

**On the client**, open the tunnel:

```bash
ssh -L 19777:127.0.0.1:19777 <user>@<server>
```

**In the plugin settings** (Advanced):

1. Enable **Client-only mode (remote bridge)**.
2. Set **Bridge host** = `127.0.0.1`, **Bridge port** = `19777` (the forwarded port).
3. Paste the **Bridge token** from the server helper.

In this mode the plugin never spawns a local bridge; it polls `/state` over HTTP
(fast while a session is running, slower when idle). Gateway controls, model
selection, sessions, approvals, and the `>hermes` launcher all operate against
the remote bridge.

## Settings

| Setting | Default | Description |
|---|---|---|
| `bridgeHost` | `127.0.0.1` | Bridge host |
| `bridgePort` | `19777` | Bridge port |
| `stateFile` | `~/.cache/noctalia-hermes/state.json` | Shared state file |
| `hermesHome` | `~/.hermes` | Hermes home directory |
| `hermesCommand` | `hermes` | Hermes executable |
| `autoStartBridge` | `true` | Start the bridge when Noctalia loads (local mode) |
| `clientOnlyMode` | `false` | Connect to a remote bridge over SSH instead of starting one locally |
| `bridgeTokenManual` | _(empty)_ | Bridge token (required in client-only mode) |
| `statusPollIntervalSec` | `30` | Status poll interval |
| `hideWhenIdle` | `false` | Hide the bar pill when idle |
| `launcherPrefix` | `>hermes` | Launcher command prefix |
| `panelPinned` | `false` | Pin the panel as a persistent side window |
| `showToolActivity` | `false` | Show compact tool-activity line |
| `defaultProvider` | _(empty)_ | Default provider |
| `defaultModel` | _(empty)_ | Default model |

## Credits

Original `hermes-agent` plugin by **nomadx**
([PR #934](https://github.com/noctalia-dev/legacy-v4-plugins/pull/934)).
Client-only mode (remote bridge over SSH) added in this fork by FelipeMayerDev.

## License

MIT