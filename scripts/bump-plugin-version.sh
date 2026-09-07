#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <plugin-name>" >&2
  exit 2
fi

plugin_name="$1"
if [[ ! "$plugin_name" =~ ^[A-Za-z0-9_-]+([.][A-Za-z0-9_-]+)*$ ]]; then
  echo "ERROR: invalid plugin name: $plugin_name" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_dir="$repo_root/plugins/$plugin_name"
codex_root="${CODEX_HOME:-$HOME/.codex}"
plugin_creator="$codex_root/skills/.system/plugin-creator"

if [[ ! -f "$plugin_dir/.codex-plugin/plugin.json" ]]; then
  echo "ERROR: plugin manifest not found: $plugin_dir/.codex-plugin/plugin.json" >&2
  exit 1
fi

if [[ ! -f "$plugin_creator/scripts/update_plugin_cachebuster.py" ]]; then
  echo "ERROR: Codex plugin-creator helper not found under $plugin_creator" >&2
  exit 1
fi

python3 "$plugin_creator/scripts/update_plugin_cachebuster.py" "$plugin_dir"
"$repo_root/scripts/validate-plugin.sh" "$plugin_name"
