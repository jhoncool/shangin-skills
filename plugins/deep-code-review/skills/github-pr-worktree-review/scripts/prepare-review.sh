#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  prepare-review.sh --pr <url-or-number> [--base <branch>] [--remote <name>] [--checkout]
  prepare-review.sh --branch <head-branch> [--base <branch>] [--remote <name>] [--checkout]

Fetches stable local review refs and prints the exact comparison metadata.
With --checkout, detaches only a clean linked worktree at the fetched head.
When gh cannot supply metadata, --pr requires a full PR URL and an explicit --base branch.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

repo_from_remote_url() {
  remote_url_value="$1"
  case "$remote_url_value" in
    *://*)
      remote_path=${remote_url_value#*://}
      remote_path=${remote_path#*/}
      ;;
    *:*)
      remote_path=${remote_url_value#*:}
      ;;
    *)
      return 1
      ;;
  esac
  remote_path=${remote_path%.git}
  case "$remote_path" in
    */*) printf '%s\n' "$remote_path" ;;
    *) return 1 ;;
  esac
}

pr_target=""
head_branch=""
base_branch=""
remote_name="origin"
checkout_requested="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pr)
      [ "$#" -ge 2 ] || fail "--pr requires a URL or number"
      pr_target="$2"
      shift 2
      ;;
    --branch)
      [ "$#" -ge 2 ] || fail "--branch requires a branch name"
      head_branch="$2"
      shift 2
      ;;
    --base)
      [ "$#" -ge 2 ] || fail "--base requires a branch name"
      base_branch="$2"
      shift 2
      ;;
    --remote)
      [ "$#" -ge 2 ] || fail "--remote requires a remote name"
      remote_name="$2"
      shift 2
      ;;
    --checkout)
      checkout_requested="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if [ -n "$pr_target" ] && [ -n "$head_branch" ]; then
  fail "Choose either --pr or --branch, not both"
fi
if [ -z "$pr_target" ] && [ -z "$head_branch" ]; then
  usage >&2
  fail "Provide --pr or --branch"
fi
case "$remote_name" in
  -*) fail "Remote name must not start with '-'" ;;
esac
case "$pr_target" in
  -*) fail "PR target must not start with '-'" ;;
esac

require_command git
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Run this script inside a Git working tree"
git remote get-url "$remote_name" >/dev/null 2>&1 || fail "Git remote not found: $remote_name"

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"
git_dir=$(git rev-parse --absolute-git-dir)
git_dir=$(cd "$git_dir" && pwd -P)

stage_token=$(printf '%s\n' "$git_dir:$$:$(date +%s)" | git hash-object --stdin)
fetch_base_ref="refs/codex-review/staging/$stage_token/base"
fetch_head_ref="refs/codex-review/staging/$stage_token/head"

cleanup_staging_refs() {
  git update-ref -d "$fetch_base_ref" >/dev/null 2>&1 || true
  git update-ref -d "$fetch_head_ref" >/dev/null 2>&1 || true
}
trap cleanup_staging_refs EXIT

if [ "$checkout_requested" = "true" ]; then
  if common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    :
  else
    common_dir_raw=$(git rev-parse --git-common-dir)
    common_dir=$(cd "$common_dir_raw" && pwd -P)
  fi
  common_dir=$(cd "$common_dir" && pwd -P)
  [ "$git_dir" != "$common_dir" ] || fail "Refusing to switch the main checkout. Start or hand off this task in a linked Worktree."
  [ -z "$(git status --porcelain --untracked-files=all)" ] || fail "Refusing to switch a dirty worktree. Preserve or remove its changes first."
fi

mode=""
pr_number=""
pr_url=""
current_repo=""
metadata_source=""

if [ -n "$pr_target" ]; then
  metadata_lookup_succeeded="false"
  if command -v gh >/dev/null 2>&1; then
    if current_repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) && \
       pr_line=$(gh pr view "$pr_target" \
         --json number,url,baseRefName,headRefName \
         --template '{{.number}}{{"\t"}}{{.url}}{{"\t"}}{{.baseRefName}}{{"\t"}}{{.headRefName}}{{"\n"}}' 2>/dev/null); then
      IFS=$'\t' read -r pr_number pr_url detected_base head_branch <<< "$pr_line"
      if [ -n "$pr_number" ] && [ -n "$pr_url" ] && [ -n "$detected_base" ] && [ -n "$head_branch" ]; then
        metadata_source="gh"
        metadata_lookup_succeeded="true"
      fi
    fi
  fi

  if [ "$metadata_lookup_succeeded" != "true" ]; then
    [ -n "$base_branch" ] || fail "Could not read PR metadata with gh. Git-only preparation requires --base <branch>."
    if command -v gh >/dev/null 2>&1; then
      printf 'WARNING: gh metadata lookup failed; using git-only PR preparation.\n' >&2
    fi
    pr_url="$pr_target"
    pr_number=$(printf '%s\n' "$pr_url" | sed -E 's~^https?://[^/]+/[^/]+/[^/]+/pull/([0-9]+)([/?#].*)?$~\1~')
    case "$pr_number" in
      ''|*[!0-9]*) fail "Could not read PR metadata with gh. Supply a full PR URL and --base <branch> for git-only preparation." ;;
    esac
    remote_url=$(git config --get "remote.$remote_name.url")
    current_repo=$(repo_from_remote_url "$remote_url") || fail "Could not derive owner/repository from remote URL: $remote_url"
    detected_base="$base_branch"
    head_branch="pr-$pr_number"
    metadata_source="git-only"
  fi

  pr_repo=$(printf '%s\n' "$pr_url" | sed -E 's~^https?://[^/]+/([^/]+/[^/]+)/pull/[0-9]+([/?#].*)?$~\1~')
  [ "$pr_repo" != "$pr_url" ] || fail "Could not derive the repository from PR URL: $pr_url"
  normalized_pr_repo=$(printf '%s' "$pr_repo" | tr '[:upper:]' '[:lower:]')
  normalized_current_repo=$(printf '%s' "$current_repo" | tr '[:upper:]' '[:lower:]')
  [ "$normalized_pr_repo" = "$normalized_current_repo" ] || fail "PR belongs to $pr_repo, but the current repository is $current_repo"

  if [ -z "$base_branch" ]; then
    base_branch="$detected_base"
  fi
  git check-ref-format --branch "$base_branch" >/dev/null 2>&1 || fail "Invalid base branch: $base_branch"

  mode="pr"
  git fetch --no-tags "$remote_name" \
    "+refs/heads/$base_branch:$fetch_base_ref" \
    "+refs/pull/$pr_number/head:$fetch_head_ref"

  fetched_head_oid=$(git rev-parse "$fetch_head_ref^{commit}")
  if [ "$metadata_source" = "gh" ]; then
    latest_head_oid=$(gh pr view "$pr_url" --json headRefOid --jq '.headRefOid')
    if [ "$fetched_head_oid" != "$latest_head_oid" ]; then
      git fetch --no-tags "$remote_name" "+refs/pull/$pr_number/head:$fetch_head_ref"
      fetched_head_oid=$(git rev-parse "$fetch_head_ref^{commit}")
    fi
    [ "$fetched_head_oid" = "$latest_head_oid" ] || fail "PR head changed while it was being prepared. Run the command again."
  fi
else
  git check-ref-format --branch "$head_branch" >/dev/null 2>&1 || fail "Invalid head branch: $head_branch"
  if [ -z "$base_branch" ]; then
    require_command gh
    base_branch=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
  fi
  git check-ref-format --branch "$base_branch" >/dev/null 2>&1 || fail "Invalid base branch: $base_branch"

  mode="branch"
  git fetch --no-tags "$remote_name" \
    "+refs/heads/$base_branch:$fetch_base_ref" \
    "+refs/heads/$head_branch:$fetch_head_ref"
  fetched_head_oid=$(git rev-parse "$fetch_head_ref^{commit}")
fi

base_oid=$(git rev-parse "$fetch_base_ref^{commit}")
head_oid=$(git rev-parse "$fetch_head_ref^{commit}")
if ! merge_base_oid=$(git merge-base "$base_oid" "$head_oid"); then
  fail "The fetched base and head do not share Git history. Verify --base, --branch or --pr, and --remote."
fi
[ -n "$merge_base_oid" ] || fail "The fetched base and head do not share Git history. Verify --base, --branch or --pr, and --remote."

base_ref="refs/codex-review/snapshots/$base_oid"
head_ref="refs/codex-review/snapshots/$head_oid"
git update-ref "$base_ref" "$base_oid"
git update-ref "$head_ref" "$head_oid"

if [ "$checkout_requested" = "true" ]; then
  git switch --detach "$head_ref" >/dev/null
  checkout_oid=$(git rev-parse HEAD)
else
  checkout_oid="not-requested"
fi

printf 'MODE=%s\n' "$mode"
[ -z "$metadata_source" ] || printf 'METADATA_SOURCE=%s\n' "$metadata_source"
[ -z "$current_repo" ] || printf 'REPOSITORY=%s\n' "$current_repo"
[ -z "$pr_number" ] || printf 'PR_NUMBER=%s\n' "$pr_number"
[ -z "$pr_url" ] || printf 'PR_URL=%s\n' "$pr_url"
printf 'REMOTE=%s\n' "$remote_name"
printf 'BASE_BRANCH=%s\n' "$base_branch"
printf 'HEAD_BRANCH=%s\n' "$head_branch"
printf 'BASE_REF=%s\n' "$base_ref"
printf 'HEAD_REF=%s\n' "$head_ref"
printf 'BASE_OID=%s\n' "$base_oid"
printf 'HEAD_OID=%s\n' "$head_oid"
printf 'MERGE_BASE_OID=%s\n' "$merge_base_oid"
printf 'DIFF_RANGE=%s...%s\n' "$base_oid" "$head_oid"
printf 'COMMIT_RANGE=%s..%s\n' "$base_oid" "$head_oid"
printf 'CHECKOUT_OID=%s\n' "$checkout_oid"
