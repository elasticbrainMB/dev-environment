# dev-environment — planning document

**v0.5, 2026-09-10.** Added a §9 carried item: OpenClaw Environment
(`C:\automation\openclaw`) is a component of this project's shared-foundation
scope, not the whole of it, and isn't connected to the roadmap yet — no
pointer file, no `STATE.md` row. Matt's call, 2026-09-10: revisit once
dev-environment gets active attention and OpenClaw has ramped up further;
not before. Everything else in v0.4 is unchanged; its own supersede note
follows unedited.

**v0.4, 2026-09-04, same day as v0.3.** Two of §9 and §10's open items are
now addressed in their own documents, noted in place below rather than
restated here — the collector-vs-own-project question they both touch is
still open either way, not settled by either edit. Everything else in v0.3
is unchanged; its own supersede note follows unedited.

**v0.3, 2026-09-04.** Supersedes v0.2 of the same day. **v0.2's §6 was
wrong about a fact** — it treated cycling-day rating as an unbuilt backlog
item and argued against choosing it. It has been live and running daily since
at least 2026-08-19; `BACKLOG.md` was stale and v0.2 trusted it. Corrected
below, and the correction is recorded rather than quietly fixed because it is
the second sync-discipline slip found on the same day.

v0.2 supersedes the v0.1 draft, which was
written before the four decisions in §2. v0.1's inventory of what exists
(§3, §4) is carried forward unchanged; what changed is that the first
increment is now chosen and the target shape is settled.

Written from a read of `C:\automation\caddy`, `C:\automation\roadmap` and
`C:\automation\project-status` on 2026-09-04. Everything asserted about disk
was read from disk.

**Lifecycle: Planned.** Matt's call, 2026-09-04. Pointer file at
`projects\dev-environment.md` with an empty `disk_location` — no folder yet.
**No `BACKLOG.md` entry**, per this repo's own rule that nothing appears in
both at once.

The prior document is `C:\automation\caddy\caddy-autonomy-plan.md` (v2,
2026-08-21). It remains correct about the caddy and is partly overtaken by
events — see §3.

---

## 1. What this project is

**A shared foundation for running work across projects, rather than
rebuilding one per project.**

Three project folders now exist where one did two weeks ago. They already
share conventions — a `STATE.md` per project, secrets under
`C:\automation\secrets\`, the severity bar, a git remote per repo. Some of
that is deliberate and written down in `PRINCIPLES.md`. Some is copy-paste
that nothing keeps equal.

This project decides which of those the shared layer should be, and closes
the one thing the caddy plan aimed at and did not reach: **work that runs
while Matt is asleep or at his job.**

## 2. Decided — Matt, 2026-09-04

| | Decision |
|---|---|
| **First increment** | **Prove the pattern on a second project.** Not
housekeeping, not full autonomy |
| **Target shape** | **The queued middle ground.** Matt drops a task file in a folder; a scheduled run picks it up under existing caps and stop rules and posts the result or the blocker. Not full overnight autonomy |
| **Which project** | **Model-version review (Qwen / GLM) is the leading candidate**, Matt 2026-09-04 — *"I'd consider the model-version review."* Not yet Planned; it becomes Planned when it has its own `planning\` document |
| **Filing** | **Planned**, with a pointer file. No backlog entry |

**The first two combine, and that is the plan.** The second project should be
built *as a queued package* rather than as another standalone folder — so one
piece of work tests both whether the pattern generalises and whether the
queued runner holds. Building them separately would test each thing once and
cost twice.

## 3. What happened, 21 August to 4 September

**The caddy plan worked, and the result was measured rather than asserted.**

Phase E made "things sent to Matt" its own metric and compared AC/DC against
a reconstructed baseline for Big Bang Bar. **Roughly seven interruptions on
Big Bang Bar; on AC/DC, zero, zero, a freeze decision that is Matt's by
design, and one confirmation.** That is the plan's entire premise, tested.

| | |
|---|---|
| **The pipeline** | `draft-by-api.ps1`, `verify-draft.ps1`, `reconcile-draft.ps1`, `retrieve-check.ps1`, `new-table.ps1` — two tables end to end. `new-table.ps1` never merges its own branch and never commits to `master`, proven live |
| **The brief pipeline** | `draft-brief.ps1`, `verify-brief.ps1`, `reconcile-brief.ps1`. Six tables have live, Matt-approved briefs |
| **Shared plumbing** | `invoke-model.ps1` (one wrapper, caps, per-call logging), `check-deps.ps1`, `post-discord.ps1` |
| **infra-watch** | A second project, v1 built, running **weekly via Task Scheduler** |
| **project-status** | Notion mirror, live end to end. GitHub Actions calls the Notion API on a successful run. Disk stays the truth |
| **roadmap** | This repo — the cross-project index, lifecycle, and `PRINCIPLES.md` |

Two things that change assumptions:

- **`per_call_max_tokens` went 500 → 8000 → 64000.** The reasoning-token
  finding from Phase A was real and much larger than estimated.
- **33 caddy commits had never reached GitHub** until project-status fixed
  the auth gap on 2026-09-04. The remote existed from Phase A; nothing was
  pushing to it. **A backup that isn't exercised isn't a backup** — worth a
  `PRINCIPLES.md` entry, now learned twice.

## 4. The gap this project closes

**Deterministic scheduled jobs already run unattended. Agentic work does
not.**

infra-watch runs weekly with nobody watching. The Notion hook fires on a
push. Both work.

Every piece of *agentic* work — drafting, fixing, reconciling — still runs as
a supervised sitting Matt starts by pasting a prompt and watches. The
interruption count *inside* a sitting fell from seven to about one, which is
real and large. **The sitting is still synchronous, and Matt still starts
it.**

The queued model in §5 is the smallest thing that changes that.

## 5. The queued runner — the target shape

**Matt writes a task file before bed. A scheduled run picks it up, executes
it under the existing guardrails, and posts the result or the blocker. When
the queue is empty it does nothing.**

That last property is why this is the cheap version: **it fails safe.**

What already exists and is reused unchanged:

| Need | Where it lives |
|---|---|
| A work package that can complete without Matt | `caddy-autonomy-plan.md` §2, seven items |
| Deterministic grading | `verify-draft.ps1`, `verify-brief.ps1` — the pattern, not the files |
| Spend control | `invoke-model.ps1`, `config\model-caps.json`, per-call log |
| Isolation and undo | Branch per run, git remote, hash checks at open and close |
| Notification and decisions | `#run-logs`, `#decisions`, and now Notion |

