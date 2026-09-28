#!/usr/bin/env bash
# Set up niri + DankMaterialShell on Fedora: the Ink theme, the AI Limit Counter in the bar
# and the AI chat panel. Your current desktop (KDE, GNOME) stays installed and untouched;
# niri is added as one more session on the login screen.
#
#   ./install.sh                     everything
#   ./install.sh --wallpaper FILE    also use FILE as the live wallpaper (converted to VP9)
#   ./install.sh --skip-packages     configuration only (niri and dms are already installed)
#   ./install.sh --voice             also set up voice input for the AI chat (local Whisper, 1-3 GB)
#   ./install.sh --gaming            also apply the gaming tweaks in system/ (asks for sudo)
#   ./install.sh --profile NAME      also apply your personal settings from profiles/NAME
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
NIRI_DIR="$CONFIG_HOME/niri"
DMS_DIR="$CONFIG_HOME/DankMaterialShell"
STAMP="$(date +%Y%m%d-%H%M%S)"

TERMINAL="kitty"
DMS_COPR="avengemedia/dms"
PACKAGES=(
  niri xwayland-satellite xdg-desktop-portal-gnome "$TERMINAL"
  git cargo python3 jq patch
  dbus-devel pkgconf-pkg-config
  gtk3 xdg-utils libnotify playerctl wl-clipboard procps-ng
  qt6-qtmultimedia ffmpeg-free
)

# The chat panel is pinned to the commit the patches in patches/ were written against.
AGENT_REPO="https://github.com/Cha1000000/dms-ai-agent"
AGENT_COMMIT="a3f4a1114942fdc715e97ddb3a6680811ff38cb9"
AGENT_DIR="$DMS_DIR/plugins/dmsAgent"

# The limit counter has its own repository. Until its DMS plugin is merged into the
# default branch, the plugin lives on LIMIT_BRANCH.
LIMIT_REPO="https://github.com/Phirios/AILimitCounter"
LIMIT_BRANCH="feat/dms-plugin"
LIMIT_SRC="$DATA_HOME/niri-setup/AILimitCounter"
LOCAL_PLUGINS=(liveMode liveWallpaper)
WALLPAPER_DIR="$HOME/Videos/Wallpapers"

NIRI_INCLUDES=(
  'include optional=true "custom/binds.kdl"'
  'include optional=true "custom/privacy.kdl"'
  'include optional=true "custom/wallpaper.kdl"'
  'include optional=true "dms-ai-agent.kdl"'
  # A personal profile, loaded last so its keys replace the shared ones; see profiles/README.md.
  'include optional=true "profile/apps.kdl"'
  'include optional=true "profile/binds.kdl"'
)

# Whisper for the chat panel's mic button; the same path the plugin's voice.py looks in.
VOICE_VENV="$DATA_HOME/dms-ai-agent/whisper-venv"
VOICE_CPP_DIR="$HOME/.local/share/dms-ai-agent/whisper.cpp"
VOICE_CPP_COMMIT="d09f61a708f3487afa956ff578e60eae5e7a233c"

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

install_packages() {
  step "Installing packages"
  grep -q '^ID=fedora$' /etc/os-release || fail "this script is written for Fedora"
  sudo dnf install -y "${PACKAGES[@]}"
  sudo dnf copr enable -y "$DMS_COPR"
  sudo dnf install -y dms
}

