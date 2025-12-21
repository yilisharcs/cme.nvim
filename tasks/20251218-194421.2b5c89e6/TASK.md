---
status: OPEN
priority: 50
tags: [bug, termcodes]
---

# Add extra ansi filters

cme.nvim doesn't have filters for these

```bash
msg_ok() {
  printf '\e[32m✔\e[0m %s\n' "$@"
}

msg_err() {
  printf '\e[31m✘\e[0m %s\n' "$@" >&2
}
```
