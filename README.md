# niri setup

One script that sets up a keyboard-driven desktop on Fedora:
[niri](https://github.com/niri-wm/niri) with
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), a near-black theme with
the Claude orange as accent, the AI Limit Counter in the bar and an AI chat panel.

Your current desktop stays installed. niri is added as one more session on the login screen,
so KDE or GNOME is one logout away.

## Install

```bash
git clone https://github.com/<you>/niri-setup      # your fork, see "Personal profiles"
cd niri-setup
./install.sh --profile yourname    # or without --profile for the shared setup only
```

Then log out, pick **niri** in the session menu of the login screen, and log in.

Requires Fedora 43 or newer. The script asks for your password once, for `dnf`.
Use `./install.sh --skip-packages` when niri and DMS are already installed.

Two parts are opt-in:

| Option | Adds |
|--------|------|
| `--voice` | Local Whisper voice input, including the Vulkan backend/model for AMD GPUs, see below |
| `--gaming` | The tweaks in `system/`: gamemode, no core dumps, a throttled file indexer |

## What it does

| Step | Result |
|------|--------|
| Packages | `niri`, `xwayland-satellite`, `kitty`, `dms` (from the `avengemedia/dms` COPR) and the tools the plugins call |
| niri config | The DMS default config, with `kitty` as terminal, plus two keybinds of our own |
| Theme | `Ink`: near-black surfaces, `#d97757` accent, blur on, translucent bar and popups |
| AI Limit Counter | Clones [AILimitCounter](https://github.com/Phirios/AILimitCounter), builds its helper into `~/.local/bin` and installs its DMS plugin |
| Live mode | A `LIVE` pill in the bar while your screen is shared, see below |
| Live wallpaper | Seamlessly switching video wallpapers through Qt Multimedia, see below |
| Tailscale | A full-width Control Center section with a taller device list, device owners and owner filtering |
| AI chat panel | [dms-ai-agent](https://github.com/Cha1000000/dms-ai-agent) at a pinned commit, with the patches in `patches/` |
| App placement | Discord and Slack on a `chat` workspace, Spotify on `media`, games fullscreen on the external monitor |
| Idle and lock | Lock after 15 min on AC and 5 min on battery, screen off after 30 and 10, lock before suspend |
| Steam on NVIDIA | On a machine with an NVIDIA card, Steam and its games start on it |

Anything that already exists is copied to a `.bak-<timestamp>` sibling before it is replaced.

## Keys

`Super` is the Windows key.

| Key | Action |
|-----|--------|
| `Super+T` | Terminal |
| `Super+Space` | App launcher |
| `Super+Q` | Close window |
| `Super+D` | Show desktop, press again to go back |
| `Super+A` | AI chat |
| `Super+B` | Cycle power profile |
| `Super+G` | Fit all windows of the workspace on screen as a grid: 2 side by side, 4 as 2x2, 6 as 3x2, 9 as 3x3 |
| `Super+Shift+G` | Put the windows back the way they were before `Super+G` |
| `Super+Up` / `Super+Down` | Window above or below, then the next workspace (no Page Up/Down needed) |
| `Super+Comma` | DMS settings |
| `Super+Shift+/` | All shortcuts |
| `Super+Shift+E` | Leave niri |

Your own keybinds go in `~/.config/niri/custom/binds.kdl`. DMS rewrites the files under
`~/.config/niri/dms/`, so changes there do not last.

## Screen sharing

While niri reports a running screencast, the bar shows a red `LIVE` pill with the time the
share has been running. Live mode switches on Do Not Disturb and holds off the idle lock, and
gives both back when the last share ends. It only gives back what it switched on itself: if
you had Do Not Disturb on already, it stays on. Both can be switched off in the plugin settings.

`~/.config/niri/custom/privacy-rules.kdl` keeps a few things out of screen shares and recordings:
the AI chat, notifications, the notification center, clipboard history, Wi-Fi password dialogs,
password prompts and common password managers. You still see them; viewers get a black
rectangle the size of the panel. For that, the installer turns off the dimmed backdrop behind
DMS dialogs, because with it DMS draws a dialog as one full-screen surface and hiding it would
black out the whole screen.

The notification center has the same problem for a different reason: DMS draws it as a strip
down to the bottom of the screen. `niri/scripts/dms-run.sh` starts DMS from a copy of its UI
with that one line changed, so only the panel is blacked out. The copy is refreshed after every
DMS update, and if the line ever changes upstream the script starts the stock UI instead. Add a `match app-id=...` line for any other app you want hidden.

Click the `LIVE` pill during a share for switches: hide private surfaces, silence
notifications, keep the screen awake. The privacy switch stays as you leave it; the other two
last for the share.

## Live wallpaper

The installer adds Qt Multimedia and a plugin that plays a video as the wallpaper, one active
player per monitor. Give it a video when installing:

```bash
./install.sh --wallpaper ~/Downloads/some-loop.mp4
```

or later in Settings > Plugins > Live Wallpaper. Videos that are not VP9 or AV1 are converted
to VP9 on install. Hardware decoding depends on the graphics driver and Qt Multimedia backend.

Videos in `~/Videos/Wallpapers` also appear as previews in DMS's normal Wallpapers tab.
Selecting one there switches the running video immediately; selecting a still image hands
the wallpaper back to DMS. The active video has a check badge. Preview images are generated at
startup and linked into `~/Pictures/Wallpapers`, without copying the videos themselves.
When switching videos, both clips keep moving during the transition: the old one blurs and
fades away as the new one sharpens. The new clip keeps playing in the same player afterward,
without restarting at the handoff. Existing mpvpaper installations are left untouched but are
no longer used by this plugin.

Each monitor plays only while its workspace is empty or the overview is open, which is when the
wallpaper can be seen. It also stops on battery and while a Steam game or gamescope runs. The
still wallpaper stays underneath. The installer places mpvpaper in niri's backdrop, so the video
stays anchored to the monitor while workspaces animate over it.

## Personal profiles

This repository holds only the shared setup. Everyone forks it and keeps their own profile in
their fork: extra shortcuts, where apps open, and settings such as the wallpaper video or idle
timeouts.

```bash
gh repo fork Auth-ism/niri-setup --clone && cd niri-setup
cp -r profiles/example profiles/<yourname>     # edit the files, commit, push to your fork
./install.sh --profile <yourname>
```

To get shared updates, pull from this repository (`git pull upstream main`) and run the
installer again. Shared improvements go back here as pull requests; profiles stay in forks.
See [profiles/README.md](profiles/README.md) for what each file does.

## Steam and the NVIDIA card

GNOME and KDE start Steam on the NVIDIA card because Steam's desktop file asks for it. niri
ignores that request, so native OpenGL games such as Half-Life ran on the Intel GPU, hot and
slow. On a machine with a working `nvidia-smi` the installer writes
`~/.local/share/applications/steam.desktop`, a copy that sets the NVIDIA offload variables.
Start Steam from the launcher to use it; `steam` typed in a terminal skips it. If a Steam update
changes its own desktop file, run the installer again.

## Gaming tweaks

`--gaming` installs gamemode with `system/gamemode.ini` (performance governor while a game
runs), turns off core dumps (`system/coredump-off.conf`; crashing apps had piled up gigabytes of
them and kept a core busy writing more) and throttles the GNOME file indexer. Add
`gamemoderun %command%` to a game's Steam launch options to use gamemode.

One more fix is specific to one laptop and so is not applied: if a Proton game drops a frame
once a second, reading the battery may be slow on that machine. Check with
`time cat /sys/class/power_supply/BAT*/status`; above 50 ms, add the kernel argument
`battery.cache_time=60000` with `sudo grubby --update-kernel=ALL --args=...`.
A file in `/etc/modprobe.d` does nothing, because `battery` is built into the Fedora kernel.

## The chat panel and what it may do

The panel can run either the `claude` or `codex` CLI with your own signed-in account. Claude
remains the default for existing installs; choose Codex in Settings > Plugins > DMS AI Agent or
from the model menu in the chat. The accent colors follow the active provider: warm orange for
Claude and a high-contrast monochrome palette for Codex.

Install [Claude Code](https://docs.claude.com/en/docs/claude-code) for Claude, or install and sign
in to [Codex](https://developers.openai.com/learn/codex) for the Codex option. Codex runs with its user configuration and rules ignored and a
read-only filesystem sandbox; Claude uses the explicit command and folder allowlist below.

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

The chat itself is not hidden from screen shares, so viewers see what you ask and what comes
back.

**Auto-update** stays off, because an update is new code that the shell then runs.

**Voice input** is off unless you install with `--voice`. That sets up
[faster-whisper](https://github.com/SYSTRAN/faster-whisper) in
`~/.local/share/dms-ai-agent/whisper-venv` and builds a pinned
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) Vulkan backend. AMD/Vulkan systems use
the local `small` GGML model; NVIDIA uses CUDA with `large-v3-turbo`, and CPU remains the
fallback. The mic records in two-minute chunks and appends each transcript as it becomes
available. Speech is turned into text on your machine. Running the installer again without
`--voice` switches voice input off again.

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
