# niri setup

One script that sets up a keyboard-driven desktop on Fedora:
[niri](https://github.com/niri-wm/niri) with
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), a near-black theme with
the Claude orange as accent, the AI Limit Counter in the bar and an AI chat panel.

Your current desktop stays installed. niri is added as one more session on the login screen,
so KDE or GNOME is one logout away.

## Install

```bash
git clone https://github.com/firatege/niri-setup
cd niri-setup
./install.sh
```

Then log out, pick **niri** in the session menu of the login screen, and log in.

Requires Fedora 43 or newer. The script asks for your password once, for `dnf`.
Use `./install.sh --skip-packages` when niri and DMS are already installed.

## What it does

| Step | Result |
|------|--------|
| Packages | `niri`, `xwayland-satellite`, `ghostty`, `wtype`, `dms` (from the `avengemedia/dms` COPR) and the tools the plugins call |
| niri config | The DMS default config plus persistent 60%-keyboard-friendly keybinds |
| Theme | `Ink`: near-black surfaces, `#d97757` accent, blur on, translucent bar and popups |
| AI Limit Counter | Clones [AILimitCounter](https://github.com/firatege/AILimitCounter), builds its helper into `~/.local/bin` and installs its DMS plugin |
| Live mode | A `LIVE` pill in the bar while your screen is shared, see below |
| Live wallpaper | A video wallpaper through mpvpaper, see below |
| AI chat panel | [dms-ai-agent](https://github.com/Cha1000000/dms-ai-agent) at a pinned commit, with the patches in `patches/` |

Anything that already exists is copied to a `.bak-<timestamp>` sibling before it is replaced.

## Keys

`Super` is the Windows key.

| Key | Action |
|-----|--------|
| `Super+T`, `Super+Enter` | Ghostty |
| `Ctrl+,`, `Ctrl+.` | Beginning/end of current line |
| `Ctrl+<` / `Ctrl+>` | Select to line beginning/end |
| `Alt+,/.` | Previous/next word |
| `Alt+<` / `Alt+>` | Select previous/next word |
| `Alt+Left`, `Alt+Right` | Move by word |
| `Super+Space` | App launcher |
| `Super+Q` | Close window |
| `Super+H/J/K/L` | Focus left/down/up/right |
| `Super+Shift+H/J/K/L` | Move window left/down/up/right |
| `Super+U/I` | Focus workspace down/up |
| `Super+Ctrl+U/I` | Move window to workspace down/up |
| `Super+M/Comma` | Focus first/last column |
| `Super+D` | Show desktop, press again to go back |
| `Super+A` | AI chat |
| `Super+B` | Cycle power profile |
| `Super+Alt+M` | Task manager |
| `Super+Alt+Comma` | DMS settings |
| `Super+Shift+/` | All shortcuts |
| `Super+Shift+E` | Leave niri |

Your own keybinds go in `~/.config/niri/custom/binds.kdl`. DMS rewrites the files under
`~/.config/niri/dms/`, so changes there do not last. The installer removes DMS's conflicting
arrow-key bindings before loading the persistent shortcuts.

## Screen sharing

While niri reports a running screencast, the bar shows a red `LIVE` pill with the time the
share has been running. Live mode switches on Do Not Disturb and holds off the idle lock, and
gives both back when the last share ends. It only gives back what it switched on itself: if
you had Do Not Disturb on already, it stays on. Both can be switched off in the plugin settings.

`~/.config/niri/custom/privacy.kdl` keeps a few things out of screen shares and recordings:
the AI chat, notifications, clipboard history, Wi-Fi password dialogs, password prompts and
common password managers. You still see them; viewers get a black rectangle the size of the
whole surface. Add a `match app-id=...` line for any other app you want hidden.

## Live wallpaper

The installer builds [mpvpaper](https://github.com/GhostNaN/mpvpaper) into `~/.local/bin` and
installs a plugin that plays a video as the wallpaper, one player per monitor. Give it a video
when installing:

```bash
./install.sh --wallpaper ~/Downloads/some-loop.mp4
```

or later in Settings > Plugins > Live Wallpaper. Videos that are not VP9 or AV1 are converted
to VP9 on install, because on an Intel GPU those decode in hardware at about 3% of one core,
while H.264 fell back to software and took a full core in testing.

Each monitor plays only while its workspace is empty or the overview is open, which is when the
wallpaper can be seen. It also stops on battery and while a Steam game or gamescope runs. The
still wallpaper stays underneath.

## The chat panel and what it may do

The panel runs your `claude` CLI, so it uses your own Claude subscription. Install
[Claude Code](https://docs.claude.com/en/docs/claude-code) and log in first.

Upstream starts Claude with `--dangerously-skip-permissions`: any command, no questions.
The patches replace that with an allowlist. Whatever is not on it is refused.

| Allowed | Refused |
|---------|---------|
| Focus, move and close windows; switch workspaces | Writing or editing files |
| Start installed apps, open files and links | Any other shell command |
| Lock, theme, night mode and other `dms ipc` calls | `niri msg action spawn` |
| Media keys, notifications | Reading outside the folders on the left |
| System info, web search | |
| Reading files in Downloads, Documents, Pictures, Desktop, Videos, Music | |

Two more things are off until you switch them on in the plugin settings: **auto-update**,
because an update is new code that the shell then runs, and **voice input**, because upstream
opens the microphone every time the panel opens.

## Undo

Pick your old session on the login screen. To remove the packages as well:

```bash
sudo dnf remove niri dms
sudo dnf copr remove avengemedia/dms
```

The configuration lives in `~/.config/niri` and `~/.config/DankMaterialShell`.

## Tests

```bash
python3 -m unittest discover -s tests
node --test tests/live.test.js tests/wallpaper.test.js
```
