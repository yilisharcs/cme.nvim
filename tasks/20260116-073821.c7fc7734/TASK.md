---
status: CLOSED
priority: 10
tags: [bug]
---

# git rebase concatenates strings previously separated by a literal ^M

UPDATE: I suspect `git rebase` emits a `[K` sequence, but because the plugin doesn't use an interactive terminal, it's stripped from the output. I guess I must suffer `Rebasing (3/4)Rebasing (4/4)Successfully rebased and updated refs/heads/dev.`...
