//! JSON adapter around the original Kopuz lyric provider modules.
#![allow(dead_code, unused_imports)]
mod lyrics;
use lyrics::{Lyrics, LyricsRequest};
use serde_json::{Value, json};
use std::io::Write;
use std::hash::{Hash, Hasher};

fn to_json(result: lyrics::LyricsFetch) -> Value {
    match result.lyrics {
        Some(Lyrics::Synced(lines)) => {
            let mut indexed: Vec<_> = lines.into_iter().enumerate().filter(|(_, line)| line.start_time.is_finite()).collect();
            let remap: std::collections::HashMap<_, _> = indexed.iter().enumerate().map(|(new_index, (old_index, _))| (*old_index, new_index)).collect();
            // Preserve source order and remap parent indexes if malformed lines
            // were removed; background vocals need not be timestamp-sorted.
            for (_, line) in &mut indexed {
                line.chunks.retain(|chunk| chunk.start_time.is_finite());
                line.end_time = line.end_time.filter(|time| time.is_finite());
                line.parent_line_index = line.parent_line_index.and_then(|index| remap.get(&index).copied());
            }
            let lines: Vec<_> = indexed.into_iter().map(|(_, line)| line).collect();
            let word_timed = lines.iter().any(|line| line.chunks.len() > 1);
            json!({"status": "synced", "engine": "Kopuz", "word_timed": word_timed, "lines": lines})
        }
        Some(Lyrics::Plain(text)) => json!({
            "status": "plain", "engine": "Kopuz", "word_timed": false,
            "lines": text.lines().map(|text| json!({"start_time": -1, "text": text, "chunks": []})).collect::<Vec<_>>()
        }),
        None => json!({"status": if result.conclusive { "not_found" } else { "error" }, "engine": "Kopuz", "lines": []}),
    }
}

async fn run() -> Value {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.len() < 4 || args[0].trim().is_empty() || args[1].trim().is_empty() {
        return json!({"status": "no_info", "engine": "Kopuz", "lines": []});
    }
    let duration = args[3].parse::<f64>().unwrap_or_default();
    let duration = if duration.is_finite() && duration > 0.0 { duration.round() as u64 } else { 0 };
    let path = args.get(4).cloned().unwrap_or_default();
    let path = if path.starts_with("file://") {
        percent_encoding::percent_decode_str(path.trim_start_matches("file://")).decode_utf8_lossy().into_owned()
    } else { path };
    let musixmatch_enabled = args.iter().skip(5).any(|arg| arg == "--musixmatch");
    let request = LyricsRequest::new(&args[1], &args[0], &args[2], duration, path).enable_musixmatch(musixmatch_enabled);
    // The standalone helper persists answers without opening Kopuz's library DB.
    let mut hash = std::collections::hash_map::DefaultHasher::new();
    request.cache_key().hash(&mut hash);
    let cache_dir = std::env::var_os("XDG_CACHE_HOME").map(std::path::PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| std::path::PathBuf::from(home).join(".cache")))
        .map(|base| base.join("dms-kopuz-lyrics"));
    let cache_path = cache_dir.as_ref().map(|dir| dir.join(format!("{:016x}.json", hash.finish())));
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|v| v.as_secs()).unwrap_or_default();
    if !args.iter().skip(5).any(|arg| arg == "--refresh") {
        if let Some(path) = &cache_path {
            if let Ok(bytes) = std::fs::read(path) {
                if let Ok(cached) = serde_json::from_slice::<Value>(&bytes) {
                    let ttl = if cached["result"]["status"] == "not_found" { 86400 } else { 604800 };
                    if cached["saved_at"].as_u64().is_some_and(|saved| now.saturating_sub(saved) < ttl) {
                        return cached["result"].clone();
                    }
                }
            }
        }
    }
    // No app credentials are needed for Kopuz's public provider chain.
    let mut result = match tokio::time::timeout(std::time::Duration::from_secs(35), lyrics::fetch_lyrics_for_request(&request)).await {
        Ok(result) => to_json(result),
        Err(_) => json!({"status": "error", "engine": "Kopuz", "lines": []}),
    };
    result["musixmatch_enabled"] = json!(musixmatch_enabled);
    if matches!(result["status"].as_str(), Some("synced" | "plain" | "not_found")) {
        if let (Some(dir), Some(path)) = (cache_dir, cache_path) {
            if std::fs::create_dir_all(dir).is_ok() {
                let temporary = path.with_extension(format!("{}.tmp", std::process::id()));
                let payload = json!({"saved_at": now, "result": result});
                if std::fs::write(&temporary, payload.to_string()).is_ok() {
                    let _ = std::fs::rename(temporary, path);
                }
            }
        }
    }
    result
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    if std::env::var_os("DMS_KOPUZ_LYRICS_TRACE").is_some() {
        let _ = tracing_subscriber::fmt().with_writer(std::io::stderr).with_ansi(false)
            .with_env_filter("kopuz::lyrics=info,dms_kopuz_lyrics=info").try_init();
    }
    let result = run().await;
    let mut stdout = std::io::stdout().lock();
    let _ = serde_json::to_writer(&mut stdout, &result);
    let _ = writeln!(stdout);
}

#[cfg(test)]
mod adapter_tests {
    use super::*;
    fn line(time: f64, parent: Option<usize>) -> lyrics::LyricLine {
        lyrics::LyricLine {
            start_time: time, end_time: None, text: "test".into(), chunks: vec![],
            parent_line_index: parent, background: parent.is_some(), opposite_turn: false,
        }
    }
    #[test]
    fn removing_invalid_timestamps_remaps_background_parents() {
        let value = to_json(lyrics::LyricsFetch { lyrics: Some(Lyrics::Synced(vec![line(f64::NAN, None), line(3.0, None), line(3.5, Some(1))])), conclusive: true });
        assert_eq!(value["lines"].as_array().map(Vec::len), Some(2));
        assert_eq!(value["lines"][1]["parent_line_index"], 0);
    }
    #[test]
    fn unreachable_provider_does_not_become_a_definitive_missing_lyric() {
        assert_eq!(to_json(lyrics::LyricsFetch { lyrics: None, conclusive: false })["status"], "error");
        assert_eq!(to_json(lyrics::LyricsFetch { lyrics: None, conclusive: true })["status"], "not_found");
    }
}
