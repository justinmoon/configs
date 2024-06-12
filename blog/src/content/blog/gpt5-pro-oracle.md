---
title: "Using GPT-5 Pro as an Oracle for Code Agents"
description: "Automating ChatGPT's web UI to give coding agents access to GPT-5 Pro when they get stuck"
date: 2025-11-06
---

[AMP](https://ampcode.com/)'s coder/oracle pattern is solid—let an agentic model do the editing while consulting an oracle when it gets stuck. I copied this for my own setup but noticed GPT-5 Pro solving problems through the web console that Codex High couldn't handle, so I needed a way to wire up GPT-5 Pro even though it's not available via API.

I built [gpt5-pro](https://github.com/justinmoon/gpt5-pro) CLI to enable coding agents to call by spawning [chatgpt.com](https://chatgpt.com/) in [Playwright](https://playwright.dev/). You log in once to capture your session, then query GPT-5 Pro headlessly. It works well with [repomix](https://github.com/yamadashy/repomix) to bundle relevant codebase context before sending questions to GPT-5 Pro.

```bash
gpt5-pro login
repomix --output context.txt src/
gpt5-pro "$(cat context.txt)\n\nFind the bug in LoginForm.tsx"
```

