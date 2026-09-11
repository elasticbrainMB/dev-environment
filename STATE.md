# STATE.md — dev-environment

The canonical status file for this project. `PLAN-dev-environment-v1.md` is
the plan; this file is what's true right now.

_Status: **Active**. Graduated from Planned 2026-09-10._

## Where things are

| | |
|---|---|
| Folder | `C:\automation\dev-environment` |
| Repo | `github.com/elasticbrainMB/dev-environment`, `main` |
| claude.ai project | Not created — open question 5 in the plan |
| Roadmap pointer | `C:\automation\roadmap\projects\dev-environment.md` |
| Plan | `PLAN-dev-environment-v1.md`, this folder |
| History | `history\dev-environment-planning-v0.5.md`, this repo — moved from the roadmap repo 2026-09-11; removed there in the same piece of work |

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
| **0 — Graduate the project** | **Done, 2026-09-11.** Repo created and pushed: `github.com/elasticbrainMB/dev-environment`, `main`. Push needed a `git push`-scoped permission rule (harness-level, separate from Matt's go-ahead) — added to `.claude/settings.local.json`, scoped to this project, force-push variants still denied. The superseded v0.5 planning doc is moved: `history\dev-environment-planning-v0.5.md` in this repo, removed from `roadmap\planning\dev-environment.md` in the same piece of work (roadmap's `STATE.md` and project pointer already graduated it to Active, committed together with the removal). claude.ai project still open — question 5 in the plan |
| **1 — OpenClaw 2.0 config reset** | **Done.** Host `openclaw.json` confirmed disconnected from the live container config (named Docker volume, not a bind mount) — all live changes go through the CLI. `automation` agent identity live and correct. `OLLAMA_API_KEY` confirmed as a real `SecretRef` object (`{source: "env", provider: "env", id: ...}`), not the raw key — verified directly, not just claimed |
| **2 — The proving ground** | Not started. A throwaway recurring job, run to a pass and then broken on purpose to fire the stop rule |
| **3 — First real project** | Deferred by decision, chosen on Phase 2 evidence. Leaning: newsletter health reporting |

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

## Open, blocking nothing yet

The five open questions live in `PLAN-dev-environment-v1.md` §10. The two
that will bite first:

- Whether OpenClaw enforces per-job budgets and retries, or the job's own
  check script has to. Phase 1 answers it.
- Whether Matt's beehiiv plan includes API access. Gates the leading Phase 3
  candidate.

## Execution route

**2026-09-11** — the Cowork device bridge's shell (`device_bash`) cannot
mount this session's connected folders (confirmed persistent across an app
restart and a fresh session; likely a product bug, not fixed from this end).
Matt's call: manage shell-dependent work through Claude Code on the mini PC
instead. Claude in Cowork keeps doing file-level work (read/write/research)
through the tools that still work, and hands off anything needing a live
shell or a running container's state as a written task list.

## Corrections

**2026-09-10 — the planning document named a project that had been dropped.**
`planning\dev-environment.md` §2 and §6 (v0.5, 2026-09-10) name model-version
review as the second project to prove the runner on. The roadmap's `STATE.md`
records it dropped on 2026-09-05. Recorded rather than quietly fixed: it is
the third sync-discipline slip in seven days, and it is why the plan's §9
now treats a mechanism as needed rather than optional.
