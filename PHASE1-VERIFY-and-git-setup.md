# PHASE1-VERIFY-and-git-setup

**2026-09-11.** Two small tasks, in order. Read `PLAN-dev-environment-v1.md`'s
"Phase 1 close-out" section first — this is the continuation.

## Task A — verify the secrets fix before calling Phase 1 done

Your own report flagged this as worth a second look, and it is. Pull the
live value directly:

```
openclaw config get models.providers.ollama.apiKey
```

- **If it returns a reference object** (something like
  `{"$secretRef": "env:OLLAMA_API_KEY"}` or whatever the actual shape turns
  out to be) — the migration worked. The `PLAINTEXT_FOUND` audit warning is
  then noise about the source type, exactly as you inferred, and Phase 1 is
  genuinely done. Say so plainly, quote the actual returned value in your
  report, and mark it closed in `STATE.md`.
- **If it still returns the raw key string** — the `config set` didn't
  actually take. Redo it, using the same dry-run-then-apply approach, and
  re-check.

Either way, report the literal command output, not a paraphrase of it — this
is the one place this round where "trust the interpretation" isn't good
enough on its own.

## Task B — Phase 0: initialize the repo

Matt gave the remote: `https://github.com/elasticbrainMB/dev-environment`.

1. Check whether it's actually empty first:
   ```
   git ls-remote https://github.com/elasticbrainMB/dev-environment.git
   ```
   If it returns nothing, it's empty and step 2 is a plain init+push. If it
   returns refs (e.g., an auto-created README), pull first and reconcile —
   don't force-push over something already there.

2. Use the same credential setup the other projects already use — this repo
   follows the same "private repo per project under one scoped PAT" pattern
   as caddy, infra-watch, and roadmap (`roadmap\CLAUDE.md`). Don't set up a
   new credential; reuse what's already configured for those.

3. Before the first commit, add a `.gitignore` that excludes:
   - `.claude/` (your own session state — not project content)
   - `Claude outputs/` (a stray auto-created mirror folder, not source
     content — same pattern was found in the roadmap repo)
   - `_cowork-write-test.md`, if it's still sitting in the folder (a
     leftover diagnostic file from Cowork's side — delete it rather than
     just ignoring it, it has no reason to exist)

4. `git init`, add the remote as `origin`, add and commit everything else
   currently in `C:\automation\dev-environment` — `PLAN-dev-environment-v1.md`,
   `STATE.md`, and every `PHASE1-*.md` file — then push to `main`.

5. **Move the superseded planning document, per this repo's own lifecycle
   rule** (nothing sits in two states at once — `roadmap\CLAUDE.md`): copy
   `C:\automation\roadmap\planning\dev-environment.md` (the v0.5 document
   this whole project superseded) into this new repo, e.g. as
   `history/dev-environment-planning-v0.5.md`, commit it, then delete the
   original from the roadmap repo and commit *that* removal there too — two
   separate commits in two separate repos, both part of the same piece of
   work. `roadmap\STATE.md` and `roadmap\projects\dev-environment.md` are
   already updated to point here; nothing else in the roadmap repo needs to
   change for this move.

6. Update this project's own `STATE.md` — add the repo URL under "Where
   things are," and note both tasks closed.

## After this

Phase 0 and Phase 1 are both done once these two tasks are confirmed. Phase
2 — the throwaway proving-ground job — is next, and it's a good candidate
for its own fresh sitting rather than tacking onto this one.
