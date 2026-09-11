# PLAN-dev-environment-v1 — the build plan

**v1, 2026-09-10.** Supersedes `roadmap\planning\dev-environment.md` (v0.5,
same day), which stays on disk as history. This document is written after
four decisions Matt made on 2026-09-10 and after a read of what is actually
installed — the OpenClaw folder, the roadmap repo, and the current release
notes. Everything asserted about disk was read from disk; everything
asserted about OpenClaw 2.0 has a source in §11 or is marked unverified.

**Lifecycle: Active.** Folder at `C:\automation\dev-environment`. Canonical
status file is this folder's `STATE.md`.

---

## 1. The correction that made room for this plan

**The planning document's chosen first project no longer exists.**

`planning\dev-environment.md` §2 and §6 name model-version review (Qwen /
GLM) as the second project the queued runner would be proved on. The
roadmap's own `STATE.md` records it as **dropped on 2026-09-05**, "before
reaching Active," with its pointer file moved to `roadmap\_to_delete\`.
v0.5 of the planning document was written on 2026-09-10 and did not catch
it.

**That is the third sync-discipline slip on this repo**, after the two
recorded in the planning document's own §6. The first two were caught by
reading disk; so was this one. The pattern is consistent enough to answer
that document's open question 5: **this needs a mechanism, not more
attention.** A candidate mechanism is in §9.

The practical effect is good — the "first increment" slot was empty, which
is exactly what §3 fills.

## 2. What this project is now

**A shared foundation for running work across projects, with OpenClaw 2.0
as the place work is started, watched, approved and reported.**

Two things changed from v0.5. First, Matt's decision to move off Claude as
his primary entry and management point, which gives the project a front
door it didn't have. Second, OpenClaw 2.0 shipping a scheduler, which
removes most of the runner v0.5 planned to build by hand.

**What this project is still not** — carried unchanged from v0.5 §8, and
all five still hold:

- Not a framework. The rule of two is still the guard.
- Not a second scheduler. There are now three, and §4 says which runs what.
- Not a rewrite of anything working. Caddy and infra-watch are not touched.
- Not full overnight autonomy. The queued middle ground is still the target.
- Not n8n's job — **amended**: n8n is now an explicitly named runner, not an
  exclusion. See §4.

## 3. Decided — Matt, 2026-09-10

| | Decision |
|---|---|
| **Front door** | **OpenClaw runs, Claude plans.** OpenClaw's control UI and Telegram become where jobs are triggered, watched, approved and read. Claude stays for scoping, architecture and hard debugging |
| **First build** | **A deliberately trivial job first**, proved end to end including firing the stop rule on purpose. The real first project is chosen after that, on evidence |
| **Runner** | **Split by whether a model is involved**, with n8n available as a third runner for scheduled work that talks to outside services |
| **Model policy** | **Local first, escalate on repeated failure.** Local models do every step; a step whose check fails twice escalates to a paid model, logged and capped |
| **Front door channel** | **Discord**, decided 2026-09-11 once Claude Code found it already live and wired to approvals. Telegram stays configured but off — no migration, no restore. This resolves §10 open question 4 for good: one channel, Discord, across OpenClaw and the existing caddy/infra-watch projects. Nothing to reconcile |
| **Secrets migration scope** | **Only what the audit flagged** — `OLLAMA_API_KEY` — decided 2026-09-11. The other three plaintext secrets in `.env` (gateway password, two bot tokens) stay as-is; they're boot-time infrastructure values a model never sees in a tool call, which is what `SecretRef`s exist to protect against |

## 4. The three runners, and the rule that routes between them

| Runner | Runs | Why it, and not the others |
|---|---|---|
| **OpenClaw Automations** | Anything where a model makes a judgment | Native persistent scheduler, per-job model and tool settings, isolated sessions, delivery to Telegram, failure notifications, a background-task ledger |
| **n8n** | Scheduled work whose substance is authenticating to an outside service and moving data | Already running, already holds credentials, already proved on `UC1 - Cycling Day Rating` |
| **Task Scheduler + PowerShell** | The deterministic local jobs already built | Caddy and infra-watch work. Nothing here refactors them |