# Store a broadly supported, silent video for the wallpaper player.
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

  # DMS assumes ghostty, which Fedora does not ship.
  sed -i "s/TERMINAL \"ghostty\"/TERMINAL \"$TERMINAL\"/" "$NIRI_DIR/config.kdl"
  sed -i "s/{ spawn \"ghostty\"; }/{ spawn \"$TERMINAL\"; }/" "$NIRI_DIR/dms/binds.kdl"

  mkdir -p "$NIRI_DIR/custom" "$NIRI_DIR/scripts"
  install -m644 "$ROOT/niri/custom/binds.kdl" "$NIRI_DIR/custom/binds.kdl"
  install -m644 "$ROOT/niri/custom/privacy-rules.kdl" "$NIRI_DIR/custom/privacy-rules.kdl"
  # The switch that live mode flips; a re-run keeps whatever it was set to.
  [[ -e "$NIRI_DIR/custom/privacy.kdl" ]] && grep -q "Live Mode plugin" "$NIRI_DIR/custom/privacy.kdl" \
    || install -m644 "$ROOT/niri/custom/privacy.kdl" "$NIRI_DIR/custom/privacy.kdl"
  # App placement moved into the profiles; an old shared copy would repeat the workspaces.
  rm -f "$NIRI_DIR/custom/apps.kdl"
  rm -rf "$NIRI_DIR/profile"
  if [[ -n "$PROFILE_DIR" ]]; then
    mkdir -p "$NIRI_DIR/profile"
    local file
    for file in binds.kdl apps.kdl; do
      [[ -f "$PROFILE_DIR/$file" ]] && install -m644 "$PROFILE_DIR/$file" "$NIRI_DIR/profile/$file"
    done
    printf '%s\n' "$(basename "$PROFILE_DIR")" > "$NIRI_DIR/profile/NAME"
  fi
  install -m644 "$ROOT/niri/custom/wallpaper.kdl" "$NIRI_DIR/custom/wallpaper.kdl"
  install -m755 "$ROOT/niri/scripts/show-desktop.sh" "$NIRI_DIR/scripts/show-desktop.sh"
  install -m755 "$ROOT/niri/scripts/dms-run.sh" "$NIRI_DIR/scripts/dms-run.sh"
  install -m644 "$ROOT/niri/scripts/dms-wallpaper-picker.patch" "$NIRI_DIR/scripts/dms-wallpaper-picker.patch"
  install -m644 "$ROOT/niri/scripts/dms-tailscale-control-center.patch" \
    "$NIRI_DIR/scripts/dms-tailscale-control-center.patch"
  install -Dm755 "$ROOT/niri/scripts/dms-live-wallpaper-thumbnails" \
    "$HOME/.local/bin/dms-live-wallpaper-thumbnails"
  install -m755 "$ROOT/niri/scripts/live-wallpaper-cycle.sh" "$NIRI_DIR/scripts/live-wallpaper-cycle.sh"
  install -m755 "$ROOT/niri/scripts/grid.py" "$NIRI_DIR/scripts/grid.py"
  # Start DMS from a patched copy of its UI; see the script for the patch.
  sed -i 's|^spawn-at-startup "dms" "run"$|spawn-at-startup "sh" "-c" "exec ~/.config/niri/scripts/dms-run.sh"|' \
    "$NIRI_DIR/config.kdl"
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
    commit --quiet --message "Apply niri-setup patches: safety, AMD voice, Codex, adaptive UI"
  chmod +x "$AGENT_DIR"/*.sh
  note "installed at $AGENT_DIR (branch hardened)"

  command -v claude >/dev/null \
    || note "claude CLI not found: install Claude Code and log in before using the chat panel"
  command -v codex >/dev/null \
    || note "codex CLI not found: install Codex and log in before choosing it in the chat panel"
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

# GNOME and KDE start Steam on the NVIDIA card because its desktop file asks for it
# (PrefersNonDefaultGPU); niri ignores that, so native OpenGL games like Half-Life ran on the
# Intel GPU. A user copy of the desktop file sets the offload variables itself.
setup_steam_gpu() {
  local system_file="/usr/share/applications/steam.desktop"
  [[ -f "$system_file" ]] || return 0
  command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1 || return 0
  step "Starting Steam on the NVIDIA card"
  mkdir -p "$DATA_HOME/applications"
  sed -E 's#^Exec=#Exec=env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only #' \
    "$system_file" > "$DATA_HOME/applications/steam.desktop"
  note "installed $DATA_HOME/applications/steam.desktop; start Steam from the launcher to use it"
}

setup_voice() {
  step "Setting up voice input (Whisper)"
  local python="$VOICE_VENV/bin/python"
  if [[ ! -x "$python" ]]; then
    mkdir -p "$(dirname "$VOICE_VENV")"
    python3 -m venv "$VOICE_VENV" || fail "python3 could not create $VOICE_VENV"
  fi
  "$python" -m pip install --quiet --upgrade faster-whisper || fail "could not install faster-whisper"
  local model="small"
  if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
    # cuBLAS and cuDNN from pip; voice.py points the loader at them, no CUDA toolkit needed.
    if "$python" -m pip install --quiet --upgrade nvidia-cublas-cu12 nvidia-cudnn-cu12; then
      model="large-v3-turbo"
    else
      note "CUDA libraries failed to install; speech recognition will use the CPU"
    fi
  fi
  note "downloading the Whisper model $model (one time)"
  "$python" -c "from faster_whisper import download_model; download_model('$model')" >/dev/null \
    || note "model download failed; it is retried the first time you use the mic"

  # whisper.cpp's Vulkan backend provides GPU acceleration on AMD (and other
  # Vulkan-capable GPUs); faster-whisper remains the CUDA/CPU fallback.
  step "Building the Vulkan Whisper backend"
  sudo dnf install -y cmake gcc-c++ glslang vulkan-headers vulkan-loader-devel
  if [[ ! -d "$VOICE_CPP_DIR/.git" ]]; then
    mkdir -p "$(dirname "$VOICE_CPP_DIR")"
    git clone --quiet https://github.com/ggml-org/whisper.cpp.git "$VOICE_CPP_DIR"
  fi
  git -C "$VOICE_CPP_DIR" checkout --quiet --detach "$VOICE_CPP_COMMIT"
  cmake -S "$VOICE_CPP_DIR" -B "$VOICE_CPP_DIR/build-vulkan" \
    -DGGML_VULKAN=1 -DCMAKE_BUILD_TYPE=Release
  cmake --build "$VOICE_CPP_DIR/build-vulkan" --config Release -j "$(nproc)"
  mkdir -p "$HOME/.local/share/dms-ai-agent/models"
  if [[ ! -f "$HOME/.local/share/dms-ai-agent/models/ggml-small.bin" ]]; then
    bash "$VOICE_CPP_DIR/models/download-ggml-model.sh" small \
      "$HOME/.local/share/dms-ai-agent/models"
  fi
}

setup_gaming() {
  step "Applying the gaming tweaks"
  sudo dnf install -y gamemode
  sudo install -Dm644 "$ROOT/system/gamemode.ini" /etc/gamemode.ini
  sudo install -Dm644 "$ROOT/system/coredump-off.conf" /etc/systemd/coredump.conf.d/99-disable.conf
  # The file indexer took most of a core while games were running.
  gsettings set org.freedesktop.Tracker3.Miner.Files throttle 15 2>/dev/null || true
  note "add 'gamemoderun %command%' to a game's Steam launch options to use gamemode"
}

setup_shell() {
  step "Applying the Ink theme and bar settings"
  install -Dm644 "$ROOT/dms/themes/ink.json" "$DMS_DIR/themes/ink.json"
  local settings_args=()
  [[ -z "$WALLPAPER" ]] || settings_args=(--wallpaper "$WALLPAPER")
  [[ "$WITH_VOICE" -eq 0 ]] || settings_args+=(--voice)
  [[ -z "$PROFILE_DIR" ]] || settings_args+=(--profile-dir "$PROFILE_DIR")
  python3 "$ROOT/lib/apply_settings.py" --config-dir "$DMS_DIR" --theme-file "$DMS_DIR/themes/ink.json" \
    "${settings_args[@]}"
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
  Super+T       terminal            Super+Space   app launcher
  Super+Q       close window        Super+D       show desktop
  Super+A       AI chat             Super+Comma   settings
  Super+B       power profile       Super+G       windows in a grid
  Super+Shift+G undo the grid
  Super+Shift+/ all shortcuts       Super+Shift+E leave niri

If DMS was already running, restart it to load the changes:
  dms kill; niri msg action spawn -- sh -c "exec ~/.config/niri/scripts/dms-run.sh"
DONE
}

main() {
  local skip_packages=0 wallpaper_source="" gaming=0
  PROFILE_DIR=""
  WITH_VOICE=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-packages) skip_packages=1 ;;
      --voice) WITH_VOICE=1 ;;
      --gaming) gaming=1 ;;
      --wallpaper) wallpaper_source="${2:?--wallpaper needs a video file}"; shift ;;
      --profile)
        PROFILE_DIR="$ROOT/profiles/${2:?--profile needs a folder name from profiles/}"
        [[ -d "$PROFILE_DIR" ]] || fail "no profile named $2 in $ROOT/profiles"
        shift ;;
      -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
  install_local_plugins
  WALLPAPER=""
  if [[ -n "$wallpaper_source" ]]; then
    step "Preparing the live wallpaper"
    WALLPAPER="$(prepare_wallpaper "$wallpaper_source")"
    note "using $WALLPAPER"
  fi
  [[ "$WITH_VOICE" -eq 0 ]] || setup_voice
  setup_steam_gpu
  [[ "$gaming" -eq 0 ]] || setup_gaming
  setup_shell
  finish
}

main "$@"
