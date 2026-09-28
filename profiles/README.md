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

## What goes where

Code is shared, choices are personal.

| Shared (outside `profiles/`) | Personal (`profiles/<name>/`) |
|------------------------------|-------------------------------|
| Plugins, scripts, how a feature works | Which videos, which keys, which timeouts |
| Defaults that suit everyone | Only the values that differ from those defaults |
| Hardware detection, e.g. NVIDIA or AMD | Machine-specific names, e.g. monitor names |

- **A feature only one person wants** still goes into the shared setup. Whoever does not want
  it switches it off in their profile, e.g. `"liveWallpaper": {"enabled": false}` in
  `plugins.json`. A private copy of the code would drift away from the shared one.
- **GPU differences are not profile settings.** The installer detects the GPU and skips the
  NVIDIA-only parts on other cards, so a profile keeps working on a new machine.
- **Override values, not files.** Copying a whole shared file into a profile to change one line
  stops that file from getting updates. Put only the key or value that differs.
- **No code in profiles.** When something needs logic, it goes into the shared setup with a
  setting that controls it, and the profile sets that setting.
- **No branch or fork per person.** Shared fixes would have to be copied to each one.
