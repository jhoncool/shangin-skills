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
marketplace_file="$repo_root/.agents/plugins/marketplace.json"
codex_root="${CODEX_HOME:-$HOME/.codex}"
plugin_creator="$codex_root/skills/.system/plugin-creator"
skill_creator="$codex_root/skills/.system/skill-creator"
python_bin="$repo_root/.venv/bin/python3"

if [[ ! -f "$plugin_dir/.codex-plugin/plugin.json" ]]; then
  echo "ERROR: plugin manifest not found: $plugin_dir/.codex-plugin/plugin.json" >&2
  exit 1
fi

if [[ ! -x "$python_bin" ]] || ! "$python_bin" -c "import yaml" >/dev/null 2>&1; then
  echo "ERROR: development environment is missing; run ./scripts/bootstrap-dev.sh" >&2
  exit 1
fi

for helper in \
  "$plugin_creator/scripts/read_marketplace_name.py" \
  "$plugin_creator/scripts/validate_plugin.py" \
  "$skill_creator/scripts/quick_validate.py"; do
  if [[ ! -f "$helper" ]]; then
    echo "ERROR: required Codex helper not found: $helper" >&2
    exit 1
  fi
done

"$python_bin" "$repo_root/scripts/validate-marketplace.py" "$marketplace_file"
"$python_bin" "$plugin_creator/scripts/read_marketplace_name.py" \
  --marketplace-path "$marketplace_file" >/dev/null
"$python_bin" "$plugin_creator/scripts/validate_plugin.py" "$plugin_dir"

skill_count=0
if [[ -d "$plugin_dir/skills" ]]; then
  while IFS= read -r skill_manifest; do
    "$python_bin" "$skill_creator/scripts/quick_validate.py" "$(dirname "$skill_manifest")"
    skill_count=$((skill_count + 1))
  done < <(find "$plugin_dir/skills" -type f -name SKILL.md -print | sort)
fi

echo "Validated $plugin_name and $skill_count discoverable skill(s)."