What has to be built:

- **A queue.** A folder of task files, and a convention for what one contains.
  The seven items in the plan's work-package definition are that convention
  already — this writes them down as a file shape.
- **A trigger.** Task Scheduler, which already runs infra-watch weekly. No new
  mechanism.
- **A stuck-handler.** The stop rule exists on paper — three consecutive
  attempts with no check flipping from fail to pass — and **has never been
  exercised on a real unattended run.** Exercising it deliberately is part of
  this build, not something to discover.

**The honest risk, unchanged:** an agent that keeps going after it is confused
turns overnight progress into several sittings of untangling. The stop rule is
the mitigation and it is unproven.

## 6. The second project

**Model-version review (Qwen / GLM) is the leading candidate**, Matt's
steer of 2026-09-04. It has not been scoped yet and is still Sketched in
`BACKLOG.md` — it becomes Planned when it has its own `planning\` document,
which is the new thread's first real deliverable.

**Update, 2026-09-04, same day — done.** Scoped in
`planning\model-version-review.md`, filed Planned, removed from
`BACKLOG.md`. The collector-vs-own-project question below is carried there
unresolved, not settled by scoping it.

**Why it fits the criteria this project needs from a second package:**

1. **A model does work whose output a script can check.** A benchmark result
   is checkable by construction — that is the routing principle in
   `PRINCIPLES.md`, and the thing the caddy proved.
2. **A different shape from the caddy** — the deliverable is a measurement,
   not a long authored document.
3. **Real value independent of what it proves.** New Qwen and GLM releases
   shipped during the caddy build with nothing to decide on.
4. **Recurring**, so the queue and the schedule get exercised rather than
   run once.

**It reuses the caddy's own `eval\` harness** — `cmp-answer.ps1`,
`step5-baseline.ps1` — which is the natural starting point and also the first
real test of the rule-of-two in §7.

**One unresolved question, carried from `BACKLOG.md`:** does this become a
second collector inside infra-watch, or its own project? Argument for shared:
release-detection overlaps. Argument for separate: the output is a benchmark
result, not a decision queue — a different shape of deliverable. **Not
decided here — tracked in `planning\model-version-review.md` §4, same
question, still open.**

### Not the first task — resolved 2026-09-04

**"Start with 5 missed checks" was about the stop rule, not about this
project's scope.** Matt confirmed the same day. It reads as a proposed
threshold — **five consecutive attempts with no check flipping from fail to
pass** — sitting between the plan's three and the architecture doc's ten. See
§9 and §10.

**Recorded as a leaning, not a filed decision.** Matt's words were *"let's
start with"*, and he then deferred it: *"I can deal with that in the future;
I'll move forward with the handoff."* **Deferring costs nothing right now**
— the queued runner is not being built yet, and scoping model-version review
comes first. It has to be settled before that build begins, not during it.

**A v0.3 draft of this document read it as five unevaluated model releases
and made it the first task.** That was an inference, marked as one, and it
was wrong. Recorded rather than deleted, because guessing at a short phrase
and writing the guess into a plan is precisely the failure this project keeps
finding in its own inheritance.

### Correction — cycling-day rating is live, not a candidate

**v0.2 called it "the smallest item in the backlog" and argued it would
prove almost nothing.** The argument about shape still holds — it is
deterministic and LLM-free, and a queued agentic runner tested on a job with
no agent in it proves nothing — **but the premise that it was unbuilt was
false.**

`UC1 - Cycling Day Rating` is an active n8n workflow: daily 06:00 CT
schedule trigger, Open-Meteo forecast and air-quality calls, a scoring code
node, posting to Discord `#cycling` through a dedicated webhook credential.
Its output was visible in Matt's own Discord screenshots on 2026-08-21.

