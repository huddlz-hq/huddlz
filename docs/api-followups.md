# API follow-ups

Things consciously deferred while landing the JSON:API + GraphQL surface on
`feat/api`. Each entry captures *why* it was skipped and *what to do* when
it's time to come back to it, so we don't have to reconstruct the context.

> **Status as of latest sweep:**
> Items addressed in the "make `feat/api` shippable" pass:
> the slug ergonomics fix, group destroy cascade, ProfilePicture upload
> exposure, the GroupMember.remove_member JSON:API route, the real
> multipart HTTP test, and the image-upload error mapping. Removed from
> this doc. The remaining items below are genuinely deferred.

## Pagination sweep

**Status:** deferred.
**Why:** Adding `pagination keyset?: true` to a read action changes the
response shape — the result becomes a `KeysetPageOf<Type>` wrapper instead
of a bare list, so any test or call site that pattern-matches on
`{:ok, [list]}` breaks. The actions that ship paginated already (`Huddl.search`,
`Huddl.by_group`) needed their tests written around `results { ... }`
unwrapping. Sweeping the rest at the same time would have multiplied
breakage well beyond the API change.
**To do:**

- Add `pagination keyset?: true, offset?: true, countable: true, required?: false`
  to: `Huddl.upcoming`, `Huddl.past`, `Group.read`, `Group.search`,
  `GroupMember.get_by_group`, `GroupMember.get_by_user`,
  `HuddlAttendee.by_huddl`, `HuddlAttendee.by_user`,
  `GroupLocation.by_group`.
- Update each action's tests to wrap result-set assertions in `results { … }`
  (GraphQL) or expect `meta.page` envelopes (JSON:API).
- Add a per-resource `default_limit` (20) and a max so large lists don't
  fall back to "stream the whole table".

## OpenAPI / GraphiQL prose polish

**Status:** deferred.
**Why:** Descriptions exist on actions and arguments but they were written
for resource-internal callers. The phrasing reads awkwardly when surfaced
to API consumers via Swagger UI or GraphiQL. This is a writing task more
than a code task.
**To do:**

- Walk through `/api/json/swaggerui` and rewrite descriptions on each
  exposed action to address API consumers ("Create a huddl" not
  "Create a huddl with the given attributes via the create action").
- Add `@deprecated` directives on the legacy `:create` actions for
  `HuddlImage` / `GroupImage` (they're now superseded by `:upload` for
  API use; the manual-create actions should stay for internal callers
  that pre-compute storage paths).
- Add example bodies to the OpenAPI spec via `OpenApiSpex` example
  schemas.

## User update mutations use `id:` arg

**Status:** functional but un-ergonomic. Attempted fix in the
shippable-API sweep; deferred again after the AshGraphql/Ash 3.x
interaction proved more involved than expected.
**Why:** `updateDisplayName(id: $id, input: { displayName: $name })`
takes the user id explicitly even though the policy already
restricts the action to `^actor(:id)`. The client can pass any id
and the policy rejects mismatches; passing the id is noise.

The clean fix — `update :update_display_name, :update_display_name,
read_action: :me, identity: false` — produces an Ecto error at run
time:

> `update_all` does not allow subqueries in `from`

because `:me` filters on `^actor(:id)`, which Ash's atomic update
path turns into a subquery wrapping the update statement. Postgres
rejects that. Setting `require_atomic? false` on the update action
didn't bypass the path either.

**To do:**

- Investigate AshGraphql 1.9's mutation pipeline and figure out
  whether there's a `read_action`-compatible shape that doesn't go
  through bulk update (a `before_action` lookup, or a custom
  resolver, or an Ash patch).
- Alternative: build a generic action wrapper (`update_self`) that
  takes only the input fields, loads the actor explicitly, and
  delegates to the underlying update. Expose that action as the
  mutation. More code than the `read_action` shortcut but works
  around the atomic-update constraint.

## API key strategy: scopes, rotation, audit

