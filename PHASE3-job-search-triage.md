# PHASE 3 — job search triage

**Chosen 2026-09-11.** The first real project. Not a kickoff-and-go doc — the
shape is settled but several facts still need checking on the machine before
anything is built. Read all of it before starting.

## The decision, and what it displaced

Phase 3 is **OpenClaw scoring job-listing fit overnight**, on rows the
existing job-search pipeline has already collected.

The previous thread's handoff leaned toward newsletter health reporting. That
got displaced for a reason worth recording: Matt has separately and
explicitly said he wants OpenClaw taking over parts of the daily job search,
to cut Claude usage. Newsletter reporting was a reasonable inference; this is
a stated want, on a workflow that already runs, that matters to a goal he's
actively pursuing. Stated beats inferred.

Newsletter reporting isn't dead — it's a good Phase 4 candidate, and the two
gates on it (beehiiv API tier, spend cap) were never checked. The spend cap
is now closed regardless. One honest note carried forward for whenever it
comes up again: Looker Studio already builds the chart half of that project
free from Analytics and Search Console, so the agent's real contribution
there is the written read on what changed, not the dashboard.

## What already exists — don't rebuild any of it

The job-search pipeline is live and working today. Phase 3 replaces exactly
one piece of it.

| Piece | Where it runs now | Phase 3 |
|---|---|---|
| ~7 LinkedIn keyword searches, Minneapolis-scoped, marketing/AI-adjacent director and program-manager titles | Cowork scheduled task "Daily job search 2026 v2", via browser control | **Unchanged** |
| Fit scoring — a 1–10 score and a "why it fits" note per row | Same Cowork task, using Claude | **This is what moves to OpenClaw** |
| Job Tracker spreadsheet, the record of every row | Google Sheets | **Unchanged** |
| Write path to the tracker | A Google Apps Script webhook — the **only** permitted write path | **Unchanged, and still the only one** |
| Resume tailoring for Fit Score = 10 rows | Cowork task `resume-autopilot-fit10`, ~06:00 daily | **Unchanged** |

Two constraints inherited from that pipeline, both non-negotiable:

- **Direct sheet editing is forbidden.** A mis-click in May 2026 overwrote
  header cells. Everything goes through the webhook.
- **The queue is read from the webhook**, `GET {webhook}?report=queue`, not by
  scraping the sheet.

The webhook URL and the tracker URL are both in the `resume-tailoring` skill;
read them from there rather than copying them into a script by hand.

**Treat the webhook URL as a credential, not an address.** Anyone holding it
can write to the Job Tracker — it carries its own authorization in the URL and
there is nothing else in front of it. Under the §5 guardrail added 2026-09-11,
that means it does not get pasted into prompts, hardcoded into a committed
script, or printed by anything a model reads. It belongs in OpenClaw's
`SecretRef` store, which is exactly the case `SecretRef` protects against: a
value a model would otherwise see in a tool call. That is a different store
from the model-provider credentials — see the three-store finding in the
plan's Phase 2 close-out before wiring it.

## Why this job is the right first real one

It lands on the easy path Phase 2 actually proved, which was the whole point
of choosing it on evidence:

- **It reads and writes files and calls an HTTP endpoint. It does not shell
  out.** Phase 2 proved the exec-approval gate only covers `exec`, `process`
  and `apply_patch` — so this job needs none of the plan's §6 allowlist work.
- **It splits across two runners the way the plan predicts is normal.** n8n or
  the existing task collects; OpenClaw judges.
- **The judgment half is genuinely a model's job** and the collection half is
  genuinely not, so the split isn't arbitrary.
- It runs comfortably inside the confirmed overnight window (23:00–05:00 CT),
  on the local model, with the escalation path capped at $5/week.

There's also a plausible side benefit worth testing early rather than
assuming: the Cowork sandbox blocks `script.google.com` outright (403
allowlist), which is why the current pipeline has to call its own webhook
through a browser from a neutral origin, and why POSTs containing query
strings sometimes get blocked by the browser guard. **The OpenClaw container
runs on Matt's own network and probably has no such restriction** — which
would delete that whole workaround. Probably. Verify it first thing; if it
holds, it's a real argument for this project beyond the cost saving.

## Explicitly out of scope

**OpenClaw does not run the LinkedIn searches.** Matt considered it and chose
against it for now. LinkedIn actively fights automation, and browser control
would reopen the approval-permission work Phase 2 just set aside. Revisit
after this ships, not during.

## The design

