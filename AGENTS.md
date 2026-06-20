# Agent Instructions

## Adding a new plugin

When adding a plugin to this repository, **always** update both files below before committing. Skipping either breaks discoverability in the Noctalia UI.

### 1. `registry.json`

Add an entry to the `plugins` array. Required fields (match the schema used by
Noctalia's `PluginService`):

```json
{
  "id": "<folder-name>",
  "name": "<Human-readable name>",
  "version": "<x.y.z from the plugin's manifest.json>",
  "official": false,
  "author": "<author>",
  "description": "<one-line description>",
  "repository": "https://github.com/FelipeMayerDev/noctalia-custom-plugins",
  "minNoctaliaVersion": "<from manifest.json, or omit if not set>",
  "license": "<from manifest.json>",
  "tags": ["<tag>"],
  "lastUpdated": "<ISO-8601 timestamp of this change>"
}
```

Keep the array ordered alphabetically by `id`. Validate JSON before committing:

```bash
python3 -c "import json; json.load(open('registry.json')); print('OK')"
```

### 2. `README.md`

Add a row to the **Plugins** table (keep alphabetical by folder name):

```markdown
| [plugin-name](plugin-name/) | One-line description. Note forks/ports and upstream credit. |
```

### 3. Bumping an existing plugin version

Update `version` and `lastUpdated` in `registry.json` to match the new
`manifest.json` version. Update the README description if the feature set
changed significantly.

### 4. Commit message convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat(<plugin-id>): <what was added>`
- `fix(<plugin-id>): <what was fixed>`
- `docs(<plugin-id>): <what was documented>`
- `chore: update registry / readme` for metadata-only bumps

Always include a `Co-Authored-By:` trailer when an AI assistant authored the
commit.

## Repository rules

- `registry.json` is the source of truth for Noctalia's plugin browser. Keep it
  in sync with the folders on `main`.
- Never commit `settings.json` (runtime user config) from installed plugin
  directories.
- Plugin folders must contain a valid `manifest.json` (fields: `id`, `name`,
  `version`, `author`, `description`, `entryPoints`). Validate with
  `python3 -c "import json; json.load(open('<plugin>/manifest.json'))"`.
- For forked or ported plugins, preserve the upstream `LICENSE` copyright line
  and credit the original author in the plugin's `README.md`.
