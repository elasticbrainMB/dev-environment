# PHASE1-round3-instructions

**2026-09-11.** Matt's answers to the two questions raised by Claude Code's
first pass. Read this after `PHASE1-findings-and-next-steps.md` and the
"Round 2" section of `PLAN-dev-environment-v1.md` — this is the continuation,
not a replacement.

## Decision 1 — front door channel: Discord

**No OpenClaw config change needed.** Discord was already live and already
wired to exec approvals; Matt chose to keep it rather than restore Telegram.
Nothing to apply. The only follow-up: if anything downstream was written
assuming Telegram (notification text, a README, a setup note), fix the
words, not the system — the system's already right.

## Decision 2 — secrets: migrate only `OLLAMA_API_KEY`

Proceed with the interactive step from `PHASE1-findings-and-next-steps.md`
Task 2, confirmed to only cover the one flagged secret:

```bash
docker exec -it openclaw openclaw secrets configure --yes
```

- Provider: `env`
- Accept the `OLLAMA_API_KEY` mapping.
- **Decline any mapping it offers for `TELEGRAM_BOT_TOKEN`,
  `DISCORD_BOT_TOKEN`, or the gateway password.** Confirmed decision — leave
  those three as plaintext env vars. They're boot-time infrastructure
  credentials, never exposed to a tool call, which is what `SecretRef`s
  exist to protect against.

Once that's run, from wherever has shell access:

```bash
openclaw secrets apply
openclaw secrets audit    # confirm OLLAMA_API_KEY is no longer flagged, and nothing else newly is
```

Report the re-audit result before moving on.

## Then — the actual next open item

Everything else in `PHASE1-findings-and-next-steps.md` Task 3 assumed
editing `openclaw.json` and restarting the container was how a change takes
effect. Round 2's findings put that in doubt: exec approvals and channel
state both appear to be managed live through the CLI / an internal store,
not through that file. **Before making any further config change**, confirm
one way or the other — check `openclaw config --help`, `openclaw config
show`, or equivalent, for how (or whether) `openclaw.json` relates to live
state now. If it turns out to be a bootstrap/import artifact only, say so
plainly and treat the file as historical from here — don't hand-edit it and
restart expecting an effect that may not happen.

Once that's settled, Phase 1's actual remaining work is small: the
`automation` agent identity already exists correctly (empty allowlist, `ask:
on-miss`, no channel bindings). It has nothing to run yet. That's fine —
Phase 2 (`PLAN-dev-environment-v1.md` §8) is the throwaway proving-ground job
that will give it its first allowlist entry. Phase 1 can close once the
secrets step above is confirmed and the config-mechanism question is
answered — it doesn't need anything more built.
