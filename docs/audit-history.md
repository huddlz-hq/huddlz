# Audit history

Issue #568 supplies change history for troubleshooting; #554 attaches browser impersonation. The organizer activity feed remains a domain summary, with its existing visibility and behavior. PaperTrail versions are the underlying resource change history, not a second feed.

## Coverage

| Resources | Meaningful changes |
| --- | --- |
| Group | Creation, details, ownership, archival, restoration, deletion |
| Huddl | Creation, editing, publication, cancellation, completion, turnout, deletion |
| HuddlTemplate, GroupLocation | Recurrence and address-book changes |
| GroupMember | Joining, leaving, adding, removing, role changes |
| GroupInvitation | Invitation, claiming, acceptance, decline, revocation, expiry |
| HuddlAttendee | RSVP, cancellation, waitlist entry/withdrawal/promotion |
| GroupImage, HuddlCoverImage, HuddlPhoto | Image metadata creation/replacement/deletion |
| User | Account changes, including administrative role changes; no profile/contact values |
| ProfilePicture, ApiKey | Lifecycle changes without file paths, names, credentials or key hashes |

Reads, page views, searches, authentication attempts, notification delivery and error diagnostics are not audited here. Existing historical rows are not backfilled. Database cascades are not separate Ash actions: a parent deletion is recorded, while any existing child versions remain available for the retention period.

## Extension choices

Use AshPaperTrail 0.7's supported snapshot mode. Adjacent versions preserve values before and after edits without disabling atomic updates (the extension's full-diff mode does not support them). Only changed records produce versions. Action names distinguish operations; actors and affected people are separate.

Use `reference_source? false` to retain versions after hard deletion. Actor and impersonator foreign keys use `on_delete: :nilify`. The extension writes versions in Ash action hooks; integration checks exercise rollback when the version insert fails. No custom audit writer is introduced.

Version resources have strict deny policies and no web/API exposure. Trusted internal investigation can explicitly bypass authorization; being an administrator does not grant access to private content through these resources.

## Attribution

The Ash actor is recorded as `actor_id`. Callers may supply `context: %{paper_trail_metadata: %{impersonation_id: id, impersonator_id: administrator_id}}` through supported PaperTrail metadata. #554 supplies this from its trusted session. Nested participation actions must propagate the actor and this context. Known automatic work explicitly records `automatic?: true`; missing attribution is unknown, not proof of automation.

## Retention and personal data

Keep versions for 90 days and prune expired versions daily. Hard deletion of an item does not immediately delete its versions. Account deletion clears actor/impersonator links; item/subject IDs and group content may remain until expiry. Do not copy direct profile/contact values, password hashes, API-key hashes, tokens, or media paths into versions. Do not store action inputs. Free text in group/huddl content remains subject to the same 90-day limit.

Retention applies to new PaperTrail versions only; this work does not change the existing organizer activity feed's deletion policy. An audit UI and private-group moderation access are deferred.
