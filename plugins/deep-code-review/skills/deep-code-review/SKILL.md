---
name: deep-code-review
description: Perform a deep, high-confidence review of local code changes using independent analysis lanes, explicit verification, Matt Pocock's standards and specification checks, and available Yandex Tracker context. Use for uncommitted changes, the current checkout, selected files, or an explicit commit or diff range. When the request identifies a GitHub PR URL, PR number, or remote branch, use `$github-pr-worktree-review` instead; this skill remains its required review engine after preparation. Do not use for a quick diff summary or when the user only asks to implement code without requesting review.
---

# Deep Code Review

Review the requested change set without modifying code. Prefer a few verified findings over a long speculative list.

## Check dependencies

Before reading repository state, run the bundled preflight from this skill's installed directory:

```bash
<skill-dir>/../../scripts/doctor.sh --workflow deep-code-review
```

Stop on any `ERROR` and return the script's remediation. Do not install system programs or external plugins automatically. A `WARNING` about `gh` does not block a local review; report it only when GitHub metadata would otherwise be part of the selected scope.

## Establish the scope

1. Read applicable `AGENTS.md`, `CLAUDE.md`, contributor guides, and directory-local instructions before judging the changes.
2. Use the scope named by the user. If none is named, infer it in this order:
   - uncommitted work when the working tree has changes;
   - the current pull request when `gh pr view` succeeds;
   - the current branch against the merge base with its PR base, the repository's default branch, or another well-supported base branch;
   - otherwise ask for a commit, branch, pull request, or file set.
3. Never use a feature branch's own tracking ref as its base merely because it is the configured upstream. Resolve ref-based endpoints to commit OIDs before review, compute the merge base once, and use the resulting immutable OID range and object contents for every lane. If the selected comparison is empty, report that there are no changes in scope and stop before launching review lanes.
4. For an uncommitted review, freeze the input before launching lanes: record the `HEAD` OID; capture complete staged and unstaged binary diffs; copy relevant untracked-file contents into a temporary read-only snapshot outside the repository; and create a hash manifest for all captured inputs. Include staged, unstaged, and relevant untracked files without silently omitting a category. Give every lane the same snapshot as its authoritative change set and use the live checkout only for surrounding context.
5. Before the final report, verify that the frozen OID range remains readable or recalculate the uncommitted-input fingerprint. If the live checkout changed, do not mix the newer content into the frozen review. Either restart against a fresh snapshot when the user asked for the latest state, or report the reviewed snapshot and the drift as residual risk.
6. Record the exact immutable comparison or snapshot fingerprint in the final response.

Use `rg` for repository search and non-mutating Git or `gh` commands for context. Do not post a review, push, edit files, stage changes, or create commits unless the user explicitly requests that separate action.

## Build context

Read the complete diff, then inspect enough surrounding code to understand callers, state transitions, data contracts, and error paths. Examine related tests and configuration. Use `git blame`, `git log`, or earlier changes only when history can clarify intent or compatibility.

Identify the intended behavior from the request, issue, PR description, tests, and project rules. Treat the diff as evidence, not as a complete specification.

## Enrich context from Yandex Tracker

When the user, PR metadata, branch name, or commit messages identify a Yandex Tracker issue by URL or key, prefer an issue explicitly supplied by the user, then an explicit PR link, PR title, branch name, and commit messages. Normalize keys to uppercase, deduplicate them, select every explicitly linked issue, and expand incidental references only when they materially define the change. Then follow the shared [Yandex Tracker review-context workflow](references/yandex-tracker-context.md).

## Include Matt Pocock's code-review

For every deep review, read the bundled [Matt Pocock code-review integration](references/mattpocock-code-review/reference.md) and apply its Standards and Spec passes in addition to the original lanes below. Its linked upstream file contains the full Fowler smell baseline and both reviewer briefs. Use these integration rules:

- Reuse the frozen scope established above. Give both passes the same resolved OIDs or uncommitted snapshot, diff commands, commit list, standards, specification, and relevant file contents.
- The combined workflow does not require `setup-matt-pocock-skills`. If no specification can be found or accessed, the Spec lane reports `Spec unavailable` with the reason rather than inventing requirements.
- Include the complete smell baseline in the Standards prompt and the applicable specification contents in the Spec prompt. The primary agent coordinates all lanes; no lane may create another agent or review orchestrator.
- Verify concrete claims from both passes against their cited rule, requirement, and changed code. Keep documented-standard violations distinct from labelled smell heuristics. Apply the confidence and severity rules below to any functional defect; a smell alone is not a functional defect.

## Classify the review and schedule lanes

Treat a change as non-trivial when it can affect runtime behavior, interfaces or data contracts, configuration or deployment, permissions or security, concurrency or resource lifetime, error handling, or requirements from a specification. A short or single-file change can still be non-trivial. Treat only clearly behavior-preserving edits such as spelling, formatting, or comment-only changes as trivial. When uncertain, classify the change as non-trivial.

When delegation tools are available, every non-trivial review must launch exactly five bounded subagent runs in two ordered batches:

**Batch 1 — three original lanes in parallel:**

1. Correctness.
2. Integration.
3. Resilience.

Wait for all three Batch 1 runs to finish, then launch:

**Batch 2 — two Matt Pocock lanes in parallel:**

4. Standards from the bundled Matt Pocock instructions.
5. Spec from the bundled Matt Pocock instructions.

The primary coordinating agent is not one of these five. Give every lane its own subagent and fresh context; do not reuse a Batch 1 agent for Batch 2. Never run more than three subagents concurrently. Temporarily occupied slots do not make delegation unavailable: wait for three slots before Batch 1 and for two slots before Batch 2. A missing specification does not reduce the count; the Spec run must still return `Spec unavailable` with the reason. Every lane prompt must prohibit edits and further delegation and must include the exact frozen scope and applicable instructions.

If one of the five launched runs fails, times out, requests unavailable input, or returns malformed output, do not launch a replacement that would increase the count. Complete that lane directly in the primary agent and record the failed run in residual risk. Only a trivial change or an environment with no subagent mechanism permits performing all applicable lanes directly from the start.

## Review-lane briefs

Require each lane to return only candidate findings with file, line, triggering scenario, impact, and evidence. A `no findings` result is valid. The Spec lane may instead return only `Spec unavailable` with its reason when no usable specification exists.

- Correctness lane: logic, state, concurrency, resource lifetime, security boundaries, performance cliffs, and data loss.
- Integration lane: callers and callees, API or schema compatibility, configuration, migration behavior, platform differences, and relevant Git history.
- Resilience lane: tests, edge cases, error handling, observability, type invariants, comments, and documentation that affects correct use.
- Standards lane: documented repository rules plus the complete bundled smell baseline, using the bundled Standards brief.
- Spec lane: missing, partial, extra, or incorrectly implemented requirements, using the bundled Spec brief.

Review the frozen change independently in the primary agent while the lanes run.

## Verify candidate findings

Merge duplicate functional findings from all lanes, then validate each against the repository:

1. Confirm the problem is introduced or exposed by the reviewed change and points to a changed line or the smallest directly affected location.
2. Trace a concrete execution path or input that triggers it.
3. Check nearby guards, callers, tests, framework behavior, generated-code boundaries, and project rules that could invalidate it.
4. Run a focused test, static check, or minimal reproduction when it materially increases confidence and can be done safely.
5. Assign a confidence score from 0 to 100. Report only findings at 80 or above.

Exclude speculative concerns, pre-existing defects, intentional behavior supported by evidence, formatting and lint-only issues, broad refactoring advice, and test requests that do not protect a plausible regression from the functional findings. Evidence-backed standards observations and labelled smell heuristics belong in the companion's separate Standards report.

## Rank severity

- P0: release-blocking or broadly catastrophic with no reasonable workaround.
- P1: high-impact defect likely to affect normal use, security, integrity, or availability.
- P2: real functional defect under a plausible but narrower condition.
- P3: low-impact functional issue worth fixing; never use P3 for style or preference.

## Report

List findings first, ordered by severity and then confidence in the initial report.

Give every distinct finding or actionable Standards/Spec observation a visible numeric ID. Use one continuous sequence starting at 1 across the whole report, including the separate Standards and Spec sections. Put the literal ID in the title, for example `**#1 [P1] Fix the missing null guard**` or `**#4 [Standards] Possible duplicated logic**`. The number identifies the item; P0–P3 still indicate severity. Carry the same ID into inline review-comment titles, preserving any priority format required by the host. A repeated reference to an existing finding uses its original ID. Leave scope, checks, and "no findings" or "unavailable" status messages unnumbered.

Keep these IDs stable throughout follow-up discussion and fixes for this review. Interpret requests such as "fix 1, 3, and 6; change 2 this way" against those IDs. Preserve IDs when showing a subset, changing priority, or marking items resolved; never renumber or reuse them. Give new findings the next number after the highest ID already assigned. Use explicit labels rather than relying on Markdown's automatic list numbering, which can renumber a subset. A new, unrelated review starts a new sequence.

For each functional finding include:

- a concise imperative title with priority;
- the narrowest useful file and line location;
- the triggering scenario and user-visible or operational impact;
- the evidence that makes it a defect;
- a minimal fix direction;
- the confidence score.

Keep a finding self-contained and avoid long code excerpts. Use inline code-review comments when the host supports them.

If no functional issue meets the threshold, say that no high-confidence functional defects were found.

After the functional findings, include the companion's separate Standards and Spec reports. Preserve each axis and its finding count; do not rerank one axis against the other. Cite the documented rule or spec requirement for concrete violations, and clearly label smell observations as judgement calls without assigning a bug priority. If an item is already a verified functional finding, reference that finding from its axis instead of repeating the full text. State when an axis has no findings or could not be checked; missing specifications must never be reported as a pass.

Finish with the reviewed scope; any Tracker issue keys and whether their descriptions and comments were read; checks actually run; and residual risk caused by unavailable tests, missing context, or an intentionally limited scope.
