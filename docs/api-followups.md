# API follow-ups

Things consciously deferred while landing the JSON:API + GraphQL surface on
`feat/api`. Each entry captures *why* it was skipped and *what to do* when
it's time to come back to it, so we don't have to reconstruct the context.

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

## `GroupMember.remove_member` JSON:API route

**Status:** deferred — GraphQL only for now.
**Why:** The action's filter-by-arg design (takes `:group_id` + `:user_id`,
filters to that pair, destroys the matching record) doesn't map onto
JSON:API's `DELETE /:id` convention. Exposing it under `/remove/:id` would
mean the path's `:id` is ignored and the action runs entirely off args —
a misleading shape for clients. GraphQL handles it cleanly because the
action's args become input fields.
**To do:**

- Reshape the action to take a record id (or a `(group_id, user_id)`
  composite identity). Either:
  1. Find the membership by id first, then run a no-arg destroy whose
     policy checks `actor` is the group owner; or
  2. Keep the args-based shape but expose it as an `action :remove_member`
     (generic action) under a `route :delete, "/group_members/remove"`
     route, which AshJsonApi supports for arbitrary verbs.
- Mirror the GraphQL test once a JSON:API route exists.

## Real multipart HTTP test for image upload

**Status:** smoke-tested, but no end-to-end multipart fixture.
**Why:** AshJsonApi's multipart envelope is the custom
`multipart/x.ash+form-data` content-type (see
`AshJsonApi.Plug.Parser` docs). Constructing one in Phoenix.ConnTest
requires either a hand-rolled boundary or a helper that knows the
`data` part vs file parts protocol. The action-level upload test
already exercises the full storage path (Plug.Upload → PersistUpload
change → Storage adapter → DB row), so the HTTP-only gap is purely
"is the parser plug actually called and does the route accept the
content type".
**To do:**

- Add a `multipart_post/3` helper to `HuddlzWeb.ApiCase` that builds
  a `multipart/x.ash+form-data` request body with a single file part.
- Wire it through one happy-path test in
  `test/huddlz_web/api/json/huddl_image_test.exs` to assert the
  storage path is populated end-to-end via HTTP.
- For GraphQL: Absinthe expects the standard
  [GraphQL multipart spec](https://github.com/jaydenseric/graphql-multipart-request-spec).
  Add a separate helper.

## Image upload — additional items

**Status:** core actions land; supporting work deferred.

- `ProfilePicture.upload` action exists and has a policy, but the
  resource has no `graphql` / `json_api` block yet — there's no public
  endpoint to call it. Adding one is small but needs a decision on
  whether to expose `ProfilePicture` as a top-level type or only via
  `User.profile_pictures`.
- File-size and content-type validation lives in the storage modules
  (`Huddlz.Storage.HuddlImages.validate_file_size/1` etc.) but errors
  surface as raw atoms (`:invalid_extension`). Should be mapped to
  user-friendly JSON:API error codes.
- Pre-signed S3 upload URLs (the v2 plan) — deferred until there's a
  concrete consumer that can't do multipart through the app server.

## Group create takes explicit slug

**Status:** mild API ergonomics gap.
**Why:** `POST /api/json/groups` requires `slug` in the request body
because `Group.slug` is `allow_nil? false` and JSON:API validates
attributes before changes run. The `GenerateSlug` change auto-fills it
from `name`, but only if the attribute reaches it — JSON:API rejects
the request before the change runs.
**To do:**

- Change `Group.create_group` to drop `:slug` from `accept` (so it's
  no longer a settable attribute via the API) and ensure
  `GenerateSlug` runs early enough that the validation pass sees the
  populated value. This requires either a `prepare`-style change or
  moving slug generation to a `before_action`.

## Group destroy can leave records behind

**Status:** the action runs but returns 400 when a group has members.
**Why:** Default destroy doesn't cascade; the existing FK on
`group_members.group_id` rejects the delete. The plan accepted this
trade-off — the test asserts 400 is returned past the auth gate, not
that the destroy succeeds.
**To do:**

- Replace the default `:destroy` with a soft-delete (add a
  `deleted_at` attribute and have read actions filter it out), or
- Add a `change cascade_destroy(:group_members, return_notifications?: true)`
  to actually delete dependents. Pick one, document the choice.

## Group attributes not surfaced in API responses

**Status:** known gap.
**Why:** `name`, `description`, `location` on `Group` aren't
`public? true`, so JSON:API and GraphQL don't include them in
serialized responses. We exposed the resource without flipping these
to public because the existing LiveView relies on resource-level
loads, and we wanted to keep this PR scoped to API surface — not
attribute visibility.
**To do:**

- Audit each `Group` attribute and decide which should be public.
  At minimum: `name`, `description`, `location`, `slug`, `is_public`.
- Same exercise for `Huddl` (most are already public),
  `GroupMember.role`, `HuddlAttendee.rsvped_at`, `GroupLocation.address`.
- Run the sensitive-field audit test after each batch — it'll fail
  loudly if the new public fields include anything on the deny list.

## User update mutations use `id:` arg

**Status:** functional but un-ergonomic.
**Why:** `updateDisplayName(id: $id, input: { displayName: $name })`
takes the user id explicitly even though the policy already
restricts the action to `^actor(:id)`. This mirrors how AshGraphql
generates update mutations from an action that targets a record. The
client can pass any id and the policy rejects mismatches; passing
the id is just noise.
**To do:**

- Add a thin `:update_self` style action that loads the actor and
  delegates to the underlying update, and expose *that* as the
  GraphQL mutation. The mutation then takes only the input fields,
  not an id.
- Or use `ash_graphql`'s `read_action` option on the mutation to
  pin the actor lookup.

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
