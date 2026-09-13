# PROGRESS.md — dev-environment

Running log, append-only. Never rewritten, only added to. Matt reads this
through OpenClaw instead of asking for status — see the 2026-09-12 decision
in `STATE.md` on the reporting mode this follows.

---

## 2026-09-12 — Phase 2 closed: the overnight test, the pwsh bug, and what it actually proved

**What happened, in order.** Reviewed the overnight timer test from
2026-09-11 into 2026-09-12 against the evidence on disk, not the plan: every
tick from 23:00 to 00:50 crashed with `pwsh.exe ... Access is denied`, a bug
nobody had planted. Both alert channels reported it anyway, starting at
23:00 — the dead-man's check caught a real failure on its first night, which
is a stronger result than the synthetic one it was built to prove.

Root cause: `run-job.ps1` called `pwsh` for its verify step. On this machine
`pwsh` is a Microsoft Store execution-alias stub, not a real install — it
only resolves inside an interactive desktop session, and the scheduled
task's restricted logon (S4U) has none. Fixed by switching to `powershell.exe`
(`proving-ground\run-job.ps1:128`), which is the real, installed interpreter.

**Tried to prove the fix through the scheduler, not by hand.** Registering a
fresh one-off task hit `Access is denied` on `Register-ScheduledTask` — a
genuine Windows permission wall, not a Claude Code prompt. Used
`Start-ScheduledTask` on the existing registered task instead, which still
runs under the real restricted logon context. Confirmed clean: no crash,
state advanced correctly.

**Decided on my own:** rebuilt `setup-timer-proof-tasks.ps1` for 2-minute
ticks (~27 minutes end to end instead of 3 hours) so Matt could iterate the
same day instead of losing a night per attempt, and widened the pass phase
to 5 ticks after Matt pointed out 2-3 was too thin against a flaky local
model. Matt ran the compressed sequence himself, elevated — it reproduced
the give-up rule on a real timer (hard stop at 07:28:43) and the heartbeat
staleness detection (STALE from 07:33:42), matching the original design.
**What didn't fully land:** the compressed run's task duration ended exactly
on the stop tick, with no further tick left to prove a stopped job stays
stopped on a *subsequent* real scheduled tick — that property is still only
hand-proven, from Phase 2's original 2026-09-11 close-out. Matt's call:
not worth a second attempt at the cost of the exercise. Recorded as a
deliberate stop, not left open.

**Diagnosed the local model's reliability rather than guessing.** Matt
pushed back on treating a 0-of-3 first-try pass rate as a footnote. Called
the model 11 times directly, outside `run-job.ps1`, and inspected each raw
response instead of just the pass/fail summary. Ruled out plumbing
completely: 9 of 11 wrote a correct file at the right path; the two
failures were the model itself stopping early (one read the input and never
wrote; the other made no tool calls at all), not a wrong path or a
permissions problem — confirmed by checking the whole container filesystem
for a stray file and finding none. **Surprise:** this direct-call session
passed at 9-of-11 (82%), well above the 0-of-3 to 1-of-6 the actual
scheduled runs showed, and nothing found so far explains the gap — same
container, same session. Matt's call: real, but not grounds to reopen the
settled model policy on eleven runs of a throwaway task. Both numbers went
into `PHASE3-job-search-triage.md`'s risk section as-is, including that they
disagree.

**Closed out today:**
- `STATE.md` — Phase 2 marked Done. Corrected a stale line from Phase 2's
  original close-out that blamed the scheduled-task block on the same
  mechanism as Phase 1's `git push` block; they're not the same thing (see
  below).
