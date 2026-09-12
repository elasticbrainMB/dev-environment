# Scoring rubric — job-listing fit

**Source:** the live prompt of the Cowork scheduled task `daily-job-search-2026-v2`
("Daily job search 2026 v2"), pasted in by Matt on 2026-09-12. Task frontmatter
at the time: `v7 — Browser-only half of the two-system pipeline: LinkedIn
rendered scan (past 24h) + ATS discovery verified via board JSON APIs (seeds
the ATS Watchlist); role-type exclusions, seniority rules, and canonical fit-score
rubric (10 = auto-resume trigger); POSTs jobs+watchlist with fit_score/selected_resume
to Apps Script webhook; chat summary includes Interested-rows-awaiting-resume.`

**Extracted verbatim, not cleaned up or improved** — Matt's explicit instruction.
What's below is copied exactly from the live prompt: the criteria that decide a
job's fit (core principle, exclusions, seniority, the fit-score rubric itself,
and the resume-variant assignment). Left out on purpose, as out of scope for
scoring rather than as an edit: the LinkedIn/ATS *discovery* mechanics, the
webhook POST mechanics, and the chat-summary format — those are collection and
write-path concerns Phase 3 isn't taking over, and the POST section also names
the live webhook URL, which this repo's credential rule keeps out of every
file. **That's a scope decision made in extracting this file, not a change to
the rubric text itself — flag it if the boundary should sit somewhere else.**
Matt reviews and edits this file before anything scores against it.

---

## CORE PRINCIPLE: only post roles that are CURRENTLY OPEN
A short list of verified-open roles is the goal; a long list padded with dead links is a failure. Discovery results are candidates, not confirmed-open jobs, until verified as described per source.

## EXCLUSIONS — never include these companies or any subsidiary/portfolio company
- Target Corporation (incl. Target Brands, Shipt, etc.)
- UnitedHealth Group (incl. Optum, UnitedHealthcare, OptumRx, OptumHealth, OptumInsight, Change Healthcare, Naviguard, Rally Health, Navihealth, Genoptix, etc.)
Skip any result from these orgs regardless of fit.

## ROLE-TYPE EXCLUSIONS — drop these regardless of company, freshness, or apparent fit
Matt's experience is specialized in digital marketing, marketing operations / MarTech, SEO / AI search, AI adoption / enablement, and marketing project / program management. Roles outside that specialization are dealbreakers — do NOT verify or post them:
- Lifecycle Marketing / CRM / retention-lifecycle roles — Matt has no lifecycle experience.
- Product Marketing / PMM roles — Matt has no product-marketing experience.
- Generalist marketing leadership WITHOUT a clear digital / ops / SEO / MarTech / AI / project-or-program-management focus — e.g. plain "Marketing Director", "VP Marketing", "Head of Marketing", "Director of Marketing & Communications", or brand/comms marketing.
Keep a role ONLY if its core responsibility is clearly digital marketing, marketing operations / MarTech, SEO / AI search, AI adoption / enablement (incl. Chief of Staff, AI), or marketing project / program management (marketing PMO, campaign or creative operations project management, program management of marketing initiatives). When a title is ambiguous, judge by the role's actual focus in the job description, not the keyword in the title.

SENIORITY: For every variant EXCEPT marketing project / program management, keep director-level and above — drop IC/manager roles well below director unless a strong AI-adoption fit. For marketing project / program management specifically, keep Manager level and above; do NOT drop those for being manager-level.

## FIT SCORE RUBRIC (canonical — one source of truth with SCORING-RUBRIC.md in the project folder and the n8n Gemini prompt)
Assign every job you post a fit_score from 1-10. A 10 triggers automatic resume generation with no human review, so 10 means "drop everything, would regret missing." Grade skeptically; when torn between two scores, give the lower. "Exempted from the bar" reasoning is forbidden.

Score 10 ONLY if ALL of these pass:
1. SENIORITY - Director level or above by title or clear scope. A Manager-titled role qualifies ONLY if its responsibilities read Director-caliber (owns strategy/budget/function, not just execution) AND its listed salary is $140,000+. Manager-titled roles with unlisted salary cap at 9.
2. LOCATION - Fully remote US with no geographic or time-zone restriction that excludes Minnesota, OR Twin Cities metro (hybrid or on-site there is fine).
3. DOMAIN - Core responsibility is an exact match to one resume variant: digital marketing leadership, marketing operations / MarTech, SEO / AI search, AI adoption / enablement, or marketing project / program management. Adjacent or stretch fits cap at 9.
4. COMPENSATION - If a salary is listed, it is $140,000+ (or clear full-time equivalent, e.g. $70+/hour). Unlisted salary does not block a 10, EXCEPT for Manager-titled roles (rule 1).
5. CLEAN - Passes every company and role-type exclusion above; posting verified currently open.

Anchors: 10 = exceptional, expect 0-2 per day and many days zero. 9 = strong, interview-worthy, one soft criterion off (soft = slight domain blend, unlisted comp on a Manager title, VP-stretch title; hybrid outside Twin Cities is NOT soft — that is a location fail capping at 7). 8 = good with one marginal criterion. 7 = plausible, worth a look (includes otherwise-strong roles that fail location). 6 or below = weak or wrong.

Also set selected_resume for every job: the base resume variant that best matches — one of "Digital", "MarTech", "SEO", "AI", "PM".

---

## Note on provenance, not part of the rubric

The FIT SCORE RUBRIC heading itself says it's "one source of truth with
SCORING-RUBRIC.md in the project folder and the n8n Gemini prompt" — meaning
this same rubric is already meant to be canonical across at least three
places (this Cowork task, a `SCORING-RUBRIC.md` in the job-search pipeline's
own project folder — a different folder than this repo — and n8n's Gemini
scoring prompt). This file is a fourth copy, extracted for Phase 3's use.
Worth deciding, before Phase 3 scores anything for real, whether this file
should be the new canonical source the others point to, or just a local
working copy — that's Matt's call, not assumed here.