### Input
Unscored rows from the tracker. **Unknown to resolve first:** the webhook's
`?report=queue` returns `fit10` and `interested` queues — it is not clear
there is an "unscored" queue at all, since scoring currently happens inline
during collection. Check what the webhook exposes before designing around it.
If no unscored queue exists, adding one to the Apps Script is a small change
and belongs to this phase.

**2026-09-12 — checked, blocked on the credential rule, not on effort.** The
webhook URL isn't in any credential store yet (`openclaw secrets audit` shows
only the two known plaintext items from Phase 1 — nothing webhook-related),
so there's no way to make this call without either the URL or its response
passing through a model's context. `scripts\check-webhook-queues.ps1` is
ready: Matt runs it himself, it prompts for the URL hidden, and prints back
only the queue names and row counts — never the URL, never row content.
Waiting on him to run it.

**2026-09-12 — the question is sharper now that gate 3's extraction showed
the live collection task's own payload.** Every job it posts already carries
a `fit_score` and `selected_resume`, assigned inline (Claude, at collection
time) — this pipeline doesn't have an "unscored" state today, it has
"scored-by-the-existing-task" and that's it. That's not a conflict with
Phase 3: the shadow-rollout plan below already has OpenClaw's score going in
a separate column while this scoring keeps owning the real one. But it means
the real gate-2 question isn't "is there an unscored queue" — it's whether
the webhook can return an **all-rows** queue (not just `fit10`/`interested`)
for OpenClaw to shadow-score against. Still needs the same script run to find
out what the webhook actually exposes.

**Also found 2026-09-12, incidental to gate 3, worth recording as its own
thing:** the live task prompt Matt pasted to unblock gate 3 contained the
webhook URL in plain text, so it entered this session's context — exactly what
the 2026-09-11 credential rule exists to prevent, even though nothing was
misused. Not written to any file here or acted on; flagged to Matt directly,
including whether he wants to rotate the Apps Script deployment. His call.

### Work
For each row: read the job description, apply the scoring rubric, produce a
1–10 fit score and a short "why it fits" note. Local model first; escalate
per the settled model policy after two consecutive no-progress attempts.

**Unknown to resolve:** the scoring rubric is currently implicit in the Cowork
task's prompt. It has to be written down explicitly before a local model can
apply it consistently. Capture it from the live task prompt — noting that
Cowork rewrites a scheduled task's prompt after its first run, so read the
current live version from the Scheduled sidebar, not the original.

**2026-09-12 — lives in its own file now, not inline here.** Per Matt's
instruction, the rubric goes in `scoring-rubric.md`, extracted from the live
Cowork prompt exactly as it stands — no cleanup, no improvement on the way
out. Blocked on access, not effort: Cowork's Scheduled sidebar isn't reachable
from this Claude Code session, so the file is a stub until Matt pastes in the
live prompt text. Matt reviews and edits it before anything scores against it.

### Output
Fit Score and Why It Fits, written back through the webhook.

### The check — and its honest limit
The convention is that a model never grades its own output, and checks are
scripts. That works here only partway, and it's worth being clear about
where it stops.

A PowerShell check script can verify **shape**, and should: the score is an
integer 1–10, "why it fits" is non-empty, under a word limit, and actually
references something specific from the job description rather than being
generic. That catches the common failure modes — a missing score, a wall of
text, a hallucinated summary that names nothing from the posting.

A script **cannot** verify that a 7 should have been a 4. There is no ground
truth for a judgment call. So correctness gets checked two other ways:

1. A separate model call, no shared history, scoring a sample independently —
   flag disagreements greater than 2 points for Matt.
2. The shadow period below.

Don't paper over this. Getting a score wrong is not a neutral error here: a
Fit Score of 10 automatically triggers resume generation at 06:00 the next
morning. A bad 10 costs Matt a wasted resume; a bad 4 on a good job costs him
the job.

### Rollout — shadow first
Because of that cascade, OpenClaw does **not** write the real Fit Score on day
one.

1. **Shadow.** OpenClaw writes its score to a separate column. The existing
   Claude scoring keeps running and keeps owning the real Fit Score.
2. **Compare** for at least a week of real rows. How often do they agree
   within 1 point? Where they disagree badly, which one was right?
3. **Cut over** only if the agreement holds, and cut over the scoring only —
   the 6am resume autopilot keeps reading the same column it always has and
   shouldn't notice anything changed.

This costs a week and removes essentially all of the risk. Take the week.

### Stop behaviour
The settled rule, unchanged: two local attempts, escalate, hard stop at five
consecutive no-progress attempts, report to disk, `#alerts` post, `#decisions`
ping, and no restart on the next tick. `proving-ground\run-job.ps1` is the
working reference for all of it.

