# Yandex Tracker review context

Use this workflow after an entrypoint has identified one or more relevant Yandex Tracker issue keys.

1. Reuse trustworthy issue content already read in the current task instead of fetching it again.
2. When `datalens-team-skills:startrek` is available, invoke it and follow its read-only `get` workflow. Read the description and comments for every issue explicitly supplied by the user or explicitly linked from the change context, starting with the selected primary issue. Later comments may refine or override the original description.
3. Synthesize requirements, constraints, expected behavior, and later decisions into the review specification. Record conflicts with the user's request, PR description, branch intent, or other selected issues.
4. Expand incidental issue references only when they materially define requirements or blockers.
5. If Tracker access, authentication, or the Startrek skill is unavailable, continue with the available context and record exactly which issue context was not read as residual risk. Never report an unread issue as successfully checked.

Keep every Tracker operation read-only. Do not edit issues or add comments during a code review.