**The routing rule, in one question each, in order:**

1. **Is it already running on Task Scheduler?** Leave it. This project does
   not migrate working things.
2. **Is the substance of the step authenticating to an outside service and
   moving its data?** n8n.
3. **Does a model make a judgment in this step?** OpenClaw.
4. **Neither?** A plain script, run by whichever of the three already owns
   that project's schedule.

**This extends `PRINCIPLES.md`'s "route on verifiability" rather than
replacing it.** That rule picks *which model* handles a step. This one picks
*which runner* invokes it. They are answered in that order: pick the runner,
then pick the model inside it.

**The corollary that matters most: one job may use two runners.** n8n
collects and lands a file on disk; OpenClaw reads that file, judges it, and
writes the result. Every candidate project in §8 has that shape. Designing a
job as a single runner's problem is usually a sign the routing question was
skipped.

### What this resolves for free

v0.5 §7 predicted the second project would force a shared-library decision,
because it would need `invoke-model.ps1` and `post-discord.ps1`, and the
rule of two would then demand extraction.

**It doesn't, and the reason is worth writing down.** OpenClaw calls models
and posts to Telegram natively. New work does not copy those two scripts, so
no second copy exists and the rule of two never fires. The predicted
extraction is cancelled, not deferred.

**One piece of `invoke-model.ps1` may still be worth keeping: per-call spend
logging.** Whether OpenClaw reports per-job cost in a form that can be summed
against a weekly cap is **[VERIFY — Phase 1]**. If it does not, that logging
is the one thing to carry across, and it is the only thing.

## 5. Guardrails

Four of these already exist and are inherited. Two are new because the
runner changed.

| Guardrail | Status |
|---|---|
| **Disk is the source of truth** | Inherited, unchanged. Every job writes its result to a file in its project folder *before* it posts anywhere. OpenClaw's own session store, Telegram, Discord and Notion are all mirrors |
| **A model never grades its own output** | Inherited, unchanged. The `check` is a script, or a separate model call with no shared history |
| **Scope** | Inherited. Each job declares the exact paths it may write to; a write outside is a hard stop |
| **Budget** | Inherited in shape — dollars and wall-clock per job — but the enforcement point moves from `invoke-model.ps1` into OpenClaw. **[VERIFY — Phase 1]** |
| **The approval gate** | **New problem. See §6** |
| **The stop rule** | **New answer. See §7** |

## 6. The approval gate is the main risk, and it is a configuration problem

`openclaw.json` currently sets `tools.exec.ask: "always"` — every real-world
action pauses for a Telegram approval. That is the right setting for a
supervised assistant and **it is fatal to an overnight run**: a job started
at 1am waits until Matt wakes up, having burned its wall-clock budget doing
nothing.

**The fix is per-job tool scope, not turning the gate off.** A job whose
writes are confined to its declared `scope` paths runs without asking.
Anything outside that — a network call the job didn't declare, a write to
another project's folder, a git push — still asks, and if nobody answers,
the run stops and reports rather than proceeding.

**This is the single most consequential change in Phase 1**, and it is the
one to be slowest about. The honest risk from v0.5 §5 is unchanged in kind
and larger in blast radius: an agent that keeps going after it is confused
turns overnight progress into several sittings of untangling. Widening what
runs without asking is what makes that possible.

**Also note:** both local models are currently denied the `web` and
`browser` tool groups. Under §4's routing rule that is mostly correct —
fetching from outside services is n8n's job — but it means an OpenClaw job
cannot go look something up mid-run. Anything a job needs from the internet
has to be on disk before the job starts, which is the same discipline as the
task-file contract's `inputs` field.

