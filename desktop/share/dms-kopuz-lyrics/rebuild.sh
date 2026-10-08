#!/bin/sh
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cargo build --release --locked --manifest-path "$bridge_dir/Cargo.toml"
install -m 755 "$bridge_dir/target/release/dms-kopuz-lyrics" "$HOME/.local/bin/dms-kopuz-lyrics"
