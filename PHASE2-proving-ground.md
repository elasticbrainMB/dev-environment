# PHASE2-proving-ground

**2026-09-11.** Written to minimize check-ins after Phase 0/1 took more
back-and-forth than it should have. This doc gives the goal, the guardrails,
and the one real gap that needs Matt directly. Everything else — exact CLI
syntax, file layout, script language, whether a step needs an approval or is
a native agent tool — is yours to work out with real system access, the same
way Phase 1's best moments worked (checking with `--help` and `--dry-run`
instead of guessing from a doc summary). One report at the end covers this,
not a check-in per step.

Read `PLAN-dev-environment-v1.md` §7 (the stop rule) and §8 Phase 2 first —
this doc is the concrete build against those, updated for what Phase 1
actually found (Discord, not Telegram; CLI-managed config, not
`openclaw.json`).

## Goal

A single throwaway job that proves the runner works end to end, then proves
the stop rule fires correctly when it shouldn't work. Nothing about this job
is meant to be kept — it's scaffolding, delete it once both scenarios are
confirmed.

## What to build

- A folder `dev-environment\proving-ground\` with a small input file — a
  couple of throwaway sentences.
- A recurring job on the `automation` agent identity (the one Phase 1
  created — empty allowlist, `ask: on-miss`), on a short interval. Ten to
  fifteen minutes is enough; this doesn't need to run for days.
- The job's work: read the input, produce a one-line summary with the
  configured local model (`qwen3.5:9b-q8_0`), write it to a dated output
  file in the same folder.
- A check script, following this project's existing convention (PowerShell,
  matching caddy's `verify-*.ps1` pattern), that fails unless the output
  exists, is non-empty, is under a small word count, and contains one
  required token you choose.
- A small state file implementing the stop rule from `PLAN-dev-environment-v1.md`
  §7 exactly: attempts 1–2 on the local model, attempts 3–5 escalate to a
  paid model, hard stop after 5, and — the part OpenClaw's own scheduler
  backoff does *not* do, confirmed in Phase 1 — **a stopped job does not
  restart on its next scheduled tick.** This state file is what enforces
  that.
- Posting to Discord on every run, pass or fail. If the job stops or needs
  Matt, that's a ping, not just a log line — same quiet-channel/pinging-
  channel split caddy and infra-watch already use (§5).

## The one real gap — check before building around it

**No paid model is configured in OpenClaw at all right now** — only the
local `ollama` provider exists. Attempts 3–5 of the stop rule need
somewhere to escalate to, and nothing does yet.

1. **Check `C:\automation\secrets\*.env` first** for an Anthropic or Gemini
   API key already used elsewhere in this ecosystem — this project shares a
   secrets folder with caddy, infra-watch, and roadmap. If one exists,
   reuse it, wired in the same `SecretRef` way `OLLAMA_API_KEY` was in
   Phase 1.
2. **If nothing usable exists, that's the one thing that needs Matt
   directly** — an Anthropic API key, preferred over Gemini per his stated
   preference for this kind of work. Get it from him straight to you, not
   relayed through Cowork chat, and store it the same way.
3. Check whether `config\model-caps.json` (or caddy's equivalent) already
   defines a weekly spend cap worth reusing before inventing a new one —
   `invoke-model.ps1`'s spend-control pattern is the reference, even though
   OpenClaw itself now handles the model call.

**Update, 2026-09-11 — Matt already tried adding OpenRouter, and it's not
showing up.** He added it recently through the OpenClaw web UI's model
picker workflow but doesn't see it listed as a provider. Two things to
check, in order, before doing anything else in this section:

1. **Check `C:\automation\secrets\*.env` for an existing
   `OPENROUTER_API_KEY`** — Matt has used OpenRouter before for GLM (per
   his own history), so a key may already exist and just need reusing
   rather than re-entering.
2. **Confirm live registration with `openclaw config get models.providers`**
   (or the equivalent read command already proven working in Phase 1). If
   OpenRouter isn't in the live list, check whether it was added by editing
   the host `C:\automation\openclaw\openclaw.json` directly — that file is
   confirmed disconnected from the running config (Phase 1 finding), so an
   edit there would explain exactly this symptom: added, but invisible.

If OpenRouter comes up clean with a Claude model available through it, that
likely closes this whole section — no separate Anthropic key needed, and it
matches the stated preference for Claude over other models for this kind of
work.

**Separately, low priority:** while testing the exec-approval flow in the
web UI directly, the local model's own reply suggested setting
`channels.discord.execApprovals.enabled` to `auto`/`true` as the fix for
routing approvals through Discord. That came from qwen3.5 explaining itself,
not from a verified system message — worth a quick check of whether that
config key is real before anyone treats it as fact.

**Resolved, 2026-09-11.** Root cause was neither theory above: OpenClaw has
two separate credential stores — `models accounts` (tied to whoever's
signed into the web UI as a person) and `models auth` (what agents actually
read). The web UI's model picker writes to the first; agents read the
second. Confirmed by the CLI's own error message, not guessed. Fixed with
`openclaw models auth paste-api-key --provider openrouter --agent main`,
using the `OPENROUTER_API_KEY` already sitting in `secrets\caddy.env` and
`secrets\infra-watch.env`. Verified live: `models status` shows a working
credential, `models list --provider openrouter` resolves 438 models, both
`main` and `automation` see it (one shared auth store). **Worth remembering:
this is a third credential mechanism, distinct from both plain `.env` and
the `SecretRef` system Phase 1 used for Ollama** — which store a given
credential belongs in isn't obvious from one consistent rule, it depends on
whether OpenClaw treats it as a model-provider credential or a general tool
secret.

**Two follow-ups before wiring a model into the stop rule, both fine to do
without checking in:**

1. **Confirm nothing from the non-interactive `paste-api-key` call landed
   in shell history or a temp file.** That command is normally interactive;
   getting a key into it without a TTY means it was piped or read from a
   file somewhere in the process — check that path is clean.
2. **Restrict the exposed model list before using it, not after.** 438
   models selectable by an unattended agent is a bigger blast radius than
   intended — the whole reason the `automation` identity has an empty
   allowlist is a tight surface. Give both `main` and `automation` an
   explicit short model list (the way `models.providers.ollama.models`
   already only lists two), not the full OpenRouter catalog.

**Default recommendation for the escalation model: `anthropic/claude-sonnet`
via OpenRouter.** It only ever gets called after two local failures, so cost
matters more than ceiling — sonnet over opus for that role, and it's the
tier Matt already uses day to day, which keeps behavior predictable when
comparing an escalated run's output to what he'd expect. Deviate with a
stated reason if something concrete argues otherwise once real pricing is in
front of you.

**Green light to continue the actual build** — the job, its check script,
and the stop-rule state file, as already spec'd above. One report at the
end.

## What to prove, in order

1. The schedule fires unattended.
2. The local model is reachable and answers.
3. The job's write happens without an approval prompt. This is what the
   `automation` identity and its allowlist exist for — if this still
   prompts, that's a real finding to report, not something to route around.
4. The check script runs and its result lands in the state file.
5. The result reaches Discord.
6. **Then break it on purpose** — edit the input or the check's required
   token so it can never pass — and confirm: two local attempts,
   escalation to paid on attempts 3–5, a hard stop at five, a report
   written to disk, a ping to Discord, and no restart on the next tick.

**Watch step 6 interactively rather than walking away from it.** This is
the first real test of the stop-rule enforcement, and a bug in the state
file's own logic is exactly the failure mode that would burn paid-API spend
in a loop instead of catching itself. That's what this whole phase exists
to catch before anything real depends on it.

## Exit condition

Both the passing run and the deliberate failure observed end to end, and
the actual dollar cost of the failure run known from whatever the paid
provider's own logging gives you. Once both are confirmed, delete the
proving-ground job and its schedule — it did its job.

## How to work

- Investigate real behavior before assuming a shape — `--help`, `--dry-run`,
  actual output. That's what made Phase 1's harder findings solid instead of
  guessed.
- Make routine calls yourself: script language, file names, exact CLI
  flags, whether Discord posting needs its own approval or is a native
  tool. None of that needs Matt.
- Stop and ask only for something with real, hard-to-reverse consequences
  you can't get past on your own — the `git push` block in Phase 1 is the
  right model for when to stop: a harness policy blocked it outright, not
  ordinary uncertainty.