Result to disk before anything else — disk is the source of truth, the tracker
and Discord are mirrors.

## Where the orchestration lives — decide this before building

Carried from `PHASE2-CLOSEOUT-timer-and-spendcap.md` §B1, and it lands here
rather than there:

The proving ground put orchestration in a **Windows host PowerShell script**
that reaches into the container with `docker exec`. That works, it's proven,
and it matches the project's "checks are caddy-shaped `verify-*.ps1` scripts"
convention. But it also means the trigger has to be host-side, which rules out
both n8n and OpenClaw's own scheduler, and it sits awkwardly against the
project's stated aim that OpenClaw is *the place work is started, watched,
approved and reported*.

**The evidence is now in, gathered 2026-09-11 during Phase 2's close-out.**
Both alternatives to host PowerShell were checked on the real machine and both
are ruled out:

- **n8n cannot reach Docker at all.** Inspected the running container
  directly: no Docker socket mounted (`/var/run/docker.sock` is absent inside
  it), no `DOCKER_HOST` set. It has no path to Docker, let alone to a host
  PowerShell script.
- **OpenClaw's own scheduler cannot invoke a host command.** Its command and
  script payloads run entirely inside the Gateway process, so it can neither
  run `run-job.ps1` nor `docker exec` into another container.

So for anything shaped like the proving ground, **Windows Task Scheduler is
the only working trigger**, and the architecture question narrows to: does the
orchestration itself move inside OpenClaw, or does it stay on the host where
Task Scheduler can reach it? That is still Phase 3's call — but it is now a
real either/or, not a three-way.

**One finding from that check belongs in the design, not just the record:**
OpenClaw's failure notifications only fire for a job that *starts and then
errors* — two consecutive failures, one-hour cooldown. They do not detect a
job that never started. So even moving orchestration inside OpenClaw would
**not** close the silent-non-start gap on its own. A dead-man's check is
required either way; it is not a workaround for having picked the host.

**Where the dead-man's check should live in Phase 3.** The proving ground's
version is its own scheduled task, which leaves the obvious hole: if the
checker itself fails to run, silence looks like success again, one level up.
Acceptable for a throwaway proof, not for a recurring real job. In Phase 3 the
staleness check belongs **inside infra-watch's existing schedule** rather than
as a task of its own — infra-watch already runs reliably, already owns this
class of problem, and already has the Discord webhook path that works when the
`openclaw` container is down. One fewer independent thing that can quietly
stop.

The one thing that shouldn't move inside the agent regardless: the check
script. Whatever else changes, the thing that grades the work stays outside
the thing that does it.

### Two rules from 2026-09-11, learned the hard way

Both came out of a dry run that was only done because the overnight test was
about to depend on an untested path. Both apply to anything built on this
machine from here.

**1. An alert path must not depend on the thing it reports on.**
`run-job.ps1` posts to Discord by running a command *inside* the `openclaw`
container. So when the container is down — the exact moment an alert matters
most — the job cannot tell anyone. It logs a warning to a file nobody is
reading at 01:00 and that is the end of it. The only alert that survived the
outage was the staleness check, which posts over infra-watch's host-side
webhook and never touches Docker.

For Phase 3, the job's own alerts go over the host-side webhook, not through
the container. Tonight's proving-ground run deliberately keeps the broken
version because it produces cleaner evidence of exactly this, but nothing real
should inherit it. Generalized: **before trusting any alert, ask what it
depends on, and whether that thing is still working in the scenario the alert
exists to report.**

**2. This machine runs Windows PowerShell 5.1, and that changes how scripts
must be written.**
Under `$ErrorActionPreference = 'Stop'`, *any* stderr redirect on an external
command — `2>&1` and `2>$null` alike — turns that command's error output into
a script-killing error. So the moment `docker` became unreachable,
`run-job.ps1` died before it could record the failure or save its state. The
counter never moved, the stop rule never triggered, and the crash looked like
silence.

This is not specific to Docker. Every script on this box that calls an
external command under `'Stop'` has the same trap. The working pattern is to
relax `$ErrorActionPreference` around each external call and check the exit
code explicitly. Assume nothing about which line is at fault — the first
diagnosis of this bug was wrong, and only an experiment settled it.

The deeper habit worth keeping: **a failure path that has never been run is
not a failure path.** The passing case had been exercised eight times; the
container-down case had never been run once, and it was broken.

### Open risk, quantified 2026-09-12: the local model's first-try reliability

