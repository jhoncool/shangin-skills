---
name: github-pr-worktree-review
description: Prepare and deeply review a GitHub pull request or remote branch inside an isolated Git worktree using the required bundled Deep Code Review skill and available Yandex Tracker context. Use when the user provides a GitHub PR URL, PR number, or remote branch and asks for a PR review, branch review, pre-merge audit, exact base-to-head comparison, or safe review without disturbing the main checkout. Stop with a dependency error when `$deep-code-review` is unavailable.
---

# GitHub PR Worktree Review

Review the requested GitHub change set from an isolated linked worktree. Do not edit code, post to GitHub, create commits, or push unless the user separately requests that action.

## Required dependency and preflight

Before running commands, reading PR metadata, fetching refs, or changing a checkout, verify that the bundled `$deep-code-review` skill is available in the current task's skill catalog. If it is unavailable, stop immediately. Do not prepare the worktree and do not perform a fallback review. Return this error exactly:

```text
ERROR [missing-dependency]: GitHub PR Worktree Review requires the bundled $deep-code-review skill. Reinstall or enable the Deep Code Review plugin, then start a new task.
```

After the catalog check succeeds, run the bundled preflight from this skill's installed directory:

```bash
<skill-dir>/../../scripts/doctor.sh --workflow github-pr-worktree-review
```

Stop on any `ERROR` and return the script's remediation. Do not install system programs or external plugins automatically. A `WARNING [missing-gh]` activates the git-only prerequisites below; it does not by itself block the review.

## Prerequisites

- Work inside the repository that owns the requested PR or branch.
- Require `git`. Prefer an authenticated `gh` for PR metadata and automatic base detection.
- When `gh` is absent or still unusable after the allowed-context retry, require a full PR URL plus an explicit `--base <branch>`. Treat missing remote PR description, checks, and review status as residual risk.
- Start or hand off the task into a Codex Worktree before checkout. Never switch the user's main checkout merely to perform a review.
- Treat the GitHub plugin as optional context; use local Git refs as the source of truth for the diff.

### Verify `gh` in constrained environments

Verify access with the read-only operation the review needs, not with a standalone `gh auth status` probe:

```bash
gh pr view <url-or-number> --json number,url,baseRefName,headRefName
```

If this command fails inside a sandbox with an authentication or network error, retry the same command in an allowed host/network context before declaring `gh` unavailable or asking the user to re-authenticate. A sandbox may read the account entry from `hosts.yml` while being unable to reach `api.github.com` or retrieve its token from the OS keyring; in that case `gh auth status` is a false negative. Treat a successful host-context PR lookup as proof that `gh` works. Never extract a keyring token or copy it into the sandbox.

## Prepare the review checkout

1. Read applicable `AGENTS.md`, `CLAUDE.md`, contributor guides, and directory-local instructions.
2. Inspect `git status`, remotes, and the current worktree before changing `HEAD`.
3. Run the bundled preparation script with checkout enabled:

   ```bash
   <skill-dir>/scripts/prepare-review.sh --pr <url-or-number> --checkout
   ```

   For a remote branch without a PR:

   ```bash
   <skill-dir>/scripts/prepare-review.sh --branch <head-branch> --base <base-branch> --checkout
   ```

   Pass `--remote <name>` when the relevant remote is not `origin`. Pass `--base <branch>` to intentionally override a PR's base branch.
4. Stop if the script reports a dirty checkout, a repository mismatch, missing authentication after the allowed-context retry above, or a non-linked main worktree. Preserve the user's checkout and explain the exact remediation.
5. Record `BASE_REF`, `HEAD_REF`, `BASE_OID`, `HEAD_OID`, `MERGE_BASE_OID`, `DIFF_RANGE`, and `COMMIT_RANGE` from the script output. `BASE_REF` and `HEAD_REF` are immutable snapshot refs named by object ID; `DIFF_RANGE` and `COMMIT_RANGE` contain object IDs. Use these exact values throughout the review.

## Build context

For a PR, inspect its intent and status without posting anything when `gh` is available:

