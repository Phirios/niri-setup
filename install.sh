#!/usr/bin/env bash
# Set up niri + DankMaterialShell on Fedora: the Ink theme, the AI Limit Counter in the bar
# and the AI chat panel. Your current desktop (KDE, GNOME) stays installed and untouched;
# niri is added as one more session on the login screen.
#
#   ./install.sh                     everything
#   ./install.sh --wallpaper FILE    also use FILE as the live wallpaper (converted to VP9)
#   ./install.sh --skip-packages     configuration only (niri and dms are already installed)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
NIRI_DIR="$CONFIG_HOME/niri"
DMS_DIR="$CONFIG_HOME/DankMaterialShell"
STAMP="$(date +%Y%m%d-%H%M%S)"

DMS_COPR="avengemedia/dms"
PACKAGES=(
  niri xwayland-satellite xdg-desktop-portal-gnome ghostty wtype
  git cargo python3 jq
  dbus-devel pkgconf-pkg-config
  gtk3 xdg-utils libnotify playerctl wl-clipboard procps-ng
)

# The chat panel is pinned to the commit the patches in patches/ were written against.
AGENT_REPO="https://github.com/Cha1000000/dms-ai-agent"
AGENT_COMMIT="a3f4a1114942fdc715e97ddb3a6680811ff38cb9"
AGENT_DIR="$DMS_DIR/plugins/dmsAgent"

# The limit counter has its own repository. Until its DMS plugin is merged into the
# default branch, the plugin lives on LIMIT_BRANCH.
LIMIT_REPO="https://github.com/firatege/AILimitCounter"
LIMIT_BRANCH="feat/dms-plugin"
LIMIT_SRC="$DATA_HOME/niri-setup/AILimitCounter"
LOCAL_PLUGINS=(liveMode liveWallpaper)
WALLPAPER_DIR="$HOME/Videos/Wallpapers"

# mpvpaper plays the live wallpaper. Fedora does not package it, so it is built from this tag.
MPVPAPER_REPO="https://github.com/GhostNaN/mpvpaper"
MPVPAPER_TAG="1.9"
MPVPAPER_BUILD_PACKAGES=(mpv mpv-devel meson ninja-build gcc wayland-devel wayland-protocols-devel mesa-libEGL-devel ffmpeg-free)

NIRI_INCLUDES=(
  'include optional=true "custom/binds.kdl"'
  'include optional=true "custom/privacy.kdl"'
  'include optional=true "dms-ai-agent.kdl"'
)

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

install_packages() {
  step "Installing packages"
  grep -q '^ID=fedora$' /etc/os-release || fail "this script is written for Fedora"
  sudo dnf install -y "${PACKAGES[@]}"
  sudo dnf copr enable -y "$DMS_COPR"
  sudo dnf install -y dms
  sudo dnf install -y "${MPVPAPER_BUILD_PACKAGES[@]}"
}

build_mpvpaper() {
  step "Building mpvpaper for the live wallpaper"
  if command -v mpvpaper >/dev/null || [[ -x "$HOME/.local/bin/mpvpaper" ]]; then
    note "already installed"
    return
  fi
  local build
  build="$(mktemp -d)"
  git clone --quiet --depth 1 --branch "$MPVPAPER_TAG" "$MPVPAPER_REPO" "$build/mpvpaper"
  meson setup "$build/mpvpaper/build" "$build/mpvpaper" --buildtype=release >/dev/null
  ninja -C "$build/mpvpaper/build" >/dev/null
  install -Dm755 "$build/mpvpaper/build/mpvpaper" "$HOME/.local/bin/mpvpaper"
  rm -rf "$build"
  note "installed at $HOME/.local/bin/mpvpaper"
}