**Two things follow, and the second is the one that matters.**

`STATE.md` and `BACKLOG.md` are corrected — it is Active, with no folder,
like the vpin skill-building entry.

**And this is the second sync-discipline slip found on 2026-09-04**, the
first being an uncommitted Planned→Active transition sitting in the roadmap's
working tree. This repo's own `CLAUDE.md` names the habit that prevents it:
closing a chunk that changes a project's status also means touching the
matching file here, *"done close to the change, not batched up and
reconstructed later from memory."* **Two misses in one day, on a repo four
days old, is worth noticing** — the discipline is sound and the practice has
not caught up to it yet. Whether that needs a mechanism or just attention is
an open question, not a decision to take here.

## 7. What is shared today, and what is drifting

**Shared, working, no action needed:** `C:\automation\secrets\*.env`; one
`STATE.md` per project; `PRINCIPLES.md`; a private repo per project under one
scoped PAT.

**Copied, with nothing keeping the copies equal:**

- **`notion-status.yml` exists in three repos.** The exact shape A13.2 warns
  about, at three copies.
- **The severity bar and sitting discipline** live in caddy's `CLAUDE.md` and
  are echoed, not referenced, in roadmap's.
- **`invoke-model.ps1`, `post-discord.ps1`, `check-deps.ps1`** are caddy-only
  but general. `check-deps.ps1` is about half general — Ollama, OpenRouter,
  disk, day spend — and half caddy-specific — frozen hashes, the caddy page.

**Rule: extract on the second copy, not on the first.** Speculative extraction
is how a personal project acquires a framework nobody needs.
`notion-status.yml` already meets that bar; nothing else does yet.

**The second project will force this question honestly**, because it will
need `invoke-model.ps1` and `post-discord.ps1`. **Copying them is the correct
first move** — and the moment a second copy exists, the rule says extract.
That is the test running on real evidence rather than on argument.

## 8. What this project should not become

- **Not a framework.** The rule of two in §7 is the guard.
- **Not a second scheduler.** Task Scheduler and GitHub Actions both run
  things already.
- **Not a rewrite of anything working.** The caddy pipeline is proven on two
  tables and should not be refactored to fit a shape it does not need.
- **Not n8n's job.** It stays where it earns its place — scheduled jobs that
  talk to outside services.
- **Not full overnight autonomy**, per §2. That stays available later; it is
  not this.

## 9. Carried items, still open

| Item | State |
|---|---|
| **Kilo / a model-agnostic agent for ad-hoc work** | Never tested. Its case was routing cheap work to a cheap model; weaker now that pipeline steps name their own model in a script |
| **The stop-rule threshold** — three consecutive no-progress attempts (the plan) versus ten consecutive loops (the architecture doc) | **Matt's leaning, 2026-09-04: five.** Stated as *"let's start with"* and then deferred — not filed. **§5's queued runner depends on this rule and cannot be built until it is settled** |
| **The `owned_tables` cross-check** | Three tables unresolved; needs n8n access or a read-only key in `caddy.env`. Caddy's, not this project's — noted because the credential gap is a shared-layer question |
| **A backup that is exercised** | 33 commits sat unpushed for two weeks against a remote created to hold them. Candidate `PRINCIPLES.md` entry |
| **OpenClaw Environment folder connection** | `C:\automation\openclaw` — a component of this project's shared-foundation scope, not the whole of it. Not yet connected to the roadmap: no pointer file, no `STATE.md` row. Matt's call, 2026-09-10: revisit once dev-environment gets active attention and OpenClaw has ramped up further |

## 10. Open questions

1. **Whether model-version review lives inside infra-watch or on its own** —
   §6, carried from `BACKLOG.md`. **This is the first live question.** Now
   also tracked in `planning\model-version-review.md` §4, unresolved
   there too.
2. **The stop-rule threshold** — §9. Matt's leaning is five; deferred
   2026-09-04, and §5 cannot be built until it is settled.
3. **What a task file contains**, exactly — **designed 2026-09-04, see
   `planning\task-file-format.md`.** Two sub-questions carried forward
   unresolved there: item 2 above (the stop-rule threshold) and item 4
   below (where the queue folder lives).
4. **Whether the queue lives in this project's folder or in the project it
   drives.** Affects whether this ever gets a `disk_location`.
5. **Whether the sync-discipline slips in §6 need a mechanism** or just
   attention.