**Status:** v1 ships with full-permission keys and manual revocation.
**Why:** Sufficient for a single first-party SPA / one trusted
machine consumer. Adding scopes / fine-grained permissions before
there's a second consumer is premature.
**To do (when needed):**

- Per-key scopes: `read_only`, `events:write`, `groups:admin`. Store
  on the `ApiKey` resource as an array of atoms; check via a custom
  policy.
- Rotation: a `rotate_api_key` mutation that creates a new key and
  marks the old one for deletion in N days.
- Audit log: record every API-key authentication event so a
  compromised key can be traced.

## Rate limiting

**Status:** none.
**Why:** No threat model yet — only first-party clients in flight.
**To do:**

- Add `:hammer` (Redis-backed in prod, ETS in dev) plug in front of
  `/api/auth/*` first (brute-force protection on register and
  sign_in).
- Per-user-or-key buckets on `/api/json/*` and `/gql`. Start
  permissive — the goal is to stop runaway scripts, not to throttle
  legitimate use.

## RemoveMemberByIds membership-existence leak

**Status:** known, acceptable for v1.
**Why:** `Huddlz.Communities.GroupMember.Actions.RemoveMemberByIds`
does `Ash.read_one(authorize?: false)` on `(group_id, user_id)` and
then dispatches `:remove_member` with the actor. The destroy is the
real auth gate, so unauthorized callers can't change state — but the
response shape distinguishes "membership not found" (404) from
"found but forbidden" (403), letting any authenticated actor probe
membership pairs. Group membership in a public group isn't very
secret; private groups would leak.
**To do:**

- Fold into the API-key scopes work above. Once a `groups:admin`
  scope exists, the lookup can be filtered to "groups owned by the
  actor" and the probe closes naturally.
- Cheaper interim fix: collapse 404 and 403 to a single 404 response
  shape so the failure modes are indistinguishable.

## User-FK cascade asymmetry

**Status:** deferred.
**Why:** Migration `20260427030225_cascade_destroy_groups_and_huddls`
cascades `groups → group_members / group_images / huddlz` and
`huddlz → huddl_images / huddl_attendees`, but the three FKs back to
`users` are **not** cascaded: `group_members.user_id`,
`huddl_attendees.user_id`, `huddlz.creator_id`. There's no
delete-account flow today, so this isn't blocking.
**To do (when delete-account ships):**

- Follow-up migration. `group_members` and `huddl_attendees` are
  pure join rows — `on_delete: :delete_all` is fine.
- `huddlz.creator_id` needs a product call **before** the FK
  changes: either soft-delete and anonymize the creator, or
  transfer ownership to the group owner. Don't `:delete_all` huddlz
  when their creator deletes their account.

## sign_out path doesn't apply to API-key auth

**Status:** functional but UX-confusing.
**Why:** `DELETE /api/auth/sign_out` only revokes JWT bearers
(it calls `TokenResource.Actions.revoke/2`). An actor authenticated
via an API key gets the same generic
`{"error": "Authentication required"}` 401 as an unauthenticated
caller, with no hint that the real revoke endpoint is
`DELETE /api/auth/api_keys/:id`.
**To do (when there's a real API-key consumer):**

- Detect the auth method on the conn and either
  (a) return a 400 with a pointer to `/api/auth/api_keys/:id`, or
  (b) destroy the active API key when sign_out is called with one.
  (a) is simpler and probably better — sign_out and key revocation
  are conceptually different.

## Cucumber `.feature` for the happy path

**Status:** end-to-end test ships as a single ExUnit case
(`test/huddlz_web/api/end_to_end_test.exs`).
**Why:** A Cucumber `.feature` file is the more readable format
for product/QA review, but writing the step definitions for a
multi-bearer, multi-protocol flow (JSON:API + GraphQL with token
swaps) is its own project.
**To do:**

- Port `end_to_end_test.exs` to a `.feature` file with step
  definitions. Probably easier once we have a small step library
  for `Given I am authenticated as ...` / `When I POST ... with body ...` /
  `Then the response is ...`.

---

When picking one of these up, tag the commit message with the section
heading so we can crosswalk back to this doc.