- Removed the dated per-run output files (`output-*.txt`,
  `report-stopped-*.md`) from `proving-ground\`. **Decided on my own:** kept
  `run-log.txt`, `state.json`, `heartbeat.txt`, and
  `heartbeat-check-log.txt` — they're the evidence of what actually
  happened, and the folder's whole future value is as a worked reference,
  which needs its logs. Only the bulky per-run artifacts came out.
- **Could not remove the four scheduled tasks.** `Unregister-ScheduledTask`
  hit the identical `Access is denied` wall as registration — confirmed a
  fourth time, on the real production task names this time, not just a test
  one. This needs real Windows administrator rights, which Matt has said
  he's not granting Claude Code for this. **Still open, needs Matt:** run
  `Unregister-ScheduledTask -TaskName 'proving-ground-run-job',
  'proving-ground-heartbeat-check','proving-ground-break-container',
  'proving-ground-restore-container'`, elevated, whenever convenient.
- Two Phase 3 guardrails recorded per Matt's instruction: shadow runs capped
  at ~10 rows each, and no write to the Job Tracker (real or shadow column)
  until Matt confirms a backup is done.
- New communication mode takes effect from here: report at milestones, not
  per step; write reversible decisions down rather than asking first; stop
  only for data-loss risk, real spend, or a decision only Matt can make.

**Committed:** the closeout changes above (STATE.md, the two removed
output-file classes, PHASE3 risk-section update and guardrails). Scheduled
task removal is not part of that commit — nothing to commit, it didn't
happen.

**What's next:** starting Phase 3's four machine-checkable gates now, per
Matt's instruction, reporting once at the end rather than per gate.

---

## 2026-09-12 — Phase 3 gates: two done, two need Matt

Worked all four of Phase 3's opening gates in one pass, reporting once here
rather than per gate, per the new mode.

**Gate 1 (Phase 2 close-out done):** closed by the work above, same day.

**Gate 4 (`script.google.com` reachable from the OpenClaw container):**
confirmed directly — `curl` from inside the container got `HTTP 302` in
about 0.2 seconds, no block. Cowork's own sandbox blocks this domain
outright (403), which is part of why this project exists; the OpenClaw
container has no such restriction. This is domain-level reachability only,
not a full webhook round-trip — that's gate 2's job.

**Gate 2 (does the webhook expose an unscored queue) — blocked on Matt, not
on effort.** Checked first whether the webhook credential already lives
anywhere accessible without a model seeing it: `openclaw secrets audit`
inside the container shows only the two known plaintext items from Phase 1
(the OpenRouter profile key, `OLLAMA_API_KEY`) — nothing webhook-related.
It hasn't been wired in yet. Per the 2026-09-11 credential rule (the webhook
URL is a write credential for the tracker, not just an address), I can't
call it myself without either the URL or the response passing through my
context. Wrote `scripts\check-webhook-queues.ps1` instead, same pattern as
the OpenRouter setup scripts: Matt runs it himself, it prompts for the URL
hidden, and prints back only the queue names and row counts. Waiting on him
to run it and report the output.

**Gate 3 (the scoring rubric written down) — blocked on Matt, not on
effort.** Created `scoring-rubric.md` as a stub with the reason spelled out
in the file itself: the live prompt only exists in Cowork's Scheduled
sidebar, a surface this session has no tool access to, and reconstructing it
from memory would risk exactly the quiet "improvement" Matt explicitly said
not to do. Waiting on him to paste in the live prompt text (or the
fit-scoring portion of it).

**Decided on my own:** wrote both blocked items into `PHASE3-job-search-triage.md`
directly (not just this log) so the doc stays the live source of truth, and
updated `STATE.md`'s Phase 3 row to show exactly which two gates are done and
which two are waiting, and why.

**What's next:** waiting on Matt for the webhook queue check and the live
rubric text. Nothing else in Phase 3 can proceed past those two without
guessing at things he explicitly asked not to be guessed at.

---

## 2026-09-12 — gate 3 closed, and a credential incident along the way

Matt tried the scheduled-task removal command and it failed:
`Unregister-ScheduledTask : Cannot convert 'System.String' to the type
'System.Management.Automation.SwitchParameter'`. My mistake — I wrapped it
in `powershell.exe -NoProfile -Command "..."`, and the outer shell expanded
`$false` to the literal text `False` before the inner command ever parsed
it, which the SwitchParameter binder then rejected. He was already at an
elevated PowerShell prompt, so the wrapper was unnecessary and actively
harmful. Corrected: gave him the bare command with no wrapper. Not yet
confirmed run.

Matt also pasted the full live prompt of the `daily-job-search-2026-v2`
Cowork task, unblocking gate 3. Extracted the scoring-relevant sections
verbatim into `scoring-rubric.md`: core principle, both exclusion sections,
seniority, the fit-score rubric, and the resume-variant assignment. Left out
the LinkedIn/ATS sourcing steps and the webhook POST mechanics as out of
scope for scoring — **decided on my own**, stated plainly in the file and to
Matt so he can redraw the line if he disagrees.

**Incident, not a footnote:** the pasted prompt contained the live Job
Tracker webhook URL in plain text, so it entered this session's context —
the exact scenario the 2026-09-11 credential rule exists to prevent, via a
path nobody had anticipated (a task prompt, not a script or a manual
command). Nothing was misused: I didn't echo it, write it to any file, or
use it in a command. Flagged directly to Matt, including that the URL now
sits in this session's transcript and asking whether he wants to rotate the
Apps Script deployment — that's genuinely his call given the blast radius
(every consumer of that URL would need updating), not something to decide or
act on unilaterally.

**Learned from this:** the credential rule so far had been about what
*scripts* and *commands* touch. A live task prompt is a third path a secret
can arrive by, and it's not one I was checking for before this happened.
Worth remembering for anything pasted in going forward, not just anything
typed or run.

**Also sharpened gate 2** using what the extracted prompt revealed: the
existing pipeline already assigns `fit_score` to every job inline at
collection (Claude, not a separate scoring pass), so there's no genuine
"unscored" state to query — the real open question is whether the webhook
can return an all-rows queue, not an unscored one. Still needs Matt to run
`check-webhook-queues.ps1`.

**Gate status: 3 of 4 done.** Only the webhook queue check remains.

---

## 2026-09-13 — webhook check script was too shallow, fixed before it leaked anything

Matt ran `check-webhook-queues.ps1` and got back `status : (not a list)` and
`queue : (not a list)` — not useful, and not obviously wrong either, so
worth digging into rather than asking him to just try again.

Root cause: the script only ever looked one level deep, and it labeled
*anything* that wasn't a top-level array as "(not a list)" — including a
perfectly normal string like `status: "ok"`. `queue` not being a top-level
array is real information (the response is wrapped, or nested, or something
else), but the script had no way to show what it actually was.

**Decided on my own:** rewrote it to walk one level deeper and describe what
it finds — array counts, an object's own key names, and (top level only) a
bare scalar's actual value. Tested the new logic against three mock response
shapes before handing it back to Matt for a third round: nested named
queues, a single collapsed row object, and a null queue.

**Caught a real bug in my own fix via that test, before Matt ever saw it:**
the first version of the deeper walk printed a nested object's scalar
children too — which is exactly what would happen if `queue` turns out to be
a single job row (`{row, company, title}`) instead of a group of lists. That
would have printed the company and title straight to Matt's terminal,
breaking the "never row data" promise the whole point of this script rests
on. Fixed before it ever ran for real: past the top level, a scalar's value
is hidden and only its name and type print. Caught by testing against mock
data, not by inspecting the code by eye — worth remembering as a general
practice for anything that walks an unknown, possibly-sensitive response
shape.

**What's next:** waiting on Matt to run the updated script and report back
what it shows.