## 7. The stop rule — settled

**Five consecutive no-progress attempts, then a hard stop.** Matt's leaning
of 2026-09-04, filed here as a decision, which unblocks v0.5 §5.

Stated so it is decidable by inspection, per `PRINCIPLES.md`:

- **An attempt** is one full execution of the job's work followed by one run
  of its `check`.
- **No progress** means no check that was failing at the start of the attempt
  is passing at the end of it. A job with several checks makes progress if
  *any one* of them flips fail → pass.
- **Attempts 1–2** run on the local model. If attempt 2 makes no progress,
  **attempts 3–5 escalate** to the paid model, logged, and counted against
  the budget.
- **After attempt 5 with no progress, the job stops.** Status `stopped`, the
  report is written to disk, one message goes to the decisions channel, and
  it pings.
- **A stopped job does not restart on its next scheduled tick.** It stays
  stopped until Matt clears it.

**That last clause is not decoration.** Without it a nightly schedule simply
restarts the same doom loop every night, and five attempts becomes thirty-five
a week. This is the failure mode the whole stop rule exists to prevent, and
the schedule is what would reintroduce it.

**The threshold has never been exercised on a real unattended run.** Firing
it deliberately is Phase 2's job, not something to discover.

## 8. The phases

### Phase 0 — Graduate the project *(this document)*

Folder exists, plan and `STATE.md` written, roadmap pointer and index
updated. Remaining: a git repo and remote for this folder, a claude.ai
project, and moving `roadmap\planning\dev-environment.md` into this folder
as history so it isn't listed in two lifecycle states at once.

### Phase 1 — OpenClaw 2.0 configuration reset

`docker-compose.yml` pins `openclaw/openclaw:2026.9.3`, the current release,
edited 2026-09-09. **`openclaw.json` has not been touched since 2026-07-17** —
it predates 2.0's setup flow, memory system, skills unification and plugin
management entirely. It is also the config Matt suspected was left in a bad
state by a Gemini-guided install.

**Exit condition:** a config Matt can explain line by line, committed to the
new repo, with the previous one kept beside it.

#### Findings, 2026-09-11 — read from disk and from OpenClaw's own docs

**An upgrade is already mid-flight and nobody finished it.**
`C:\automation\openclaw\backups\openclaw-2026.7.1-20260909.tgz` (19.5MB) was
written 2026-09-09 — the same day `docker-compose.yml` was edited to pin
`2026.9.3`. Someone already started this exact reset, took a safety backup of
the pre-upgrade state, and stopped before touching `openclaw.json`. That
backup is good news — don't delete it — but it means the container has been
running the 2.0 image against a 1.x-era config for two days.

**There are two unapplied config drafts, not one, and they disagree with each
other and with the live file.** `config-staging.json` (last touched
2026-07-16, a day before the live file) is a *different* draft that adds a
Discord channel (`channels.discord`, plus a Discord ID in
`commands.ownerAllowFrom`) and switches `gateway.bind` from `loopback` to
`lan`. Neither change is in the live `openclaw.json` file — though, per the
Round 2 findings below, Discord turned out to already be live anyway,
through whatever actually manages runtime channel state. **Superseded by
Matt's decision, 2026-09-11: see the Discord/Telegram entry in §3 — this
draft's channel direction turned out to be the one that stuck, even though
the file itself was never applied.**

**The exec approval gate cannot be scoped by file path or by scope list —
correction to §6.** §6 as written assumed a job could run without asking as
long as its writes stayed inside a declared `scope`. OpenClaw's own docs say
otherwise: `tools.exec` approval is enforced **per agent** (each entry under
an `agents` map gets its own allowlist and `security`/`ask` policy), not per
path, and an automation "cannot use a more permissive policy than its owning
agent is configured with — approvals can only tighten, never loosen." The
usable version of §6's idea is: **a second, separate agent identity for
automations**, with its own allowlist of specific approved command patterns
and `ask: "on-miss"`, left running alongside the interactive agent's
unchanged `ask: "always"`. An automation still cannot invent new permissions
at runtime — it can only replay commands that already matched something on
its agent's allowlist once.