```bash
gh pr view <url-or-number> --json number,title,body,url,author,baseRefName,headRefName,isDraft,reviewDecision,statusCheckRollup
```

Read the complete `title` and `body`; do not treat them as display-only metadata. Use them as the PR author's statement of intent and requirements. If `gh` is unavailable, continue from the Git refs prepared from the full PR URL and explicitly state that remote PR metadata and checks were not inspected. Tracker context may still come from the user's request, branch name, or commit messages.

Read complete commit subjects and bodies from the immutable commit range before identifying issues or requirements:

```bash
git log --format='%H%x09%s%n%b' "$COMMIT_RANGE"
```

### Enrich context from Yandex Tracker

For a PR or branch review, look for a Yandex Tracker issue in this priority order, skipping sources that do not exist for the selected mode:

1. A Tracker URL or standalone issue key explicitly supplied by the user.
2. An explicit `https://st.yandex-team.ru/<KEY>` link in the PR body.
3. A standalone issue key in the PR title.
4. A standalone issue key in `headRefName`.
5. A standalone issue key in the commit messages.
6. A standalone issue key elsewhere in the PR body.

Recognize keys such as `DLAPI-1597` case-insensitively, normalize them to uppercase, and deduplicate matches. Treat the first match by the priority above as the primary issue. Select every issue explicitly supplied by the user or linked in the PR. Then follow the shared [Yandex Tracker review-context workflow](../deep-code-review/references/yandex-tracker-context.md).

Before reviewing the diff, synthesize:

- change intent from the user's request and commit messages;
- PR intent from the title and full body when PR metadata is available;
- requirements, constraints, and expected behavior from the Tracker description;
- later decisions or corrections from Tracker comments;
- any conflict among the user, PR, commits, and Tracker context.

Use this combined context as the review specification. Apply the shared workflow's unavailable-context and residual-risk rules without silently omitting an identified issue.

Read the complete diff before judging individual files:

```bash
git diff --stat "$DIFF_RANGE"
git diff --name-status "$DIFF_RANGE"
git diff "$DIFF_RANGE"
```

Inspect surrounding callers, callees, tests, configuration, migrations, schemas, and error paths. Use history only when it clarifies intent or compatibility.

## Review deeply

Invoke the required `$deep-code-review` skill in the current agent and use it as the sole review engine. Do not place the invocation inside a wrapper subagent and do not run duplicate review lanes afterward. Before invoking it, supply this explicit contract from the prepared review:

- The authoritative scope is the immutable object-ID `DIFF_RANGE` resolved from `BASE_REF` and `HEAD_REF`; include `BASE_REF`, `HEAD_REF`, `BASE_OID`, `HEAD_OID`, and `MERGE_BASE_OID`. State that the linked worktree is detached at `HEAD_OID` and that the review must not infer another scope from the checkout, upstream, mutable refs, or PR metadata.
- Include the exact diff commands already used and the commit list from `git log --oneline "$COMMIT_RANGE"`.
- Pass the synthesized PR/Tracker specification, the explicitly selected primary Tracker issue, and the applicable repository-instruction and standards files. State that already-read Tracker content should be reused rather than fetched again. State explicitly when Tracker context or a usable specification was unavailable so the Spec pass can report that limitation without blocking the other passes.
- Keep the review read-only and locate findings against the checked-out `HEAD_OID`.

Let Deep Code Review own its Correctness, Integration, Resilience, Standards, and Spec lanes; candidate verification; P0–P3 severity; confidence threshold; and report structure. Preserve its distinct Standards and Spec reports and its stable finding IDs. Do not merge, rerank, or renumber its output.

Use Deep Code Review's existing final provenance block for the exact PR or branch, primary and linked Tracker issue keys and whether their descriptions/comments were read, base and head SHAs, `DIFF_RANGE`, checks run, and residual risk. Do not append a second provenance block. Keep the block unnumbered, and do not claim that tests passed unless they actually ran successfully.

## Bundled script

Use `scripts/prepare-review.sh` to resolve and fetch exact GitHub refs and safely detach only a clean linked worktree at the review head. The script never creates commits, pushes, or posts reviews.
