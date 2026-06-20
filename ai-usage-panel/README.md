# AI Usage Panel

Monitor **Claude, Codex, Copilot, OpenCode Zen, and Z.ai** usage directly from
the Noctalia bar.

This is a Noctalia Shell port of
[gustavobragac/plasma-ai-usage-panel](https://github.com/gustavobragac/plasma-ai-usage-panel)
(originally a KDE Plasma 6 widget). Licensed MIT — see [LICENSE](LICENSE).

## Requirements

The panel reads usage through the CLI helpers shipped by the original
`plasma-ai-usage-panel` project. Install them and make sure they are on your
`PATH`:

- `claude-usage`
- `codex-usage`
- `copilot-usage`
- `zen-balance`
- `zai-usage`

Z.ai credentials are stored in `~/.config/plasma-ai-usage-panel/zai.conf`
(kept compatible with `zai-usage`).

## Usage

1. Add the **AI Usage Panel** widget to your bar (Settings -> Bar).
2. Open the widget settings to pick which providers to show, the refresh
   interval, and icon/text colors.
3. Click the bar widget to open the panel with per-provider usage and reset
   times.

## Credits

Original KDE Plasma widget and CLI helpers by gustavobragac (NihilDigit).
Noctalia port by FelipeMayerDev.