# VP9 decodes on the GPU; the H.264 most wallpaper sites ship took a full CPU core in testing.
prepare_wallpaper() {
  local source="$1" target
  [[ -f "$source" ]] || fail "wallpaper not found: $source"
  mkdir -p "$WALLPAPER_DIR"
  target="$WALLPAPER_DIR/$(basename "${source%.*}").webm"
  if [[ "$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$source")" =~ ^(vp9|av1)$ ]]; then
    cp "$source" "$target"
  else
    note "converting $(basename "$source") to VP9, this takes a few minutes" >&2
    ffmpeg -v error -y -i "$source" -an -c:v libvpx-vp9 -b:v 0 -crf 30 -row-mt 1 -cpu-used 4 \
      -pix_fmt yuv420p "$target" || fail "could not convert $source"
  fi
  printf '%s\n' "$target"
}

backup_dir() {
  local dir="$1"
  [[ -e "$dir" ]] || return 0
  cp -a "$dir" "$dir.bak-$STAMP"
  note "backed up $dir to $dir.bak-$STAMP"
}

setup_niri() {
  step "Configuring niri"
  backup_dir "$NIRI_DIR"
  # Without systemd integration DMS starts from the niri config, so it never runs in other sessions.
  dms setup headless --compositor niri --no-systemd --force >/dev/null

  # Keep personal shortcuts in custom/binds.kdl and remove conflicting DMS defaults.
  python3 "$ROOT/lib/apply_niri_binds.py" "$NIRI_DIR/dms/binds.kdl"

  mkdir -p "$NIRI_DIR/custom" "$NIRI_DIR/scripts"
  install -m644 "$ROOT/niri/custom/binds.kdl" "$NIRI_DIR/custom/binds.kdl"
  install -m644 "$ROOT/niri/custom/privacy.kdl" "$NIRI_DIR/custom/privacy.kdl"
  install -m755 "$ROOT/niri/scripts/show-desktop.sh" "$NIRI_DIR/scripts/show-desktop.sh"
  install -m644 "$ROOT/niri/dms-ai-agent.kdl" "$NIRI_DIR/dms-ai-agent.kdl"

  local line
  for line in "${NIRI_INCLUDES[@]}"; do
    grep -qF "$line" "$NIRI_DIR/config.kdl" || printf '%s\n' "$line" >> "$NIRI_DIR/config.kdl"
  done

  niri validate -c "$NIRI_DIR/config.kdl" >/dev/null 2>&1 \
    || fail "niri rejected $NIRI_DIR/config.kdl; run 'niri validate' to see why"
  note "niri config is valid"
}

install_limit_counter() {
  step "Installing the AI Limit Counter"
  rm -rf "$LIMIT_SRC"
  mkdir -p "$(dirname "$LIMIT_SRC")"
  git clone --quiet "$LIMIT_REPO" "$LIMIT_SRC"
  if [[ ! -x "$LIMIT_SRC/dms/install.sh" ]]; then
    git -C "$LIMIT_SRC" checkout --quiet "$LIMIT_BRANCH" \
      || fail "no DMS plugin in $LIMIT_REPO (looked at the default branch and $LIMIT_BRANCH)"
  fi
  [[ -x "$LIMIT_SRC/dms/install.sh" ]] || fail "$LIMIT_REPO has no dms/install.sh"
  "$LIMIT_SRC/dms/install.sh" | sed 's/^/    /'
}

install_agent() {
  step "Installing the AI chat panel"
  backup_dir "$AGENT_DIR"
  rm -rf "$AGENT_DIR"
  mkdir -p "$(dirname "$AGENT_DIR")"

  git clone --quiet "$AGENT_REPO" "$AGENT_DIR"
  git -C "$AGENT_DIR" checkout --quiet -b hardened "$AGENT_COMMIT"
  # Not "origin": the plugin's self-update pulls from origin, and this copy must stay as patched.
  git -C "$AGENT_DIR" remote rename origin fork

  local patch
  for patch in "$ROOT"/patches/*.patch; do
    git -C "$AGENT_DIR" apply --index "$patch" || fail "could not apply $(basename "$patch")"
  done
  git -C "$AGENT_DIR" -c user.name="niri-setup" -c user.email="niri-setup@localhost" \
    commit --quiet --message "Apply niri-setup patches: allowlist, no auto-update, accent rim"
  chmod +x "$AGENT_DIR"/*.sh
  note "installed at $AGENT_DIR (branch hardened)"

  command -v claude >/dev/null \
    || note "claude CLI not found: install Claude Code and log in before using the chat panel"
}

install_local_plugins() {
  step "Installing live mode and the live wallpaper"
  local plugin dest
  for plugin in "${LOCAL_PLUGINS[@]}"; do
    dest="$DMS_DIR/plugins/$plugin"
    mkdir -p "$dest"
    rm -rf "${dest:?}/"*
    cp -r "$ROOT/plugins/$plugin/." "$dest/"
    note "installed at $dest"
  done
}

setup_shell() {
  step "Applying the Ink theme and bar settings"
  install -Dm644 "$ROOT/dms/themes/ink.json" "$DMS_DIR/themes/ink.json"
  local wallpaper_args=()
  [[ -z "$WALLPAPER" ]] || wallpaper_args=(--wallpaper "$WALLPAPER")
  python3 "$ROOT/lib/apply_settings.py" --config-dir "$DMS_DIR" --theme-file "$DMS_DIR/themes/ink.json" \
    "${wallpaper_args[@]}"
}

finish() {
  cat <<'DONE'

Done. The plugins are already enabled and in the bar.
For a live wallpaper, pick a video in Settings > Plugins > Live Wallpaper,
or run this again with --wallpaper FILE.

  1. Log out.
  2. On the login screen pick the "niri" session, then log in.
  3. Your old desktop is still in that same session menu.

Keys (Super is the Windows key):
  Super+T/Enter Ghostty             Super+Space   app launcher
  Ctrl+,        beginning of line   Ctrl+.       end of line
  Ctrl+</>      select to line start/end
  Alt+,/.       move by word        Alt+</>      select by word
  Alt+Left/Right move by word
  Super+H/J/K/L focus windows       add Shift to move them
  Super+U/I     change workspace    add Ctrl to move a window
  Super+Q       close window        Super+D       show desktop
  Super+A       AI chat             Super+Alt+,   settings
  Super+B       power profile
  Super+Shift+/ all shortcuts       Super+Shift+E leave niri

If DMS was already running, restart it to load the changes:
  dms kill; niri msg action spawn -- dms run
DONE
}

main() {
  local skip_packages=0 wallpaper_source=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-packages) skip_packages=1 ;;
      --wallpaper) wallpaper_source="${2:?--wallpaper needs a video file}"; shift ;;
      -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
    shift
  done

  # The configuration belongs to a user, and dms refuses to run as root.
  [[ "$(id -u)" -ne 0 ]] || fail "run this as your normal user; it asks for sudo when it needs it"

  [[ "$skip_packages" -eq 1 ]] || install_packages
  command -v niri >/dev/null || fail "niri is not installed; run without --skip-packages"
  command -v dms >/dev/null || fail "dms is not installed; run without --skip-packages"

  setup_niri
  install_limit_counter
  install_agent
  build_mpvpaper
  install_local_plugins
  WALLPAPER=""
  if [[ -n "$wallpaper_source" ]]; then
    step "Preparing the live wallpaper"
    WALLPAPER="$(prepare_wallpaper "$wallpaper_source")"
    note "using $WALLPAPER"
  fi
  setup_shell
  finish
}

main "$@"
