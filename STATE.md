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
| **2 — The proving ground** | **Proven end to end, 2026-09-11 — 5 of 6 proof points closed.** Built and run for real in `proving-ground\`. Passing run and deliberate-failure run both observed with real evidence (Discord, disk, cost). Biggest finding: the exec-approval gate only covers `exec`/`process`/`apply_patch` — a job that only reads and writes files never touches it, so most future jobs need none of §6's allowlist work. Stop rule proven exactly as designed: 2 local fails → 3 paid-escalation fails (`openrouter/~anthropic/claude-sonnet-latest`, real spend $0.927612) → hard stop at attempt 5 → report to disk → Discord ping → confirmed no restart on a sixth, hand-run tick. Model exposure narrowed from OpenRouter's 438-model catalog to an explicit 3-model allowlist via `agents.defaults.modelPolicy.allow`, verified as real enforcement (a disallowed model was rejected, not just hidden). **Left open, Matt's own call, not a failure:** the Windows Scheduled Task itself was not created — same standing-action classifier as `git push` in Phase 1 — so the one still-unproven property is a real timer firing the job with nobody watching. **Weekly spend cap: built and verified 2026-09-11**, closing the item this row used to carry to Phase 3 as a blocker. See the decisions table below. See `PLAN-dev-environment-v1.md`'s "Phase 2 close-out" section for the full findings, including a third credential-storage mechanism (`models auth`, distinct from both `.env` and `SecretRef`) |
| **3 — First real project** | **Chosen 2026-09-11: job search triage.** OpenClaw takes over fit scoring on rows the existing job-search pipeline already collects; n8n/the existing task keeps collecting, the Google Apps Script webhook stays the only write path to the Job Tracker, and the 06:00 resume autopilot is untouched. Displaced newsletter health reporting because Matt has stated he wants the job search moved off Claude, where the newsletter idea was a prior thread's inference. Explicitly excludes the LinkedIn browser steps. Scoped in `PHASE3-job-search-triage.md`; gated on Phase 2's close-out and four machine-checkable unknowns |

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
| 2026-09-11 | **The weekly spend cap is $5, enforced by OpenRouter on a dedicated API key** (`limit: 5`, `limit_reset: weekly`), not by a budget check inside the job. Rejected requests never reach a model, so they cost nothing, and the ceiling holds even when our own code is wrong — including for jobs not yet written. Sized against Phase 2's worst case of $0.927612 for one job failing to a hard stop. Answers plan open question 1 with a third option neither branch anticipated: the provider enforces it |
| 2026-09-11 | **The timer proof gets closed now on the proving ground**, not folded into Phase 3 — find scheduling problems on a throwaway job rather than while debugging real logic |
| 2026-09-11 | **Phase 3 is job search triage**, not newsletter health reporting. Stated want beats inferred one. Newsletter reporting stays a live Phase 4 candidate |
| 2026-09-11 | **Work windows confirmed: overnight 23:00–05:00 CT and daytime 09:00–16:00 CT.** Overnight ends at 05:00, not the proposed 06:00 — Matt is usually online around 05:15, so overnight work must *finish* inside the window, not merely start in it. Resolves plan open question 3 |
| 2026-09-11 | **Weekly spend cap built and verified.** `scripts\setup-openrouter-cap.ps1` and `scripts\verify-openrouter-cap.ps1` now exist. The `openclaw-automation` capped key (`limit: 5`, `limit_reset: weekly`) is live in OpenClaw's credential store; the Management API key that created it is deleted. Verified against the live system, not just configured: one real paid escalation attempt cost `$0.31594`, and `limit_remaining` on the capped key dropped from `5` to `4.68406` to match — proof spend is counted against this key, not some other one |
| 2026-09-11 | **No credential value ever enters a model's context** — not a Cowork or Claude Code prompt, not a file a model reads back, not a command whose output a model sees. Matt's instruction, now a standing guardrail (plan §5). The division: Matt runs anything holding a secret, in his own window, behind a secure prompt; Claude Code writes the scripts, which contain none. Covers the Phase 3 webhook URL too — it is a write credential for the Job Tracker, not just an address |

## Open, blocking nothing yet

Two of the five items that stood here on 2026-09-11 are now decided (the
spend cap's size and mechanism, and the work windows) and one is scoped
(Phase 3's project). What remains:

- **The timer proof.** Decided, not yet built — Task B of
  `PHASE2-CLOSEOUT-timer-and-spendcap.md`. The spend cap (Task A) is done: see
  the decisions table above.
- **The silent-non-start gap.** Found 2026-09-11 by reading `run-job.ps1`
  rather than its description. `$ErrorActionPreference = 'Stop'` at the top
  means that if `docker exec` is unreachable — exactly the Task Scheduler
  failure mode being tested for — the script dies before any Discord post and
  before any state write. Nothing posts, nothing lands on disk, and silence is
  indistinguishable from success. Phase 2 could not have caught this: a human
  watched every run. For unattended work this is a larger hole than anything
  Phase 2 closed, and a dead-man's check is part of the timer task, not a
  follow-up to it.
- **Where job orchestration lives.** The proving ground put it in a Windows
  host PowerShell script reaching in via `docker exec`. That works and matches
  the caddy-shaped `verify-*.ps1` convention, but it forces a host-side
  trigger — which rules out both n8n and OpenClaw's own scheduler, and sits
  awkwardly against this project's stated aim that OpenClaw is where work is
  started, watched and reported. Phase 2's close-out gathers the evidence;
  Phase 3 makes the call.
- **`proving-ground\`'s fate — now decided by sequence rather than debate.**
  It stays until the timer proof passes, because it is what the proof runs on.
  After that: scheduled task and dated outputs removed, folder kept in git as
  a worked reference for Phase 3.
- Whether Matt's beehiiv plan includes API access. No longer gates anything
  immediate — it follows newsletter reporting to Phase 4. Still not answerable
  from public docs; it is a look in his beehiiv account settings.

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
