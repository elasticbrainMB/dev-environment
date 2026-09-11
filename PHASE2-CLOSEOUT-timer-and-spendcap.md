# PHASE2-CLOSEOUT — spend cap and the timer proof

**2026-09-11.** Two tasks that close Phase 2 completely. Matt has decided
both, so nothing here needs a decision from him. Three steps in Task A are
his to *run* rather than decide, because they handle credentials — see the
credential rule below.

Read `STATE.md` for where the project stands. The short version: the proving
ground is built, run, and pushed. Two properties are still unproven — a
weekly spend ceiling, and a timer firing a job with nobody watching. This
doc closes both.

---

## The credential rule this project follows

**No credential value ever enters a model's context.** Not a Cowork prompt,
not a Claude Code prompt, not a file a model reads back, not a command whose
output a model sees. Added as a standing guardrail 2026-09-11 at Matt's
instruction, and it applies to every phase from here, not just this task.

The boundary that matters is **the model's context and the session
transcript** — not "visible anywhere". Matt's own screen and his own
PowerShell window are fine. A transcript is not: it persists, it syncs, and
it is read back by future sessions.

The practical division that falls out of it, and the one this task uses:

- **Matt owns anything with a secret in it.** He runs those commands himself,
  in his own window, with secure prompts.
- **Claude Code owns everything else** — writing the scripts (which contain no
  secrets), and every step that has no credential in it.

Write scripts so that a secret is read from a secure prompt, used, and
discarded, and so that nothing ever prints a key to stdout that a model will
read.

---

## Task A — put a hard weekly spend ceiling on the escalation path

**Decision: $5 per week, enforced by OpenRouter, not by our own script.**

The plan assumed this cap would have to be built into the job. It doesn't.
OpenRouter can put a spending limit on an individual API key and refuse
requests once the limit is reached — the rejection happens before the request
reaches a model, so a blocked request costs nothing. The limit resets
automatically, weeks running Monday to Sunday, midnight UTC.

This is better than a check inside `run-job.ps1` for one reason worth stating
plainly: it holds even when our code is wrong. A budget check we write only
protects us if every job remembers to call it and the counter is never
corrupted. A ceiling on the key protects us even if a job loops, even if
`state.json` is deleted, and even for a job nobody has written yet.

Sizing: Phase 2's worst case — a job failing all the way to a hard stop, three
paid attempts — cost $0.927612. $5 covers roughly five of those in a week.

**Two credentials are involved, and they are very different.** A **Management
API key** can create and delete keys across the whole account — it is the most
privileged thing in this project. The **capped key** it creates can spend at
most $5 a week. The management key is needed exactly once, for setup, and
should not survive it.

### A1 — Claude Code: write the two scripts

Both go in `scripts\` and both get committed. **Neither contains a secret.**

**`scripts\setup-openrouter-cap.ps1`** — run once by Matt:

1. Prompt for the management key with `Read-Host -AsSecureString`. That keeps
   it off the screen and out of PSReadLine history. Convert it in memory only.
2. `POST https://openrouter.ai/api/v1/keys` with
   `Authorization: Bearer <management key>` and body:
   ```json
   { "name": "openclaw-automation", "limit": 5, "limit_reset": "weekly" }
   ```
3. The response carries the new key's secret **once and only once**. Handle it
   without printing it if you can: check whether
   `openclaw models auth paste-api-key` accepts the value on stdin, and if it
   does, pipe it straight through. If that command is interactive-only, print
   the key once with a clear instruction for Matt to copy it into his password
   manager and paste it at the prompt, then `Clear-Host`. Printing to Matt's
   own screen is acceptable; leaving it in a transcript is not — and since
   Matt runs this script, not you, its output never reaches your context
   either way.
4. Print only non-secret confirmation: key name, `limit`, `limit_reset`,
   `limit_remaining`.
5. **Print the two follow-up actions as the last thing on screen**, in plain
   words, so Matt doesn't have to remember them. Something close to:

   ```
   Done. Two things left, both yours:

     1. Save the capped key in your password manager (Bitwarden/1Password/
        similar - NOT a .env file). It is the key OpenClaw now uses to pay
        for escalated model calls. Capped at $5/week.

     2. DELETE the management key you just used, at
        https://openrouter.ai/settings/management-keys
        It can create and delete keys on your whole account and it has now
        done its only job. The capped key is not affected.

   Report back to Claude Code: limit, limit_reset, limit_remaining (above).
   Do not paste either key.
   ```

   The two keys are easy to confuse, so name them distinctly everywhere: the
   **management key** (account-wide, setup-only) and the **capped key**
   (`openclaw-automation`, $5/week). Never just "the key".
