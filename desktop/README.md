# Personal desktop capture

Captured from the active Fedora configuration on 2026-10-08. This is the personal
configuration for the Phirios fork, not a `piroz` profile in the shared repository.
The live desktop was not reinstalled, reloaded or restarted during capture.

## Contents

- `config/hypr`: current Lua configuration, DMS bindings, outputs and fallback lock/wallpaper configuration.
- `config/niri`: current Niri configuration and its referenced DMS/user includes.
- `bin`: wallpaper, lock, translation, emoji, workspace and session helpers.
- `share/hypr-smart-resize`: directional geometry engine, documentation and existing tests.
- `lib/desktop-idle-guard` and `config/systemd/user`: video idle inhibition and palette reload integration.
- `shell.json` and `plugins.json`: personal DMS preferences; these are intended to merge into settings, not replace runtime account state.
- `dms-patches`: custom shell differences against Fedora `dms-1.6.2-1.fc44.x86_64` (`/usr/share/quickshell/dms`).
- `agent-patches`: additional local chat and voice changes against agent commit `2d749f3` recorded in the manifest.
- `plugins/aiLimitCounter`: installed DMS plugin source. The helper itself remains in its separate project.
- `share/dms-kopuz-lyrics`: lyrics adapter and vendored Kopuz provider/model sources, with their EUPL license. No compiled binary or lyrics cache is included.

The repository's `plugins/liveMode` and `plugins/liveWallpaper` also contain the
current local changes. Privacy exclusions are disabled in the captured Niri setup,
matching the running desktop. The LIVE indicator and share lifecycle remain.

## Reusing this capture

The shared `../install.sh` installs the baseline Niri setup, not this entire snapshot.
Do not run it merely to update the repository: it changes live configuration.

Paths in this capture refer to `/home/phirios`. Adapt them when restoring under a
different account. Config files belong under `~/.config`, `bin` under `~/.local/bin`,
`share` under `~/.local/share`, and `lib` under `~/.local/lib`. Back up existing files
before restoring. The Hyprland GPU links are intentionally not stored as machine
absolute symlinks: recreate `~/.config/hypr/gpu-rx9070` and `gpu-ryzen` for the actual
GPU PCI paths on the target machine. Monitor names and modes also need review.

Build the lyrics helper with `share/dms-kopuz-lyrics/rebuild.sh`. Its vendored source
is independent of the Kopuz checkout; build output is ignored. Rebuild GLSL shader
bundles with `/usr/lib64/qt6/bin/qsb` alongside each `.frag` source, using the matching
`.frag.qsb` filename. These generated bundles are intentionally excluded.

To reconstruct the custom DMS shell, copy the matching installed package directory
to `~/.local/share/dms-shell-custom`, then apply every `dms-patches/*.patch` with
`git apply` in that copy. Patches were checked against the recorded package, not
against arbitrary future versions. The agent delta is checked against its recorded
base, and must follow the matching baseline patches. No reload is performed here.

Other prerequisites used by the captured setup include Hyprland with Lua support,
Quickshell/DMS, hyprpaper, hyprlock, swayidle, Ghostty, wtype, jq, Python/Pillow,
playerctl, ffmpeg, wl-clipboard, grim/slurp, KDE Connect/Polkit and Dialect Flatpak.
The video and wallpaper artwork, Whisper models, external helper binaries and
credentials are separate local dependencies and are not bundled.

## Sharing changes

Keep personal configuration commits in this fork. Select reusable implementation
commits for a later upstream branch/PR, and remove personal paths/default choices
before submitting. No upstream PR is opened by this capture.

The older `~/Projects/niri-setup` checkout is preserved on the fork's
`archive/older-checkout` branch: its existing keyboard commit plus the previously
uncommitted line/word navigation edits. The same active bindings are captured here.

Excluded: auth files, API keys, tokens, session data, chat histories, lyrics/cache
contents, backups, logs, build output, compiled helpers and wallpaper media.
`capture-manifest.json` records source paths and hashes, not those excluded contents.