**That allowlist config's exact file and schema is not confirmed.** The
example in OpenClaw's exec-approvals doc (`version`, `defaults`, `agents` as
top-level siblings) does not match `openclaw.json`'s own shape, which nests
`tools.exec` under `tools` and has no top-level `agents.<id>` map today —
only `agents.defaults`. This is most likely a separate file OpenClaw itself
manages, but a doc-summary excerpt is a proxy for the real schema, not the
fact of it, per this repo's own `PRINCIPLES.md`. **This is Phase 1's first
real task for whoever has a working shell** — see the handoff doc.

**Automation retry/backoff is real but doesn't do what §7 needs.** Recurring
jobs get escalating backoff on consecutive *execution* errors (30s → 60s →
5m → 15m → 60m), resetting to zero on the next success. There is no
documented cap that permanently disables a job after N failures, and no
documented budget or wall-clock field on a job. **This confirms, rather than
leaves open, what §7 already assumed as a fallback: the five-attempt hard
stop and the "don't restart on the next tick" rule have to be implemented in
the job's own check script and a small state file, because OpenClaw's
scheduler will otherwise happily back off and retry forever.**

**Secrets: 2.0's actual credential-lockdown mechanism is `SecretRef`s, and
nothing is using them yet.** Plaintext in `openclaw.json` and `.env` stays
fully readable by the agent until migrated. The migration path is
`secrets audit` → `secrets configure` → `secrets apply`, all CLI commands —
another Phase 1 shell task, not a config-file edit.

**Memory search has a trap.** Enabling `agents.defaults.memorySearch`
without also setting `memory.search.provider` defaults to **OpenAI cloud
embeddings** — an unbudgeted paid cloud dependency outside the
Claude/Gemini-only preference. Leaving it disabled (current setting) is the
correct default for now; turning it on later requires setting
`provider: "local"` or `"ollama"` in the same change, never on its own.

**The network setup predates 2.0's documented pattern, on both drafts.**
Live `docker-compose.yml` maps the gateway port directly onto the Tailscale
interface IP (`100.115.99.39:18789:18789`) — plain HTTP over the tailnet.
`config-staging.json`'s `bind: "lan"` is explicitly the pattern OpenClaw's
own docs caution against. The documented recommendation for a home server on
Tailscale is `bind: "loopback"` plus `gateway.tailscale.mode: "serve"`, which
keeps the port off the network entirely and lets Tailscale terminate HTTPS.
**Not folded into this pass** — it changes the URL Matt uses to reach the
control UI, and that's worth doing deliberately in its own change once
Phase 1's approval-gate work is verified working, not bundled in.

**What this means for who does what:** the remaining Phase 1 work —
confirming the real approval-allowlist file, running the secrets migration,
and applying the reviewed config — all need a shell against the live
container. That's the handoff in `PHASE1-findings-and-next-steps.md`,
written for whichever tool Matt is running with real access (Claude Code or
otherwise).

#### Round 2 — Claude Code's live-system check, 2026-09-11

**This document itself didn't sync correctly, and it's the same class of bug
`CLAUDE.md` already names.** The findings above were committed to disk after
being written, but the write silently reverted to the pre-edit version — the
committing tool reported success, the byte count on disk briefly matched the
new content, and some time later the file on disk was back to the old
version. Re-committed and verified by an immediate re-read, not just a
success response, which is now the standing practice for every write this
project makes to this device. Cause unconfirmed — possibly the same
unreliability as the `device_bash` mount failure, on the same bridge.