The proving ground's task is about as easy as a model task gets: read one
sentence, write a one-line summary under 22 words with a fixed literal token
at the end. Every clean, infra-unaffected first attempt on record — three of
them, across two days and two different machine states — **failed**. Zero
passes on a first try, out of three. The only pass anywhere in the log
happened on a second attempt, after the state had already recorded one
failure. Counting every clean local-model attempt regardless of try number
(both attempt 1 and attempt 2 use the local model), that's 1 pass in 5 clean
attempts — 20% — and even that one pass required a retry.

Sample size is small; three is not a confident estimate of a true rate.
But it is not "roughly 50%, worth a footnote" — it is 0% on the first try in
every clean instance observed, on the easiest possible task. Fit-scoring a
real job posting is a harder task than summarizing one sentence, so there is
no reason to expect this number to improve for Phase 3's actual work, and
some reason to expect it to be worse.

This bears directly on Phase 3's design, not just its risk log:

- **The escalation policy already assumes some first-try failure** ("two
  local attempts, escalate") but was not sized against a first-try rate this
  low. At roughly a 1-in-5 chance of the *second* local attempt also failing
  (see the 06:28 sequence in `proving-ground\run-log.txt`, where attempt 2
  failed too), a meaningful fraction of rows will escalate to the paid model
  just to get a valid response shape at all — before the shadow-scoring
  comparison in the rollout plan above even gets to judge whether the score
  itself was good. That's spend the $5/week cap needs to absorb, not just
  the deliberate hard-stop failures Phase 2 sized it against.
- **Before the shadow period starts, measure this specific number on the
  real scoring task**, not just infer it from the proving ground: how often
  does the local model produce a validly-shaped response (right format, a
  1–10 score, non-empty rationale) on the first attempt, across a real batch
  of job rows. If it's anywhere near what the proving ground showed, either
  the model, the prompt, or the local-first policy for this specific job
  needs to change before Phase 3 goes live — not after a week of shadow data
  quietly burns budget on retries.

**Update, 2026-09-12 — a second, contradicting measurement, recorded as-is.**
Diagnosed the failure directly rather than guessing: called the local model
11 times outside `run-job.ps1`, same container, same agent, same task, and
inspected each raw response. Plumbing is fully ruled out — 9 of the 11 wrote
a correct file at the correct path on the first call, the write tool never
failed when the model actually invoked it, and neither failure left a stray
file anywhere on the container's filesystem. Both failures were the model
itself stopping early: one call read the input file and then never called
`write`; the other made no tool calls at all and stopped after one turn. So
the mechanism is confirmed — this is the model quitting a two-step task
partway through, not a path or permissions problem.

That gives 9-of-11 (82%) in this direct session, against 0-of-3 to 1-of-6
seen via the actual scheduled runs in `proving-ground\run-log.txt`. Both
numbers are real; they disagree, and nothing so far explains the gap — same
container, same session, no obvious environmental difference between the two
sets of calls. Recorded rather than reconciled: **Matt's call is that eleven
runs of a throwaway task isn't grounds for reopening the settled model
policy**, so this stays a Phase 3 risk to watch, not an action taken. Whoever
picks this up before or during the shadow period should treat both numbers as
real, take neither as the true rate, and get a larger sample on the actual
scoring task before drawing a conclusion.

## Guardrails, set 2026-09-12

Two limits Matt set before any building starts, both standing until he says
otherwise:

- **Shadow-period runs are capped at ~10 rows each.** Don't score a full
  backlog to gather comparison data — a small batch per run, repeated, not
  one large one.
- **Nothing gets written to the Job Tracker — the real Fit Score column or
  the shadow column — until Matt confirms he's backed it up.** He'll say when
  it's clear. Until then, every part of this phase that reads the tracker is
  fine; anything that writes to it waits.

## Gates before any building starts

1. **Done, 2026-09-12.** Phase 2's close-out is done — spend cap live and
   verified, timer proven, dead-man's check in place. See `STATE.md`.
2. **Blocked on Matt, 2026-09-12.** The webhook's unscored-row question isn't
   answered yet — see the note under Input above. `check-webhook-queues.ps1`
   is ready for him to run.
3. **Blocked on Matt, 2026-09-12.** The scoring rubric isn't written down yet
   — see the note under Work above. `scoring-rubric.md` is a stub waiting on
   the live Cowork prompt text.
4. **Done, 2026-09-12.** `script.google.com` answers from inside the OpenClaw
   container — `HTTP 302` in ~0.2s on a plain `curl`, no block, nothing like
   Cowork's sandbox restriction. Domain-level reachability only; the actual
   webhook round-trip is gate 2's job once it's answered.

Turned out two of the four need something only Matt has (a webhook URL, and
Cowork's own UI) — not a correction to "none of these need Matt," just where
this particular pair landed.
