#!/usr/bin/env bash

set -euo pipefail

workflow=""

usage() {
  printf 'Usage: %s --workflow <deep-code-review|github-pr-worktree-review>\n' "${0##*/}" >&2
}

while (($# > 0)); do
  case "$1" in
    --workflow)
      if (($# < 2)); then
        usage
        exit 2
      fi
      workflow=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR [invalid-argument]: Unknown argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$workflow" in
  deep-code-review|github-pr-worktree-review)
    ;;
  *)
    printf 'ERROR [invalid-workflow]: --workflow must be deep-code-review or github-pr-worktree-review.\n' >&2
    usage
    exit 2
    ;;
esac

script_path=${BASH_SOURCE[0]}
script_dir=${script_path%/*}
if [[ "$script_dir" == "$script_path" ]]; then
  script_dir=.
fi
plugin_root=$(cd -- "$script_dir/.." && pwd -P)

failed=0

if ! command -v git >/dev/null 2>&1; then
  printf 'ERROR [missing-git]: Deep Code Review requires Git. Install Git, then run this check again.\n' >&2
  failed=1
elif ! git_version=$(git --version 2>/dev/null); then
  printf 'ERROR [unusable-git]: Git is installed but cannot run. Repair Git, then run this check again.\n' >&2
  failed=1
else
  printf 'OK [git]: %s\n' "$git_version"
fi

for bundled_skill in deep-code-review github-pr-worktree-review; do
  skill_file="$plugin_root/skills/$bundled_skill/SKILL.md"
  if [[ ! -f "$skill_file" ]]; then
    printf 'ERROR [invalid-bundle]: Missing bundled skill: %s. Reinstall the Deep Code Review plugin, then start a new task.\n' "$bundled_skill" >&2
    failed=1
  fi
done

required_bundle_files=(
  "skills/deep-code-review/references/mattpocock-code-review/reference.md"
  "skills/deep-code-review/references/mattpocock-code-review/upstream.md"
  "skills/deep-code-review/references/mattpocock-code-review/LICENSE"
  "skills/deep-code-review/references/mattpocock-code-review/source.json"
  "skills/github-pr-worktree-review/scripts/prepare-review.sh"
)

for relative_path in "${required_bundle_files[@]}"; do
  if [[ ! -f "$plugin_root/$relative_path" ]]; then
    printf 'ERROR [invalid-bundle]: Missing bundled file: %s. Reinstall the Deep Code Review plugin, then start a new task.\n' "$relative_path" >&2
    failed=1
  fi
done

prepare_script="$plugin_root/skills/github-pr-worktree-review/scripts/prepare-review.sh"
if [[ -f "$prepare_script" && ! -x "$prepare_script" ]]; then
  printf 'ERROR [invalid-bundle]: Bundled preparation script is not executable. Reinstall the Deep Code Review plugin, then start a new task.\n' >&2
  failed=1
fi

if ((failed != 0)); then
  exit 1
fi

printf 'OK [bundle]: Deep Code Review and GitHub PR Worktree Review are bundled.\n'
printf 'OK [mattpocock-code-review]: Matt Pocock code-review checks are bundled; no separate npx installation is required.\n'

if command -v gh >/dev/null 2>&1; then
  printf 'OK [gh]: GitHub CLI is installed. The skill will verify access with the required read-only PR lookup.\n'
else
  if [[ "$workflow" == github-pr-worktree-review ]]; then
    printf 'WARNING [missing-gh]: GitHub CLI is unavailable. Continue in git-only mode with a full PR URL and an explicit base branch.\n' >&2
  else
    printf 'WARNING [missing-gh]: GitHub CLI is unavailable. Local Git review can continue, but GitHub PR metadata will not be available.\n' >&2
  fi
fi

printf 'OK [preflight]: %s can start.\n' "$workflow"
