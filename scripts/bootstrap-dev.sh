#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
venv_dir="$repo_root/.venv"

if [[ ! -x "$venv_dir/bin/python3" ]]; then
  python3 -m venv "$venv_dir"
fi

"$venv_dir/bin/python3" -m pip install -r "$repo_root/requirements-dev.txt"
echo "Development environment is ready: $venv_dir"