**The core Phase 1 problem may be smaller than assumed.** Claude Code
queried the live approval policy directly (not the JSON file) and found the
`main` agent already running `ask: "on-miss"` with one command on a
standing allowlist, last used 49 days ago — not the blanket `ask: "always"`
`openclaw.json` shows. The JSON file's `tools.exec.ask` value is most likely
a bootstrap default rather than the live setting once any approval has ever
been granted. This doesn't close the gap — only one command is allowlisted,
everything else on `main` still prompts — but it means the interactive agent
was never as blocking as the plan's §6 assumed, and it's independent
corroboration that the per-agent-allowlist design in §6's correction is
exactly how OpenClaw already behaves in practice, not just in the docs.

**openclaw.json is very likely a bootstrap/import artifact, not the live
config, for anything CLI-managed.** Three findings point the same way: (1)
exec approvals are queried and set through `openclaw agents` / `approvals` /
`exec-policy` commands against an internal store, not this file; (2) the
live channel state (next finding) contradicts what the file says; (3) the
file's mtime updates on container operations without its content changing.
**Working theory, not yet confirmed: editing `openclaw.json` and restarting
may have no effect at all on channels, exec policy, or agent identities —
those may need to be set through the CLI directly, the way the `automation`
agent identity already was.** Task 3 in the handoff doc assumed a JSON edit
was the mechanism; that assumption needs to be checked before anyone acts on
it further.

**Discord, not Telegram, is the live front door — the opposite of what both
this plan and Matt's own stated history assumed.** The live config has
Telegram configured but `enabled: false`, and Discord `enabled: true` with
exec approvals actually routed through it to Matt's Discord ID. This
contradicts Matt's own prior decision (consolidating the approval channel
onto Telegram) closely enough that it isn't a call to make on his behalf —
see the question put to him alongside this update.

**Secrets audit flagged one of four plaintext secrets, not the one
expected.** `.env` holds four plaintext values (gateway password, Ollama key,
Telegram bot token, Discord bot token); `secrets audit` flagged only
`OLLAMA_API_KEY`. Likely reading of why, not confirmed: SecretRefs exist to
keep a value out of *agent/model* context specifically — per OpenClaw's own
docs, materialization happens only for credentials "actively used in tool
calls." The other three are gateway- and channel-level credentials the
process needs at boot, before any agent session exists, and never surface in
a tool call the model constructs — so the audit not flagging them is
plausibly correct behavior, not an incomplete audit. Recommendation: accept
the audit's own scope rather than forcing all four into SecretRefs.

**Progress already made, independent of the above:** a new `automation`
agent identity exists — empty allowlist, no channel bindings, `ask:
on-miss`, `main` untouched. That was §6's actual goal and it's done. It has
nothing to run yet; Phase 2 is what will populate its allowlist.

#### Phase 1 close-out, 2026-09-11 — Claude Code, with real shell and Docker access

**The disconnected-config theory is now a confirmed fact, not a theory.**
`docker-compose.yml` mounts a named Docker volume (`openclaw_data`) at
`/home/node/.openclaw` — not a bind mount to the host `openclaw.json`. A
direct diff between the host file and the live in-container config showed
410 of roughly 460 lines different. **Editing the host file and restarting
would have done nothing.** Every live change from here on goes through the
CLI against the running container — `openclaw config get/set/patch` — not
through that file. Treat the host `openclaw.json` as historical.

**Secrets migration done, one detail needs a direct look before calling it
closed.** `secrets configure`'s interactive wizard needs a real TTY, which a
scripted shell call can't safely drive without risking a mis-mapped prompt —
correctly declined to guess at it. Used the CLI's non-interactive path
instead: registered an `env`-sourced provider, then set
`models.providers.ollama.apiKey` to a `SecretRef` pointing at it. Validated
with `--dry-run` before applying, confirmed a hot reload with no restart and
no errors in the logs. Matches the decision exactly — only `OLLAMA_API_KEY`,
nothing else touched.