6. Clear the variables holding either key before exiting.

**`scripts\verify-openrouter-cap.ps1`** — run by Matt whenever the ceiling
needs checking:

- Prompt securely for the **capped** key (from his password manager — not the
  management key; this script must never need that one).
- `GET https://openrouter.ai/api/v1/key` — note the **singular** path. This
  endpoint reports on whichever key authenticates the call, so it needs no
  privileged credential at all.
- Print `limit`, `limit_remaining`, `limit_reset`, and `usage_weekly`.

That singular endpoint is what makes this clean: **all verification from here
on needs only the $5-capped key.** The management key is a setup-only
credential.

### A2 — Matt: run the setup script, once

In his own PowerShell window. You do not run this and you do not see its
input or its output. Ask him to report back only the three non-secret numbers
it prints: `limit`, `limit_reset`, `limit_remaining`.

He should save the capped key to his password manager at this point. It is the
only copy outside OpenClaw's credential store.

### A3 — Matt: delete the management key

Once A2 has reported a good `limit_remaining`, **the management key gets
deleted** at `openrouter.ai/settings/management-keys` — the same page it was
created on. It has done its one job, and it is the most privileged credential
in this project: it can create and delete keys across the whole account.
Deleting it does not affect the capped key.

If another capped key is ever needed later, a fresh management key takes a
minute to create. There is no reason to keep this one around in the meantime.

The setup script prints this instruction itself (A1 step 5), so Matt sees it
at the moment it applies. Confirm with him that it's done rather than
assuming — an undeleted management key is the kind of thing that quietly
survives for a year.

### A4 — Where the capped key goes

Phase 2 established that OpenRouter credentials live in OpenClaw's
model-provider credential store — `openclaw models auth paste-api-key` — not
in `.env` and not as a `SecretRef`. That is a third storage mechanism,
distinct from both; don't re-derive it. The new capped key replaces the
existing OpenRouter credential there.

`run-job.ps1` hardcodes `openrouter/~anthropic/claude-sonnet-latest` as the
escalation model. It needs **no change** — the ceiling lives on the key, so
swapping the credential is the whole job.

Also confirm the account credit balance is non-zero. Per-key limits all draw
from the same account balance; a $5 ceiling stops this key overspending, it
does not put credits in the account.

### A5 — Verify the ceiling is real, not just configured

This project's standing practice is to verify against the system rather than
trust a setting. Two checks, neither needing the management key:

1. Matt runs `verify-openrouter-cap.ps1` and reports the numbers. Confirm
   `limit` is 5 and `limit_reset` is weekly.
2. Run the proving ground once through the escalation path — set
   `state.attempt` to 2 in `state.json` so attempt 3 goes paid — then have
   Matt run the verify script again. `limit_remaining` should have dropped by
   roughly the run's cost. **That is the check that matters**: it proves spend
   is actually counted against this key and not some other one. A configured
   limit on the wrong key looks identical to a working one until a bill
   arrives.

Don't try to prove the rejection by burning $5. Check 2 is enough.

### A6 — Record it

Add to `STATE.md`'s decisions table and note in the plan that open question 1
("does OpenClaw enforce budgets, or must the job's own check script?") now has
a third answer neither option anticipated: **the provider enforces it, and
that's the strongest of the three.**

---

## Task B — prove a timer fires the job with nobody watching

**Decision: close this now on the proving ground, rather than folding it into
Phase 3.** Matt's reasoning, which I agree with: find scheduling problems on a
throwaway job, not while also debugging real logic.

**Matt's stated preference was to fire it from n8n.** Reading `run-job.ps1`
before writing this changed my recommendation, and you should know why before
you start.

### B1. The complication, stated honestly

`run-job.ps1` is a **Windows host** script. It uses PowerShell, Windows paths,
and `docker exec` to reach the `openclaw` container from outside. Whatever
fires it has to be able to run host PowerShell and reach Docker.

That rules n8n out as written — n8n runs inside a container and can't invoke
host PowerShell without new plumbing. It also rules out OpenClaw's own
built-in scheduler, for the same reason in the other direction: the scheduler
is inside the container and the script is outside it.

So there is a real fork here, and it belongs to Phase 3's design more than to
this task:

- **Keep orchestration in host PowerShell** (what exists, and what the
  project's "checks are scripts, caddy-shaped" convention points at). Then
  Windows Task Scheduler is the natural trigger.
- **Move orchestration inside OpenClaw** (what "OpenClaw is the place work is
  started, watched, approved and reported" implies). Then OpenClaw's own
  scheduler triggers it, and it reportedly has native failure notification,
  which is directly relevant to B3 below.

**Don't resolve that fork here.** Close the proof point the cheap way, and
carry the fork into Phase 3 where it actually matters.

### B2. What to do

Spend no more than about fifteen minutes checking whether either of these is
clean on the real machine, since either would be better than Task Scheduler
if it works without new infrastructure:

- Can the n8n container reach the Docker socket or a Docker TCP endpoint? If
  yes, n8n could `docker exec` into `openclaw` directly — though the
  PowerShell orchestration would still need somewhere to live.
- Does OpenClaw's scheduler (`docs.openclaw.ai/automation/cron-jobs`) have any
  way to invoke a host command, and what does its failure notification
  actually do?

Record what you find either way — it's the input Phase 3 needs.

**Then, unless one of those turns out to be clean, default to Windows Task
Scheduler.** It is the only trigger that runs the proven script unchanged, and
the point of this task is to close a proof point, not to re-architect.

Set it up as:

- Runs as Matt's own user account, **"Run whether user is logged on or not."**
- Working directory set explicitly to
  `C:\automation\dev-environment\proving-ground`.
- The known failure mode to watch for: Docker Desktop runs per-user, and a
  task running in a non-interactive session often cannot reach it. If
  `docker exec` fails from the scheduled context but works from your
  interactive shell, that's this — and finding it here, on a throwaway job, is
  exactly why Matt chose to test it now.
- Schedule it inside the confirmed overnight window (below), at a time you can
  still be around to observe the first fire.

**Creating a scheduled task may hit the same standing-action classifier that
blocked `git push` in Phase 1.** If it does, that's a hard block — report it
and stop, don't work around it.

### B3. The gap Phase 2 couldn't see, and the thing actually worth proving

Phase 2 proved the job handles *its own* failures — five attempts, a hard
stop, a report, a Discord ping. It could not prove what happens when the job
**never starts at all**, because a human was watching every run.

Read the top of `run-job.ps1`: `$ErrorActionPreference = 'Stop'`. If
`docker exec` is unreachable — which is precisely the Task Scheduler failure
mode above — the script dies before it reaches any Discord call and before it
writes any state. Nothing posts. Nothing is written to disk. An unattended job
that fails to start is **completely silent**, and silence currently looks
exactly like success.

For a job nobody is watching, that is a bigger hole than anything Phase 2
closed. So this task is not done when a timer fires successfully. It's done
when a timer firing into a *broken* system is also visible.

Add a dead-man's check. Shape is your call; the cheapest version that works:

- `run-job.ps1` touches a heartbeat file at the very start, before anything
  that can throw.
- A separate small scheduled check — or a step in the existing `infra-watch`
  job, which already exists for this class of problem — posts to Discord's
  `#decisions` channel if the heartbeat is older than the window it should
  have run in.

Wrapping the body of `run-job.ps1` in try/catch with a Discord post in the
catch is worth adding too, but it is **not** a substitute: it can't fire if
the script never launched, which is the case that matters.

### B4. Prove it, don't claim it

Same standard as Phase 2 — real evidence, not a self-report:

1. A scheduled fire that passes, with Matt not at the keyboard: the run log,
   the output file, and the `#alerts` post.
2. A scheduled fire into a deliberately broken system — stop the `openclaw`
   container, let the timer fire — and confirm you find out about it. This is
   the new one, and the one that matters.
3. Confirm the stop-rule no-restart behaviour survives a *real* scheduled
   tick, not just the hand-run one Phase 2 tested.

### B5. Then tear down the proving ground

Once all three are observed: the proving ground has done its job. Delete the
scheduled task and the dated output files, and leave `proving-ground\` in git
as a working reference — its value now is as a worked example for Phase 3, not
as something that runs.

---

## Confirmed work windows

Matt confirmed these, with one correction to what the plan proposed:

| Window | Times (Central) | For |
|---|---|---|
| Overnight | **23:00 – 05:00** | Heavy local model work while the GPU is free |
| Daytime | 09:00 – 16:00 | Light collection and checks; an approval can be answered within an hour or two |

The overnight window ends at **05:00, not 06:00** — Matt is an early riser and
is usually online around 05:15, so work should be finished and reported by
then, not still running. Anything scheduled overnight needs to complete inside
that window, not merely start in it. Include the model warm-up the plan calls
for before the window opens.

Update plan §10.3 to record these as confirmed.

---

## When you're done

Update `STATE.md` and the plan, commit, and push — the scoped `git push`
permission from Phase 1 should let that go without asking.

Then Phase 3 is next, and it's scoped already: see
`PHASE3-job-search-triage.md` in this folder. Don't start it from this doc.
