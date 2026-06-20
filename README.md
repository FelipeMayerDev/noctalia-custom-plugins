# Noctalia Custom Plugins

Custom plugins for [Noctalia Shell](https://github.com/noctalia-dev).

## Plugins

| Plugin | Description |
|---|---|
| [hermes-ssh-chat](hermes-ssh-chat/) | Use Hermes on a remote server through an interactive SSH terminal. |

## Installation

### From the Noctalia UI (recommended)

Noctalia can install plugins straight from this repository — no manual copying.

1. Open **Settings -> Plugins -> Sources**.
2. Click **Add source** and paste this repository URL:

   ```
   https://github.com/FelipeMayerDev/noctalia-custom-plugins
   ```

3. Make sure the source is **enabled**.
4. Go to the **Available** tab and hit **Refresh** if the list is stale.
5. Find the plugin (e.g. *Hermes SSH Terminal*), click **Install**, then
   toggle it **on** in the **Installed** tab.

> Noctalia reads `registry.json` from the default branch of each source repo to
> list available plugins, then clones the matching plugin folder on install.

### Manual install

Copy the plugin folder into your Noctalia plugins directory, then enable it in
**Settings -> Plugins -> Installed**:

```bash
cp -r hermes-ssh-chat ~/.config/noctalia/plugins/
```

Each plugin has its own `README.md` with setup and usage details.
