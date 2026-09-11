# PHASE1-openclaw-findings-and-next-steps

**2026-09-11.** Written by Claude in a Cowork session, after that session's
shell access to the mini PC broke (see `roadmap`'s history for the mount
issue) and Matt chose to finish Phase 1's live-system work through Claude
Code instead. This document is everything that session found from disk and
from OpenClaw's docs, plus the exact remaining tasks — written so Claude Code
can pick this up without re-deriving the research.

**Read `PLAN-dev-environment-v1.md` first**, specifically its "Findings,
2026-09-11" note under Phase 1. This document is the task list that note
points to.

---

## Already confirmed — don't re-check these

- Container: `docker-compose.yml` pins `openclaw/openclaw:2026.9.3` (current
  release), edited 2026-09-09.
- `openclaw.json` (the live config, at `C:\automation\openclaw\openclaw.json`)
  has not been touched since 2026-07-17 — predates the 2.0 upgrade.
- A pre-upgrade backup already exists:
  `C:\automation\openclaw\backups\openclaw-2026.7.1-20260909.tgz`, written
  2026-09-09. Don't delete it. It's the rollback point if anything in this
  document goes wrong.
- `config-staging.json` is a second, older, unapplied draft (2026-07-16) that
  adds a Discord channel and sets `gateway.bind: "lan"`. **Decision: leave it
  unapplied.** Don't merge its Discord addition — this project keeps Discord
  on the existing caddy/infra-watch projects and puts new automation work on
  Telegram, per the roadmap's own open question 4. Confirm with Matt only if
  you find a reason this default call is wrong.
- Both the live network setup (Docker port-mapped straight onto the Tailscale
  IP) and `config-staging.json`'s `bind: "lan"` predate OpenClaw 2.0's
  documented recommendation for a Tailscale-reached home server
  (`bind: "loopback"` + `gateway.tailscale.mode: "serve"`). **Out of scope
  for this pass on purpose** — it changes the URL Matt uses to reach the
  control UI. Don't fold it into the changes below; raise it as its own
  follow-up once the rest of this is verified working.
- Memory search (`agents.defaults.memorySearch`) is currently disabled.
  Leave it disabled. If it's ever turned on, `memory.search.provider` must be
  set to `"local"` or `"ollama"` in the *same* change — the undocumented
  default is OpenAI cloud embeddings, which is an unbudgeted paid dependency
  Matt hasn't approved.

## Task 1 — find the real exec-approval config

OpenClaw's docs describe approvals as scoped per agent (`agents.<id>` each
carrying their own `security` mode and allowlist), with an example schema
(`version`, `defaults`, `agents` as top-level keys) that **does not match**
`openclaw.json`'s own shape — `openclaw.json` nests exec settings under
`tools.exec` and has no `agents.<id>` map, only `agents.defaults`.

**Do this with actual shell/API access, not another doc fetch:**

1. Inspect the live container's config directory
   (`docker exec openclaw ls -la /home/node/.openclaw`, or the equivalent
   from wherever it's mounted) for a separate approvals file — likely
   something like `exec-approvals.json`, `approvals.json`, or similar, either
   next to `openclaw.json` or auto-created on first approval.
2. If nothing exists yet, check `openclaw --help` / the CLI's own docs for
   how a new agent identity and its allowlist actually get created — it may
   be a CLI command (`openclaw agents create ...` or similar) rather than a
   hand-edited file.
3. Confirm the exact mechanism, then design one new agent identity for
   automations — allowlist empty to start, `ask: "on-miss"` — separate from
   whatever agent identity handles Matt's interactive Telegram/control-UI
   sessions, which keeps `ask: "always"` unchanged.

**Don't hand-author a guessed JSON block for this and apply it** — confirm
the real shape first. This is the one piece of Phase 1 last session
explicitly declined to fabricate.

## Task 2 — secrets migration

Run, in order, against the live container:

```
openclaw secrets audit
openclaw secrets configure
openclaw secrets apply
openclaw secrets audit    # re-run to confirm plaintext is gone
```

Expect `secrets audit` to flag the Telegram bot token currently sitting in
`.env` and/or `openclaw.json`. `configure` sets up a `SecretRef` provider —
`env`, `file`, `exec` (1Password/Bitwarden/Vault/pass/sops), or `store` are
the four options; for a single-machine setup, `env` or `file` is the
low-effort choice unless Matt already has 1Password or similar wired in.
Report back what `audit` actually found before running `apply`.

## Task 3 — apply the reviewed config

Once Tasks 1 and 2 are settled:

1. Copy the live `openclaw.json` to
   `openclaw.json.pre-phase1-2026-09-11.bak` before changing anything (in
   addition to the existing `.last-good` and the tarball — this one's
   specifically tied to this change so it's unambiguous what to roll back
   to).
2. Apply the new automation-agent block from Task 1.
3. Leave everything else in the live config as-is unless Task 1 or 2 required
   a change to reach it (e.g., a `SecretRef` replacing a plaintext value).
4. Restart the container (`docker compose up -d` from
   `C:\automation\openclaw`) and confirm it comes up clean —
   `docker compose logs -f openclaw` for a minute, and a real Telegram
   message round-trip to confirm the interactive agent still asks for
   approval exactly as before.
5. Update `C:\automation\dev-environment\STATE.md`'s Phase 1 row and commit.

## What Phase 1 does *not* include

Don't touch: the model list (`qwen3.5:9b-q8_0` / `gemma4`), the
`byProvider` tool denials, the skills/plugins enabled-list, or the network
binding. None of those were flagged as wrong — only the approval gate, the
plaintext secrets, and the two stale/conflicting drafts were.

## When this is done

Phase 2 (the proving-ground job) is the next planned step in
`PLAN-dev-environment-v1.md` §8, and it's the first thing that will actually
exercise the new automation agent's allowlist — expect to add exactly one
pattern to it for that job's one command.
