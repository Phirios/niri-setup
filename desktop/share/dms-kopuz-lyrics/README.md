# DMS Kopuz lyrics bridge

The DMS hover-player panel uses this JSON command-line adapter around the original lyrics engine in `/home/phirios/Projects/kopuz`. The provider module directory and lyric data model are vendored from that checkout; they are not a Python reimplementation. Kopuz's files and library database are left untouched.

Rebuild after updating Kopuz:

```sh
/home/phirios/.local/share/dms-kopuz-lyrics/rebuild.sh
```

The helper takes `title artist album duration_seconds [track_path] [--refresh] [--musixmatch]` and emits one JSON object. It preserves line/chunk timestamps, end times, background vocals, parent links, and opposite turns. Public providers and local/embedded lyrics use Kopuz's original selection code. Musixmatch defaults to disabled and is controlled independently by DMS Settings → Media Player → Lyrics → Musixmatch lyrics (`mediaLyricsMusixmatchEnabled`). The panel passes `--musixmatch` when enabled; provider settings are part of the cache key. Authenticated Jellyfin, Subsonic, and Apple Music requests require credentials unavailable through MPRIS and are not configured by this adapter.

Answers live in `~/.cache/dms-kopuz-lyrics`, separately from the Kopuz database: successful results expire after seven days; definitive misses after one day. Network failures are never cached as misses. The panel's Retry action bypasses this cache.

Panel: `~/.local/share/dms-shell-custom/Modules/DankDash/MediaLyricsPanel.qml`.
The standalone helper has its own Cargo lockfile and avoids building the full music app and browser runtime. Original source licensing is EUPL-1.2; see the Kopuz checkout's license.

## Lyrics panel appearance

The panel has a transparent surface, larger text, GPU edge fades and a soft left-to-right glyph wipe. Completed chunks stay lit. Background rows show only during their own timing or while their parent is current. Click a timed line to seek. Scrolling follows Kopuz: the active line starts at 42% of the viewport, movement uses a 720 ms cubic ease, and manual scrolling pauses following until Follow lyrics is clicked or a timed line is selected. There is no timed resume cooldown. Shader sources and baked Qt shader bundles are alongside the panel in `Modules/DankDash`; rebake with `/usr/lib64/qt6/bin/qsb` after editing GLSL. UI rollback files are in `~/.local/state/dms-lyrics-stage/ui/`.

Foreground activation also follows Kopuz's seamless-gap rule: if the next line starts at most three seconds after the explicit end, keep the current line lit and enlarged until the next starts. Longer gaps clear activation. Explicit background-vocal ends are not extended.
