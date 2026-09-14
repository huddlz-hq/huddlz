# Signup abuse prevention

Status: shared understanding and ticket sequence approved; issues published. Display-name validation is implemented locally; the remaining tickets are follow-up work.

## Agreed direction

- Address display-name abuse, automated bulk registration, and suspension of abusive accounts as separate workstreams.
- Allow nicknames, international text, punctuation, emoji, and business names. Prohibit web addresses and overt advertisements in display names.
- Automatically reject recognizable links on signup and name changes; use moderation for ambiguous promotional language rather than a keyword blacklist.
- Keep signup open and minimize inconvenience for legitimate people. Investigate a low-friction bot check and conservative signup throttling separately from URL validation.
- Retain account creation before confirmation and preserve unconfirmed accounts; participation remains gated by confirmation.
- Reject recognizable web addresses, including addresses without a protocol. Leave disguised advertising to moderation rather than aggressive detection.
- Flag existing invalid display names for administrator review; do not automatically suspend those accounts.

## Scope and moderation decisions

- Implement URL rejection in display names first. Turnstile is a separate investigation ticket, outside the URL-validation implementation; neither provider adoption nor failure behavior is decided.
- Hide suspended accounts from ordinary member listings and searches and from the default administrator user list. Provide an administrator view for managing suspended accounts and restoration.
- Where historical attribution remains necessary, use a neutral label in place of the suspended account's display name. Hide personal profile content immediately.
- Release future RSVP and waitlist spots on suspension, retaining historical records.
- Preserve owned groups and huddlz pending explicit moderation; flag owned groups and upcoming huddlz for administrator review. Suspending one owner must not automatically hide or remove an entire community.
- Implement validation on signup and name changes first; identifying existing invalid names is a separate review ticket.
- Platform administrators alone suspend and restore accounts, with a required reason and an audit record of who acted and when. Suspension immediately ends authenticated access.
- Restoration permits fresh sign-in, without restoring revoked credentials or automatically rebooking released RSVP or waitlist spots.
- Member reporting is a committed follow-up feature. Confirmed members can report an account from surfaces where they can already see the person. Offer Spam or advertising and Other, with optional details. Reports enter an administrator queue, never automatically suspend accounts, and do not disclose the reporter to the reported account.
- IP-based signup throttling is a separate investigation ticket, outside the immediate URL-validation work.
- Reject recognizable email addresses as well as URLs; retain ordinary initials and punctuation. Reject rather than rewrite the submitted name, with: Choose a display name without links or email addresses.
- Prohibit promotional display names as policy. Ambiguous handles are handled through reports and contextual administrator review, not platform-name or keyword blacklists. Adapt future safeguards to observed abuse.
- Stop community notifications to suspended accounts. Send one plain suspension notice with a support contact path, keeping internal moderation notes private. Confirmation and password reset never lift suspension.
- Reporters receive only an immediate acknowledgement, with no status tracking or follow-up messages. Administrators have a simple Mark handled action and can suspend when appropriate.
- Suspension has no automatic expiry. Only an administrator may restore an account after determining that the suspension was mistaken; proof of human control alone is insufficient. Agent-based review is out of scope.
- Retain the current suspension status and reason until restoration. Reports and historical audit records expire after the existing two-year window.
- Automatic account purging is outside implementation scope. Create a separate retention-and-purge investigation to propose deletion or anonymization periods, minimal suspension records, and treatment of shared records. No automatic purge deadline is agreed.

## Existing behavior

Signup creates the account before email confirmation. Confirmation is required for participation and proves access to the address, not trustworthiness. Unconfirmed accounts can therefore appear in the administrator's user list. ADR 0006 preserves unconfirmed accounts and excludes automatic deletion.

## Ticket breakdown

1. [#586: Reject URLs and email addresses in display names](https://github.com/huddlz-hq/huddlz/issues/586). Implement first.
2. [#587: Administrator suspension and restoration](https://github.com/huddlz-hq/huddlz/issues/587), including access, visibility, RSVP, notification, and audit behavior described above. No implementation blocker; follows validation in priority.
3. [#588: Review existing invalid display names](https://github.com/huddlz-hq/huddlz/issues/588). Blocked by #586 and #587 so recognition is consistent and review can lead to suspension.
4. [#589: Member reports and administrator queue](https://github.com/huddlz-hq/huddlz/issues/589). Blocked by #587.
5. [#590: Investigate Turnstile](https://github.com/huddlz-hq/huddlz/issues/590): user friction, coverage, failure behavior, integration, and operational requirements. Adoption remains undecided.
6. [#591: Investigate signup throttling](https://github.com/huddlz-hq/huddlz/issues/591): trusted client identity across entry points, conservative limits, shared-network effects, and recovery experience.
7. [#592: Investigate retention and purging](https://github.com/huddlz-hq/huddlz/issues/592), preserving necessary shared records and defining minimal suspension information.

Investigation findings may require further product decisions; they are not prerequisites for ticket 1. See ADR 0009 for the suspension boundary and retention trade-off.
