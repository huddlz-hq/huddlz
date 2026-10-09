# Post-login landing: POC spec and handoff

**Tracking issue:** [#670](https://github.com/huddlz-hq/huddlz/issues/670) — "Post-login
experience usually isn't helpful for RSVPing to a huddl". Supersedes #669.

**Status:** Open for POCs. No approach chosen.

**What this document is.** Issue #670 asks for several competing proofs of concept, each as
its own draft PR, so one can be chosen and the rest declined. This document is the shared
brief those PRs are built from: the problem, what already exists in the code, one section per
POC variant with its own task list, and the comparison rubric they will all be judged against.

**For the agent picking this up.** Read "How to use this document" below before starting. You
are expected to edit this file as part of your PR.

---

## How to use this document

1. Pick one POC variant from the table in [POC variants](#poc-variants). Take the first one
   whose status is `Not started` unless the human directs you elsewhere.
2. Read [Shared context](#shared-context) and [Shared constraints](#shared-constraints). The
   `return_to` plumbing in particular already exists — do not rebuild it.
3. Work the variant's task list in order. Each list is written outside-in per `AGENTS.md`:
   the Cucumber scenario comes first and fails before any implementation.
4. Update this document in the same PR:
   - Set the variant's **Status** in the variants table (`Not started` → `In progress` →
     `PR open #N` → `Chosen` / `Declined`).
   - Tick the variant's task checkboxes as you complete them.
   - Fill in the variant's **Findings** subsection: measured click count, what surprised you,
     what you'd cut. This is the actual deliverable — the rubric is scored from it.
5. Open the PR as a **draft** with `Part of #670` in the body, and add it to the POCs
   checklist on the issue.

Variants are deliberately overlapping. Building something twice is accepted overhead; see
[Overlap is expected](#overlap-is-expected).

---

## Shared context

### The problem, restated

A person arrives from outside the app — a Google result, a QR code on a flyer, a link a
friend sent — with one specific huddl in mind. They hit sign-in. After signing in they land
on `/agenda`, which shows only huddlz they have *already* RSVP'd to. The huddl they came for
is, by definition, not there.

Everything else in #670 is a symptom of that one gap:

- Seeing the group's huddlz takes a second click to `/agenda?scope=groups`, and the chip is
  easy to forget.
- Huddlz outside the person's groups need a third surface, `/discover`.
- `/discover` is the more useful page here but feels more cluttered than the agenda.

### What the code does today

Verified against `main` at the time of writing. Line numbers will drift; the modules won't.

| Concern | Where | Behavior |
| --- | --- | --- |
| Post-auth redirect | `lib/huddlz_web/controllers/auth_controller.ex` (`success/4`, `return_to/1`) | Redirects to `params["return_to"]`, else `session[:return_to]`, else `/`. |
| `return_to` safety | `lib/huddlz_web/auth_return_to.ex` | `validate/1` accepts local paths only; rejects `//`, backslashes, encoded separators. |
| `return_to` carried through auth UI | `live/auth_live/sign_in.ex`, `register.ex`, `components.ex` | Read from params, kept in a hidden field across the password and magic-link forms, preserved across the sign-in ↔ register links. |
| Only producer of a `return_to` link | `live/huddl_live/show.ex` (`rsvp_sign_in_path/2`) | The huddl page's RSVP button, when signed out, links to `/sign-in?return_to=/groups/:slug/huddlz/:id`. |
| `/` for signed-in users | `live/landing_live.ex`, `live_user_auth.ex` (`:redirect_to_me_if_authenticated`) | Redirects to `/agenda`. |
| Agenda scope | `live/calendar_live.ex` (`parse_scope/1`, `handle_params/3`) | `?scope=groups` widens from own RSVPs to everything the person's groups have scheduled. Entirely URL state — nothing persisted. Both scopes are loaded every render (`own`, `everything`) to compute chip counts. |
| Discover | `live/huddl_live.ex` | `/discover`, async combined search over huddlz and groups. Filters: `q`, `event_type`, `date_filter` (default `upcoming`), location + distance. Defaults a signed-in person's location to their home search location. |
| A user-level preference | `lib/huddlz/accounts/user.ex` (`theme_preference` attribute + `:update_theme_preference` action + its policy) | The precedent to copy for any new "where do I land" setting. |

### The three facts that should shape your POC

1. **`return_to` is already built.** The mechanism is complete and safe. What's missing is
   *coverage*: only the huddl page's RSVP button produces a `return_to` link. A person who
   lands on a huddl page and clicks "Sign in" in the global header
   (`components/layouts.ex`, a bare `~p"/sign-in"`) loses their intent. This makes variant
   **A** much smaller than #670 implies, and makes it a strong baseline every other variant
   should be compared against.
2. **The agenda already loads both scopes.** `handle_params/3` computes `own` and
   `everything` on every render regardless of scope, because the chips show counts for both.
   A variant that changes the default scope is a one-line change to `parse_scope/1` plus
   wherever the default is sourced — not a data-loading change.
3. **The agenda has no concept of "huddlz outside my groups."** `load_entries/2` and
   `load_group_extras/4` are both scoped to the person's groups. Variant **C** needs a
   genuinely new query path; it is the largest variant by a wide margin.

---

## Shared constraints

These apply to every POC. A POC that violates one isn't comparable with the others.

- **Terminology.** "huddl" / "huddlz", lowercase, always. Never "event" or "events". See
  `AGENTS.md`.
- **Outside-in BDD.** One Cucumber scenario per behavior, in `test/features/`, driven through
  a public user interface, asserting observable outcomes in domain language. Scenarios must
  not assert markup, classes, or layout. Demonstrate the scenario failing before implementing.
  Cucumber scenarios are the pre-agreed test seam for this repo — proceed without
  reconfirming.
- **No new redirect loops.** `/` already redirects signed-in users to `/agenda`. Anything that
  changes the landing destination must be checked against that hop.
- **`return_to` goes through `AuthReturnTo.validate/1`.** Never trust a path from params or
  session without it. Open-redirect regressions are the one hard failure mode in this area.
- **Phoenix 1.8 conventions.** Templates open with `<Layouts.app flash={@flash} ...>`; pass
  `current_scope`; use `<.input>` and `<.icon>`.
- **Validation via Ash, not HTML5.** Any new setting uses `allow_nil?`/constraints on the
  resource, not a `required` attribute.
- **Production-quality UI.** A POC here is meant to be *felt*, not squinted at: follow the
  UI/UX guidelines in `AGENTS.md` — polished responsive layout, clean typography and spacing,
  subtle micro-interactions, hover and loading states. A variant that looks unfinished will
  lose the Desirable and Delightful criteria for reasons that have nothing to do with its idea,
  which would make the comparison worthless.
- **Scope discipline.** Polish the surface your variant changes; leave everything else alone.
  Do not refactor adjacent code, do not restyle surfaces you aren't changing, and do not
  bundle two variants into one PR.
- **`mix precommit` passes** before the PR goes up.

### Terminology this work will need

None of these are in `GLOSSARY.md` yet. Pick language in your POC, then — if your variant is
chosen — the glossary gets the winning term via `/domain-modeling`. Flag in your Findings
which term you used.

- The post-sign-in destination (candidates: *landing*, *home*, *post-sign-in destination*).
- The remembered pre-auth intent (candidates: *return destination*, *arrival intent*).
- Variant C's "upcoming huddlz near me, outside my groups" slice.

### Overlap is expected

#670 says explicitly: *"it is okay if the same thing gets built twice due to overhead as one
will win and the others will be declined."* So:

- Do **not** coordinate with other POC branches or wait on them.
- Do **not** extract shared helpers across variants. Duplicate freely inside your own branch.
- Branch from `main`, never from another POC branch.
- If your variant needs something another variant also needs (both A and E touch the
  sign-in link, for instance), build your own copy.

Combination is a decision for *after* the comparison. #670 notes A + B + C may cover most
cases. Variant F exists to test that explicitly, and is the only variant permitted to depend
on the others.

---

## POC variants

| ID | Variant | Issue proposal | Size | Status | PR |
| --- | --- | --- | --- | --- | --- |
| A | Return to origin | 1 | S | Not started | — |
| B | Better default landing | 2 | S–M | Not started | — |
| C | Discover inside the agenda | 3 | L | Not started | — |
| D | Prominent search on the agenda | 4 | M | Not started | — |
| E | Intent-based login flow | 5 | M | Not started | — |
| F | Adaptive nudge | 6 | M–L | In progress | — |
| G | Combination: A + B + C | "these can be combined" | L | Not started | — |

Size is relative effort, not priority.

---

### A — Return to origin

**Hypothesis.** The problem mostly isn't the landing page; it's that intent is dropped. If
every sign-in entry point from a huddl or group page carries `return_to`, the person lands
back on the huddl they came for and the landing page stops mattering for this journey.

**Why this is the baseline.** The plumbing exists and is already safe. If A alone gets the
click count to target, the other variants are solving a problem that only affects people who
arrive *without* a specific huddl in mind — a different, smaller problem.

**Scope.** Extend `return_to` coverage to every sign-in entry point reachable from a huddl or
group page — notably the global header's bare `~p"/sign-in"` in `components/layouts.ex`.
Decide and document whether the *session* should capture the current path on an unauthenticated
page view (a plug) or whether link-level coverage is enough. Link-level is the smaller diff;
session capture covers more paths but risks stale destinations.

**Open questions to answer in Findings.**
- Link-level coverage, session capture, or both?
- Does the QR-code / `?from=` path interact with this? `JoinSourceTag` already redirects
  `/groups/:slug?from=...` to a clean address — does `return_to` survive that hop?
- What happens on *register* (not sign-in) from a huddl page, where email confirmation
  intervenes? `ConfirmationDestination` exists for this; verify it covers the case.

**Tasks**
- [ ] Write a Cucumber scenario: a signed-out person on a huddl page signs in via the global
      header and lands back on that huddl page. Demonstrate it failing.
- [ ] Write a scenario for the same journey starting from a group page.
- [ ] Write a scenario for the register-then-confirm path from a huddl page.
- [ ] Audit every sign-in and register entry point reachable from huddl and group pages; list
      them in Findings with current `return_to` behavior.
- [ ] Make the header sign-in link carry the current path as `return_to`.
- [ ] Cover the remaining entry points found in the audit.
- [ ] Verify `AuthReturnTo.validate/1` guards every new path; add a unit test for any new
      input shape (encoded separators, protocol-relative, cross-host).
- [ ] Confirm no interaction bug with `JoinSourceTag`'s redirect.
- [ ] Measure clicks from sign-in to an un-RSVP'd huddl; record in Findings.
- [ ] `mix precommit`.

**Findings** _(fill in during the PR)_

- Clicks from login to an un-RSVP'd huddl:
- First-time user without help:
- What surprised you:
- What you'd cut:
- Terminology used:

---

### B — Better default landing

**Hypothesis.** `?scope=groups` is simply the better default. Most people's groups are why
they're here, and the huddl they came for is usually in one of them. Make Groups the default
scope and let people change it.

**Scope.** Two pieces, and the POC should make clear which carries the value:

1. Change the agenda's default scope to Groups.
2. Add a user setting for the preferred landing (or preferred scope), modeled on
   `theme_preference`: an atom-typed attribute with a default, a narrow Ash update action, and
   a policy allowing a person to update only their own.

The setting is the expensive half. Consider shipping the POC with piece 1 only and *mocking*
piece 2 in the PR description, if that's enough to judge the default.

**Watch out.** `?scope=mine` must stay reachable and must stay the thing `parse_scope/1`
returns for an explicit `mine`. Flipping the fallback must not make the RSVPs chip
unreachable, and the chip counts (`scope_counts/4`) must stay correct for both.

**Open questions to answer in Findings.**
- Is the setting "which scope" or "which page"? The latter generalizes to `/discover` and
  makes B a superset of parts of C and E.
- Where does the setting live — `/profile`, or `/profile/notifications`-style subpage?
- What's the default for a person in **zero** groups? Groups scope is empty for them, which is
  the first-run case `first_run?` already handles. Does the default need to be dynamic?

**Tasks**
- [ ] Write a Cucumber scenario: a signed-in person in a group visits `/agenda` and sees their
      group's huddlz, including ones they haven't RSVP'd to. Demonstrate it failing.
- [ ] Write a scenario: the RSVPs filter is still reachable and still shows only own RSVPs.
- [ ] Write a scenario for a person in zero groups landing on the agenda.
- [ ] Flip the default scope; keep `?scope=mine` explicit and working.
- [ ] Verify both chips' counts are still correct.
- [ ] Decide scope-vs-page for the setting; record the reasoning in Findings.
- [ ] Add the preference attribute + Ash update action + policy, following
      `theme_preference`.
- [ ] Add the setting's UI with Ash-driven validation (no HTML5 `required`).
- [ ] Honor the preference in the post-auth redirect, routed through
      `AuthReturnTo.validate/1`, and confirm an explicit `return_to` still wins over it.
- [ ] Write a scenario: a person who set a landing preference lands there after signing in.
- [ ] Measure clicks; record in Findings.
- [ ] `mix precommit`.

**Findings** _(fill in during the PR)_

- Clicks from login to an un-RSVP'd huddl:
- First-time user without help:
- Did piece 1 alone carry the value:
- What surprised you:
- What you'd cut:
- Terminology used:

---

### C — Discover inside the agenda

**Hypothesis.** The agenda is the page that feels right; `/discover` is the page that has the
answers. Bring Discover's results into the agenda as additional filters alongside RSVPs and
Groups — "nearby" and "all" — showing upcoming huddlz with no filter configuration required.

**Why this is the biggest variant.** The agenda's data path is scoped to the person's groups
throughout (`load_entries/2`, `load_group_extras/4`, `merge_entries/2`, `scope_counts/4`). A
scope meaning "huddlz I have no relationship to" is a new query, and it has to produce entries
in the agenda's own shape, with its own statuses and day grouping. `/discover` already has a
suitable query; the work is making its results inhabit the agenda.

**Scope.** Add one or two new scopes to `/agenda`. Keep the time window deliberately tight —
#670 suggests "maybe the next few days only", and the agenda already has an `@agenda_days`
window (7) to borrow. Reuse Discover's query rather than writing a new one. "Nearby" needs a
search location; a signed-in person's home search location is the obvious default, and
`/discover` already does this.

**Watch out.** Chip counts. `scope_counts/4` currently compares two in-memory lists. A scope
backed by a paginated async search can't be counted the same way. Either make counts optional
per scope or be honest in Findings that this is where the design strains. Also: the agenda is
synchronous; `/discover` is async with a loading state. Mixing them is a real design question,
not an implementation detail — report on it.

**Open questions to answer in Findings.**
- One new scope or two? Is "all" useful, or just noise without a location?
- What happens with no search location on file?
- Did bringing Discover into the agenda keep the agenda's calm feel, or import the clutter?
  This is the hypothesis's actual test.

**Tasks**
- [ ] Write a Cucumber scenario: a signed-in person visits `/agenda`, chooses the nearby
      filter, and sees an upcoming huddl from a group they don't belong to. Demonstrate it
      failing.
- [ ] Write a scenario: the RSVPs and Groups filters still behave as before.
- [ ] Write a scenario for a person with no home search location choosing the nearby filter.
- [ ] Map Discover's huddl query and decide how to reuse it from the agenda; record the
      approach in Findings.
- [ ] Add the new scope(s) to `parse_scope/1` and the agenda's URL state.
- [ ] Load the new scope's entries into the agenda's entry shape, reusing the existing day
      grouping and status logic.
- [ ] Resolve the chip-count problem; document the resolution.
- [ ] Resolve sync-vs-async rendering; document the resolution.
- [ ] Constrain the time window; justify the number chosen.
- [ ] Measure clicks; record in Findings.
- [ ] `mix precommit`.

**Findings** _(fill in during the PR)_

- Clicks from login to an un-RSVP'd huddl:
- First-time user without help:
- Did the agenda stay calm:
- Where the design strained:
- What you'd cut:
- Terminology used:

---

### D — Prominent search on the agenda

**Hypothesis.** A person who arrives with a specific huddl in mind doesn't want to browse —
they want to type its name. One obvious search field on the agenda beats any amount of
better browsing.

**Scope.** Put a search entry point on or near the agenda. The cheapest honest version is a
field that navigates to `/discover?q=...`; the richest is inline results on the agenda itself.
Pick one and say why. The cheap version is probably the better POC: it tests whether *search
being visible* is the fix, independent of where results render.

**Watch out.** Don't make the agenda feel like Discover. D's whole premise is that the agenda
stays calm and gains exactly one affordance. If your diff adds filters, you've drifted into C.

**Open questions to answer in Findings.**
- Navigate to `/discover`, or render results inline?
- Does search need to find groups too, or only huddlz? `/discover` does both.
- Is one field enough without a location, or does "near me" have to be implicit?

**Tasks**
- [ ] Write a Cucumber scenario: a signed-in person on `/agenda` searches for a huddl by name
      and reaches it. Demonstrate it failing.
- [ ] Write a scenario: a search with no matches explains itself.
- [ ] Decide navigate-vs-inline; record the reasoning in Findings.
- [ ] Add the search entry point to the agenda using `<.input>`, with Ash-driven validation.
- [ ] Wire it to Discover's existing search; do not write a second search path.
- [ ] Confirm the agenda gained no other affordances (self-review the diff against C).
- [ ] Measure clicks; record in Findings.
- [ ] `mix precommit`.

**Findings** _(fill in during the PR)_

- Clicks from login to an un-RSVP'd huddl:
- First-time user without help:
- Did the agenda stay calm:
- What surprised you:
- What you'd cut:
- Terminology used:

---

### E — Intent-based login flow

**Hypothesis.** The app can't guess intent, so it should ask. After signing in, offer "See my
huddlz" or "Find a new one" and route to the agenda or Discover accordingly.

**Why build it even though it adds a step.** It adds a click, so it will likely lose on the
click-count measure. It's worth building anyway because it's the only variant that *measures
intent directly*: the distribution of choices is evidence for what the default should be in
B. Treat the choice telemetry — even just a log line — as a deliverable.

**Watch out.** An interstitial between sign-in and destination is the highest-risk change
here. It must not appear when `return_to` is set (A's journey must bypass it entirely), it
must not appear on every sign-in forever, and it must not trap anyone. Krug's "memorable"
criterion is where this variant is most exposed: a question you answer every time is worse
than a default you set once.

**Open questions to answer in Findings.**
- Shown once, every time, or until dismissed?
- Does answering it also *set* the B preference? That would make E a discovery mechanism for
  B rather than a competitor.
- What did the choice distribution look like in your own testing?

**Tasks**
- [ ] Write a Cucumber scenario: a person signs in, chooses "find a new one", and reaches
      Discover. Demonstrate it failing.
- [ ] Write a scenario: a person signs in with a `return_to` destination and is **not** asked.
- [ ] Write a scenario: the choice is not re-asked on the next sign-in (per whatever policy
      you chose).
- [ ] Decide the showing policy; record the reasoning in Findings.
- [ ] Add the interstitial between the post-auth redirect and the landing page.
- [ ] Route each choice to its destination via `AuthReturnTo.validate/1`.
- [ ] Ensure an explicit `return_to` bypasses the interstitial completely.
- [ ] Log the choice so the distribution is observable; note it in Findings.
- [ ] Measure clicks; record in Findings.
- [ ] `mix precommit`.

**Findings** _(fill in during the PR)_

- Clicks from login to an un-RSVP'd huddl:
- First-time user without help:
- Choice distribution observed:
- Memorable (or does it nag):
- What you'd cut:
- Terminology used:

---

### F — Adaptive nudge

**Hypothesis.** Don't ask up front; notice. When someone repeatedly navigates away from their
landing page, offer to change it: "Change where you land after login?" with Change, Dismiss,
and Don't ask again.

**Why build it.** It's the only variant that costs nothing until it's useful. It's also the
one most likely to be annoying, and the hardest to get right — it needs B's preference to
exist and a notion of "repeatedly navigated away."

**Watch out.** This variant has the most room to over-build. Do **not** add analytics
infrastructure. The POC question is whether the *nudge* is welcome; detecting the condition
can be crude — a session counter, or even a dev-only trigger — as long as the PR is explicit
that the detection is a stand-in. Say so plainly in Findings rather than letting a reviewer
think it's production logic.

**Open questions to answer in Findings.**
- What counts as "repeatedly"? What did you use, and what would production need?
- Does "Don't ask again" need to persist to the user record, or is a session good enough for a
  POC?
- Is the nudge welcome or irritating? Report your honest reaction.

**Tasks**
- [x] Write a Cucumber scenario: a person who navigates away from their landing page several
      times is offered the chance to change it. Demonstrate it failing.
- [x] Write a scenario: choosing Change updates the landing and the next sign-in honors it.
- [x] Write a scenario: choosing "Don't ask again" stops the offer.
- [x] Define the detection condition; label it clearly as a stand-in if it is one.
- [x] Add the minimum landing preference the nudge can write to (borrow B's shape; duplicating
      B is fine).
- [x] Add the nudge UI with all three actions.
- [x] Persist the dismissal per the policy you chose.
- [x] Measure clicks; record in Findings.
- [ ] `mix precommit`. _(deliberate follow-up after review, per the POC brief: verified by
      scenario failing -> passing plus a clean `--warnings-as-errors` compile.)_

**Findings**

- **Clicks from login to an un-RSVP'd huddl:** 4 before, 3 after — and the saving is
  smaller than that, because of what the sidebar already does (below).
  - Baseline: land on `/agenda` -> **1** Discover in the sidebar -> **2** submit a search
    -> **3** open the huddl -> **4** RSVP.
  - After accepting the nudge (landing `:discover`): **1** submit a search -> **2** open the
    huddl -> **3** RSVP. Plus a one-time **1** click on "Land on Discover", so the nudge pays
    for itself on the second sign-in.
  - **The honest caveat.** `components/layouts.ex` already renders a global topbar search that
    GETs straight to `/discover` from *every* page, agenda included. Someone who uses that box
    is at **3** clicks today, with no preference and no nudge. So for them variant F saves
    **zero** clicks and only removes a surface they never visited. The 4-click baseline
    assumes the person navigates via the sidebar rather than the search box. I did not
    discover that search box until I was measuring, and it is the single most important thing
    I found: it weakens F's premise, and it weakens #670's "the agenda is a dead end" framing
    generally. Whoever scores these variants should check it before crediting any of them with
    click savings.

- **Detection condition used (and whether it's a stand-in):** **A stand-in. It should not
  ship.** `User.landing_departures` is an integer on the user record, incremented once per
  mount of a first-class in-app page that is not the person's landing page (`/discover`,
  `/agenda`, `/groups`, `/calendar/week`), capped at the threshold. At **3** departures the
  offer renders on the landing page. Three is a feel-it-in-a-POC number, not a researched one.
  It is wrong in at least four ways, all documented in the module's `@moduledoc`:
  1. it cannot tell "I came for a specific huddl and the agenda was no help" from idle
     browsing — both look like a departure;
  2. it never decays, so one curious afternoon marks the account permanently;
  3. it writes to the user record on page mounts, which is the wrong home for navigation
     signal and the wrong write pattern;
  4. it counts a page *mount*, so a back-button round trip inflates the count.
  Production would want something session- or event-shaped that distinguishes
  *searched-then-left* from *browsed*, and that decays. Per the variant's own warning I did
  **not** build analytics infrastructure to get there — the deliverable is the offer, not the
  detector.

- **Was the nudge welcome:** **Mixed, and I'd lean no in this form.** Honest reaction from
  building and clicking it:
  - The *copy* is the good part. "Change where you land after login?" with a reason ("You keep
    heading somewhere else after signing in") is legible in about a second, and offering the
    destination as a named button — "Land on Discover", with a line of hint text — means you
    never have to go find a settings page. That much I'd keep.
  - The *interruption* is the bad part, and the fact that it appears on the landing page makes
    it worse: it appears exactly when the person has arrived with an intention, which is the
    worst moment to ask them an unrelated question. It is a banner that pushes the content
    down. Three times out of four I wanted to answer "not now" just to get rid of it, which is
    the tell — a prompt people dismiss reflexively has become chrome, not help.
  - It also asks the person to predict their own future behavior ("where do you *usually* want
    to land?"), which is harder than the question it's trying to save them. The three-action
    shape is right — a free out and a permanent out are both necessary — but needing a
    "Don't ask again" button at all is an admission that the prompt is expected to annoy
    someone.
  - My read: the **preference** is worth having and the **nudge** is not the way to surface it.
    A quiet, always-available control (variant B's setting, or a pin on the surface itself)
    costs nothing and interrupts nobody. If a nudge survives at all it should be a one-line
    inline link, not a banner, and it should appear on the page the person *keeps going to*
    ("Always start here?") rather than on the one they're trying to leave. That reframing is
    cheap and I'd test it before testing this.

- **What you'd cut:**
  - The **detector**, entirely, as described above. It is the majority of the risk in this
    variant and none of its value.
  - The **banner treatment** — reduce to an inline one-line offer.
  - `landing_departures` as a **persisted column**. If a nudge like this ships, the counter is
    session state; it does not belong on the user row.
  - The **`:groups` landing option**, probably. `/agenda?scope=groups` as a *landing* is a
    third thing to explain next to Agenda and Discover, and the nudge's job is to be
    answerable without thinking. Two choices beat three here.
  - The nudge's **"Not now"** could arguably go too: it is the option that makes the prompt
    repeatable, and a prompt worth showing once is not obviously worth showing twice.

- **Terminology used:** **landing** — `landing_preference`, `LandingPreference`, "where you
  land after login", "Land on Discover". I picked it over *home* (already overloaded: `/` is
  the landing surface, and the user record has a `home_location`) and over *post-sign-in
  destination* (accurate, unusable in a button). The remembered pre-auth intent keeps the
  existing code's name, **return destination** (`return_to`, `AuthReturnTo`), which I did not
  rename. huddl/huddlz used throughout; no "event" anywhere in the diff.

---

### G — Combination: A + B + C

**Hypothesis.** From #670: *"1 + 2 + 3 may cover most cases without a new flow."* No new
interstitial, no new nudge — just intent preserved, a better default, and Discover reachable
from the agenda.

**Dependency note.** G is the one variant allowed to depend on others. Build it only after at
least two of A, B, C have open PRs, and cherry-pick from them rather than reimplementing. If
you're reading this and A/B/C aren't up yet, pick one of those instead.

**What G is actually testing.** Not whether each piece works — their own PRs establish that.
G tests whether the three together feel like one coherent page or three features stapled
together. Judge it on coherence, and say so if it feels stapled.

**Tasks**
- [ ] Confirm at least two of A, B, C have open PRs. If not, stop and build one of those.
- [ ] Write a Cucumber scenario covering the combined journey: arrive at a huddl signed out,
      sign in, land back on the huddl. Demonstrate it failing.
- [ ] Write a scenario: a person arriving *without* a destination lands on the Groups-scoped
      agenda and can reach a huddl outside their groups from there.
- [ ] Cherry-pick A's changes; note any conflicts in Findings.
- [ ] Cherry-pick B's changes; note any conflicts.
- [ ] Cherry-pick C's changes; note any conflicts.
- [ ] Resolve interactions — especially precedence between `return_to`, a landing preference,
      and the default scope. Document the precedence order you chose.
- [ ] Assess coherence honestly; record in Findings.
- [ ] Measure clicks for both journeys (with and without a destination).
- [ ] `mix precommit`.

**Findings** _(fill in during the PR)_

- Clicks, arriving with a destination:
- Clicks, arriving without one:
- Precedence order chosen:
- Coherent or stapled:
- What you'd cut:
- Terminology used:

---

## Comparison rubric

Scored from each PR's Findings section once the POCs are up. #670's measures, plus Krug's
criteria from the issue's Notes.

### Hard measures

| Measure | Target |
| --- | --- |
| Clicks from login to an un-RSVP'd huddl | 2 or fewer |
| A first-time user can do it without help | Yes |
| Diff size | Smaller wins, all else equal |

Count clicks for two journeys separately, because the variants optimize different ones:

- **With a destination** — arrived from a link or QR code with a specific huddl in mind.
- **Without one** — opened the app to see what's on.

### Krug's criteria

From #670. Score each variant 1–5.

| Criterion | Question |
| --- | --- |
| Useful | Does it do something people need done? |
| Learnable | Can people figure out how to use it? |
| Memorable | Do they have to relearn it each time? |
| Effective | Does it get the job done? |
| Efficient | Does it take a reasonable amount of time and effort? |
| Desirable | Do people want it? |
| Delightful | Is it enjoyable? _(weighted lower)_ |

Core question, verbatim from the issue: *Can a user of reasonable intelligence accomplish the
task they want in a reasonable amount of time?*

### Scoreboard

Filled in during comparison, not by POC authors.

| ID | Clicks (with dest.) | Clicks (without) | First-timer | Krug total | Notes |
| --- | --- | --- | --- | --- | --- |
| A | | | | | |
| B | | | | | |
| C | | | | | |
| D | | | | | |
| E | | | | | |
| F | | | | | |
| G | | | | | |

---

## Decision log

Append as decisions land. Date, decision, reasoning.

| Date | Decision | Reasoning |
| --- | --- | --- |
| 2026-10-08 | This document created from #670 | Shared brief so each POC PR is comparable |

---

## Done when

Per #670: an approach or combination is chosen, implementation issues are filed, and #670 is
closed. At that point:

- Record the choice in the Decision log above, with the reasoning.
- Close the losing POC PRs with a comment pointing at the decision.
- File implementation issues for the chosen approach — a POC is not the shipped thing.
- If the chosen approach settles any of the terminology questions in
  [Terminology this work will need](#terminology-this-work-will-need), add the term to
  `GLOSSARY.md` via `/domain-modeling`.
- Consider whether the decision warrants an ADR in `docs/adr/`. A new persisted user
  preference, or a new interstitial in the auth flow, probably does.