**Not yet accepted at face value:** `secrets audit` still reports
`OLLAMA_API_KEY` as `PLAINTEXT_FOUND` (severity `warn`) after the fix.
Claude Code's read is that this is inherent to the `env` source type — the
value has to physically sit in `.env` for an env-var reference to resolve —
and isn't a sign the migration failed. That's plausible, but it's also
exactly the kind of explanation to verify rather than accept, per this
project's own rule that a model doesn't grade its own output. **Next task,
before Phase 1 is actually marked done: pull the live value of
`models.providers.ollama.apiKey` directly and confirm it holds a reference
object, not the raw key string.** If it's a reference, the audit warning is
noise about the source type, as claimed, and Phase 1 closes clean. If it's
still the raw string, the `config set` didn't take and needs redoing.

**Everything else closed cleanly:** the `automation` agent identity was
reconfirmed live and correct. No live-facing doc anywhere in this project
incorrectly assumes Telegram — checked, not just assumed.

**Phase 0 has an answer now.** Matt supplied the GitHub remote:
`github.com/elasticbrainMB/dev-environment`. No repo exists in the folder
yet. See the handoff doc for the git setup, alongside the one open
verification above.

### Phase 2 — The proving ground

A deliberately trivial recurring job, built to be thrown away, that exercises
every part of the runner exactly once.

