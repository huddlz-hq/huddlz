# Suspension is an account action, separate from community moderation

An administrator can suspend an account for abuse and restore one whose suspension was a mistake. Suspension is indefinite, needs a reason, and records who acted and when. It cuts the person off everywhere at once (browser sessions, open pages, bearer tokens and API keys), releases their upcoming RSVP and waitlist spots under the ordinary capacity rules, hides them from member lists and searches, and shows "Suspended account" in place of their name and picture wherever a record must keep its author, on the API as much as on a page. Their groups, huddlz and participation history stay as they are and are flagged for an administrator to look at. The person gets one plain email with the support address and nothing else from huddlz until restored.

We want abuse stopped without erasing a community's records or widening what administrators can do inside groups (ADR-0004).

## Considered options

- **Deleting the account.** Rejected: it destroys the shared records of every group the person touched, and a mistaken deletion cannot be undone.
- **Hiding the account and its content.** Rejected: hiding a group or a huddl on the owner's behalf punishes everyone who joined it. Groups and huddlz stay; an administrator decides each one, and only with the access they already have.
- **A temporary suspension with an expiry.** Rejected: an expiry restores access without anyone judging the case. Restoration is manual, and only for a suspension judged mistaken; proof that a person is at the keyboard is not enough on its own.
- **Keeping the name on historical records.** Rejected: a spam name is itself the abuse. Records keep their author under a neutral label; the original name is read only in account administration and participation history.
- **A neutral label that discloses nothing about status.** Considered: "Suspended account" says why a person vanished, which is what an organizer looking at their own feed needs to know. It carries no name and no reason.

## Consequences

Every stored token is revoked and every API key is destroyed at the moment of suspension, so restoration never revives a credential; the person signs in again from scratch. Password reset and email confirmation work as proofs but never hand a suspended account a session.

Released spots are ordinary cancellations on the record, attributed to the administrator, so the waitlist moves as it would for any cancellation. A suspended person on a waitlist is skipped by every promotion path.

Member counts leave suspended accounts out, so a roster and its count agree. Attendance history keeps its rows under the neutral label, as who's going keeps naming people who RSVPd (ADR-0008).

Suspension is a versioned change on the account, so the reason, the administrator and the time follow the two-year audit window (ADR-0007). The current status and reason stay on the account until restoration; an expired audit entry restores nothing.

Community notifications, in-app and by email, stop at once. The one suspension notice carries no internal notes and names no reporter.
