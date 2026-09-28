# Profiles

Everything outside this folder is shared. A profile holds only what one person wants
different, and is applied on top of the shared setup:

```bash
./install.sh --profile firat
./install.sh --profile piroz
```

Without `--profile` you get the shared setup alone. Each file in a profile is optional.

| File | What it does | Installed to |
|------|--------------|--------------|
| `binds.kdl` | Extra or changed shortcuts. Loaded after the shared ones, so the same key here wins. | `~/.config/niri/profile/binds.kdl` |
| `apps.kdl` | Named workspaces and where apps open. Output names like `eDP-1` depend on the machine; `niri msg outputs` lists them. | `~/.config/niri/profile/apps.kdl` |
| `shell.json` | DankMaterialShell settings that differ, e.g. idle timeouts. Settings for the main bar go under `"bar"`. | merged into `~/.config/DankMaterialShell/settings.json` |
| `plugins.json` | Plugin settings per plugin id, e.g. the live wallpaper video. | merged into `~/.config/DankMaterialShell/plugin_settings.json` |

Keys starting with `_` in the JSON files are comments and are ignored.

Changes to a profile only reach a machine when the installer runs again with that profile.