**The job:** read a small text file in `dev-environment\proving-ground\`,
have the local model produce a one-line summary, write it to a dated file in
that folder, and run a check script that verifies the output exists, is
non-empty, is under a word count, and contains a required token. Post one
line to Telegram.

**What it proves, in order:** the schedule fires unattended → the local model
is reachable and answers → a write inside `scope` happens without an approval
prompt → the check script runs and its result is recorded → the result
reaches Telegram → a failure notifies rather than going silent.

**Then break it on purpose.** Change the input so the check cannot pass.
Confirm: two local attempts, escalation to the paid model on attempts 3–5,
a hard stop at five, a report on disk, a ping to the decisions channel, and
**no restart on the next tick.**

**Exit condition:** both the passing run and the deliberate failure observed
end to end, and the actual spend of the failure run known in dollars.

### Phase 3 — Choose the first real project, on evidence

Deferred by decision. What Phase 2 will have told us:

| If Phase 2 showed | Then favour |
|---|---|
| Local models handle a small judgment well, escalation rarely fires | The newsletter reporting project — its value is in the judgment layer |
| Local judgment is weak and escalation fires often | A collection-heavy project where the model's role is small |
| The approval gate is still forcing prompts on ordinary work | Stop and fix §6 before any real project |

**The two candidates Matt named, assessed honestly:**

**Newsletter health reporting** — Google Analytics, Search Console, Tag
Manager and beehiiv into one view. Splits cleanly across two runners: n8n
collects on a schedule, OpenClaw judges and writes. Its data-collection half
is fully script-checkable (row counts, date ranges, totals reconciling
against each source), and only the commentary half needs the evaluate →
iterate → edit loop, which is the artifact Matt says the overnight window is
for. It feeds `CONTEXT.md`'s stated reason the roadmap is documented at all.
**Gating unknown: whether Matt's beehiiv plan tier includes API access.** The
public developer docs describe the analytics endpoints but do not state plan
eligibility — a five-minute check in beehiiv settings.

**Bike construction flagging** — Strava or Garmin routes cross-referenced
against construction data. **The blocker is data, not runner.** Minnesota's
511 feed is strong on state highways and weak on the county and neighborhood
roads Matt actually rides; MnDOT commissioned a research report specifically
on how inconsistently local road and bridge closures get reported. Strava's
API is self-serve and will say which roads he rides; Garmin's is
partner-gated. So the "which roads" half is easy and the "which are closed"
half may have no reliable source at all.

Its shape is also a concern: fetch, score, notify — the same shape as
`UC1 - Cycling Day Rating`, which is already Done. A queued agentic runner
tested on a job with almost no agent in it proves little, which is the
argument v0.2 got right about that same workflow.

**Leaning, not a decision:** newsletter reporting first, scoped so the first
thing that ships is the boring checkable collection half. Bike construction
becomes the second queued package once the runner is proved — by which point
the data question can be answered on its own merits instead of blocking the
foundation.

## 9. Carried items

| Item | State |
|---|---|
| **Sync-discipline mechanism** | v0.5 open question 5, now **answered: it needs a mechanism.** Three slips in seven days. Candidate: a scheduled OpenClaw job that reads `roadmap\STATE.md` and every `projects\*.md`, and reports rows whose status disagrees or whose `last_synced` is stale. It is a good Phase 3 candidate in its own right — small, checkable, and it fixes a problem this repo has demonstrably got |
| **Where the queue lives** | v0.5 open question 4, **partly dissolved.** OpenClaw persists its own jobs, so there is no queue folder to place. What remains is where a job's *spec* lives — proposed: in the project it drives, since that is where its `check` script and `scope` paths already are |
| **The task-file contract** | `planning\task-file-format.md` survives as a **contract**, not a runner. Its useful half is the field set — `goal`, `check`, `inputs`, `scope`, `budget_dollars`, `budget_minutes`, `stop_conditions`, `decision_list`. Its Task Scheduler assumptions, and its §5 worry about a script editing its own trigger file, are obsolete |
| **A backup that is exercised** | Unchanged from v0.5. 33 caddy commits sat unpushed for two weeks. Still a candidate `PRINCIPLES.md` entry, and it applies immediately to this folder's new repo |
| **Kilo / a model-agnostic agent** | Unchanged. Never tested. Weaker still now that OpenClaw selects a model per job |
| **`owned_tables` cross-check** | Unchanged. Caddy's, not this project's |

## 10. Open questions

1. **Does OpenClaw enforce budgets and retries, or must the job's own check
   script?** Phase 1 answers it. §7 is written to work either way, but where
   the counting lives changes what a job spec has to carry.
2. **Does Matt's beehiiv plan include API access?** Gates the leading Phase 3
   candidate. Not answerable from the public docs.
3. **What the two work windows actually are.** Proposed: overnight 23:00–06:00
   CT for heavy local model work while the GPU is free, and 09:00–16:00 CT for
   lighter collection and checks, when a Telegram approval can be answered
   within an hour or two. Includes a scheduled model warm-up before the
   overnight window. **Not confirmed with Matt.**
4. ~~Whether Discord stays.~~ **Resolved 2026-09-11 — Discord, everywhere.**
   Turned out moot: OpenClaw's actual live channel was already Discord, not
   Telegram as assumed when this question was written. One channel across
   caddy, infra-watch, and OpenClaw now, not two.
5. **The claude.ai project for this folder.** Matt is moving off Claude as the
   front door, but Claude stays for planning. Whether that still warrants a
   dedicated project, or whether planning happens in the roadmap project, is
   unresolved.

## 11. Sources for the OpenClaw claims

Read 2026-09-10. Claims about Matt's own install were read from
`C:\automation\openclaw`.

- Release notes, v2026.8.1 ("OpenClaw 2.0") and the release index confirming
  v2026.9.3 as current — `docs.openclaw.ai/releases`
- Automations: scheduler, cron and one-shot rules, webhook and event
  triggers, payload and delivery options, failure notification —
  `docs.openclaw.ai/automation/cron-jobs` and `docs.openclaw.ai/automation`
- Heartbeat, background-task ledger, hooks and standing orders —
  `docs.openclaw.ai/automation`
- 2.0 feature summary (setup, memory, skills unification, plugin management,
  credential handling) — InfoQ, 2026-09

**Not found in the public documentation, and therefore unverified:** budget
or spend caps per job, retry policy, and per-job cost reporting. All three
are Phase 1 questions.
