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
