# STATE.md — dev-environment

The canonical status file for this project. `PLAN-dev-environment-v1.md` is
the plan; this file is what's true right now.

_Status: **Active**. Graduated from Planned 2026-09-10._

## Where things are

| | |
|---|---|
| Folder | `C:\automation\dev-environment` |
| Repo | `github.com/elasticbrainMB/dev-environment`, `main` |
| claude.ai project | **"Dev Environment"** — resolves open question 5. Holds the cross-session handoff doc; this file and the plan stay the on-disk source of truth |
| Roadmap pointer | `C:\automation\roadmap\projects\dev-environment.md` |
| Plan | `PLAN-dev-environment-v1.md`, this folder |
| History | Moved, 2026-09-11 — `history\dev-environment-planning-v0.5.md`, this folder |

## What this is

A shared foundation for running work across projects, with **OpenClaw 2.0 as
the place work is started, watched, approved and reported** — so agentic work
can run overnight and during the workday without Matt sitting at the keyboard.

Three runners, one routing rule: OpenClaw for anything where a model makes a
judgment, n8n for scheduled work that talks to outside services, Windows Task
Scheduler for the deterministic jobs already built. Nothing already working
gets migrated.

## Phase status

| Phase | State |
|---|---|
| **0 — Graduate the project** | **Done, 2026-09-11.** Repo live at `github.com/elasticbrainMB/dev-environment`, `main` branch, 3 commits. `roadmap\planning\dev-environment.md` moved here as `history\dev-environment-planning-v0.5.md`; removed from roadmap in the same pass as roadmap's own pending pointer-update commit, so history never shows the old doc and a stale pointer coexisting |
| **1 — OpenClaw 2.0 config reset** | **Done, 2026-09-11.** Host `openclaw.json` confirmed disconnected from the live container config (named Docker volume, not a bind mount) — all live changes go through the CLI. `automation` agent identity live and correct. `OLLAMA_API_KEY` confirmed as a real `SecretRef` object, not the raw key — verified directly, not just claimed. A `git push`-scoped permission rule now lives in this project's local Claude Code settings, so future pushes here don't need a manual unblock |
| **2 — The proving ground** | **Proven end to end, 2026-09-11 — 5 of 6 proof points closed.** Built and run for real in `proving-ground\`. Passing run and deliberate-failure run both observed with real evidence (Discord, disk, cost). Biggest finding: the exec-approval gate only covers `exec`/`process`/`apply_patch` — a job that only reads and writes files never touches it, so most future jobs need none of §6's allowlist work. Stop rule proven exactly as designed: 2 local fails → 3 paid-escalation fails (`openrouter/~anthropic/claude-sonnet-latest`, real spend $0.927612) → hard stop at attempt 5 → report to disk → Discord ping → confirmed no restart on a sixth, hand-run tick. Model exposure narrowed from OpenRouter's 438-model catalog to an explicit 3-model allowlist via `agents.defaults.modelPolicy.allow`, verified as real enforcement (a disallowed model was rejected, not just hidden). **Left open, Matt's own call, not a failure:** the Windows Scheduled Task itself was not created — same standing-action classifier as `git push` in Phase 1 — so the one still-unproven property is a real timer firing the job with nobody watching. **Carried to Phase 3, not optional:** no weekly spend cap is wired in anywhere for the OpenRouter escalation path yet; must exist before any real recurring job uses it. See `PLAN-dev-environment-v1.md`'s "Phase 2 close-out" section for the full findings, including a third credential-storage mechanism (`models auth`, distinct from both `.env` and `SecretRef`) |
| **3 — First real project** | Deferred by decision, chosen on Phase 2 evidence. Leaning: newsletter health reporting, scoped so the boring checkable collection half ships first. Two gates not yet checked: whether Matt's beehiiv plan includes API access, and the spend cap above |

## Decisions on the record

| Date | Decision |
|---|---|
| 2026-09-04 | First increment proves the pattern on a second project; target shape is the queued middle ground, not full autonomy |
| 2026-09-10 | Front door: OpenClaw runs, Claude plans |
| 2026-09-10 | First build is a deliberately trivial proving-ground job; the real project is chosen after it, on evidence |
| 2026-09-10 | Runner split by whether a model is involved, with n8n named as a third runner |
| 2026-09-10 | Model policy: local first, escalate to paid after two consecutive no-progress attempts |
| 2026-09-10 | **Stop rule settled at five** consecutive no-progress attempts, and a stopped job does not restart on its next scheduled tick |
| 2026-09-11 | **Front door channel: Discord**, not Telegram — it was already live and wired to approvals when Claude Code checked. Telegram stays configured but off. Resolves the plan's open question 4 |
| 2026-09-11 | **Secrets migration scope: only what the audit flagged** (`OLLAMA_API_KEY`). The other three plaintext secrets in `.env` stay as-is |
| 2026-09-11 | **Claude Code may push to git in this project without asking each time**, once a permission rule scoped to `git push` (not broader) is in place. Deliberate call, not a default — Claude Code's harness blocks pushes by default for the same reason the OpenClaw approval gate exists: a push is visible and hard to undo. Revisit if this project ever needs a *narrower* rule than "any push in this folder" (e.g. once Phase 2 automations exist, whether they should push too, or only Matt/interactive Claude Code sessions) |
| 2026-09-11 | **Exec-approval scoping (§6) is deprioritized for most future jobs** — proven in Phase 2 to only apply to jobs that shell out. Still needed for the minority that do |
| 2026-09-11 | **Escalation model set to exactly 3 allowed models** (`agents.defaults.modelPolicy.allow`) — the two existing local Ollama models plus `openrouter/~anthropic/claude-sonnet-latest` — instead of OpenRouter's full 438-model catalog |
| 2026-09-11 | **A weekly spend cap on the OpenRouter escalation path is required before Phase 3**, not optional. Nothing enforces one yet |

## Open, blocking nothing yet

Full list in `PLAN-dev-environment-v1.md` §10 (5 items) and the Phase 2
close-out section. What will bite first, in rough order:

- **A weekly spend cap for the OpenRouter escalation path.** Must exist
  before Phase 3's job goes live — the one carried, non-optional item from
  Phase 2.
- **The Windows Scheduled Task itself.** Matt declined to create it during
  Phase 2 (same standing-action classifier as `git push`); it's the one
  proof point Phase 2 didn't close. Worth closing before treating any real
  job as unattended-ready.
- Whether Matt's beehiiv plan includes API access. Gates the leading Phase 3
  candidate.
- Whether to tear down `proving-ground\` or leave it as a working reference
  — no cost either way, genuinely undecided.
- The two work-window times (overnight heavy-local vs. daytime light) —
  proposed in the plan §10.3, not confirmed with Matt.

## Execution route

**2026-09-11** — the Cowork device bridge's shell (`device_bash`) cannot
mount this session's connected folders (confirmed persistent across an app
restart and a fresh session; likely a product bug, not fixed from this end).
Matt's call: manage shell-dependent work through Claude Code on the mini PC
instead. Claude in Cowork keeps doing file-level work (read/write/research)
through the tools that still work, and hands off anything needing a live
shell or a running container's state as a written task list.

**Standing practice since:** the file-write bridge has its own bug — writing
two different files to the same local staged filename in successive calls
can silently serve the first file's stale bytes on the second write, while
still reporting success. Every write to this device is now followed by an
independent re-read (fresh staged filename, byte-size or content check)
before treating it as done. And per Matt's explicit, repeated feedback: keep
back-and-forth through him to a minimum — resolve routine calls without
asking, batch anything that must go through him, and reserve real questions
for hard blocks (a harness-level policy, a decision only he can make).

## Corrections

**2026-09-10 — the planning document named a project that had been dropped.**
`planning\dev-environment.md` §2 and §6 (v0.5, 2026-09-10) name model-version
review as the second project to prove the runner on. The roadmap's `STATE.md`
records it dropped on 2026-09-05. Recorded rather than quietly fixed: it is
the third sync-discipline slip in seven days, and it is why the plan's §9
now treats a mechanism as needed rather than optional.
