# Matt Pocock code-review integration

Read the bundled [upstream code-review instructions](upstream.md) in full for these materials:

- the separate Standards and Spec review axes;
- the complete Fowler smell baseline;
- the Standards and Spec reviewer briefs;
- the reason the two reports remain distinct.

Use the upstream file as reference material for those items only. The parent `deep-code-review` skill owns scope selection and freezing, Tracker access, subagent scheduling, missing-spec behavior, candidate verification, stable finding IDs, and final reporting. Do not follow conflicting upstream process steps in those areas, and do not request `setup-matt-pocock-skills`.

For a non-trivial review, Standards and Spec form the two parallel runs in Batch 2 after the three original lanes finish. Run Spec even when no usable specification exists; in that case it returns `Spec unavailable` with the reason. Neither run may edit files or delegate to another agent.
