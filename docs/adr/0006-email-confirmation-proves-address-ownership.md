---
status: accepted
---

# Email confirmation is required before participation

Email confirmation establishes ownership of a particular address; it does not establish a person's identity or trustworthiness. Joining groups, RSVPing, and organizing huddlz require confirmation. Unconfirmed people can browse public content and use account-confirmation controls. Activity and digest emails require confirmation and remain subject to notification preferences; transactional email retains its existing exceptions.

We considered allowing participation immediately to reduce RSVP friction. We require confirmation because an unintended mailbox owner can use email-based password recovery to access the account and any accumulated data. This follows [OWASP's recommendation to verify email before account use](https://cheatsheetseries.owasp.org/cheatsheets/Email_Validation_and_Verification_Cheat_Sheet.html#email-ownership-verification).

Preserve the intended huddl through registration and email confirmation, then return the person to that huddl with a clear RSVP action. Confirmation itself does not create an RSVP or reserve capacity. The RSVP uses current availability and permissions, so a huddl that fills, changes, or becomes unavailable during confirmation is handled as it is now.

The destination survives confirmation in another browser or device. Preserve group invitation destinations through the same flow, with acceptance remaining an explicit action after confirmation.

Confirmation must apply to the specific address, including after an email change. A banner across signed-in pages shows the address and offers confirmation resends, with guidance to check junk mail. Profile settings retain the confirmation and pending-email-change controls. Dismissal lasts for the current session; profile settings retain the confirmation status. Existing unconfirmed accounts receive the same banner, without a bulk email campaign.

There is no automatic follow-up email: the banner helps people find the original message or request another themselves. Confirmation does not replay missed emails or change notification preferences.

For every email change, follow the [OWASP Authentication Cheat Sheet's process for accounts without MFA](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html#recommended-process-if-the-user-does-not-have-multifactor-authentication-enabled): require the current password, retain the replacement as pending, and require separate approvals from the old and new addresses using time-limited, single-use links. Provide a way to report an unexpected request. The existing address remains active for sign-in and recovery, and retains its existing notification eligibility, until both approvals complete. One approval alone never changes the address. This deliberately adds approval from the old inbox rather than relying on a notice after the change.

Both inbox approvals are required even when a person has lost access to the old address or never confirmed it, including a typo during sign-up. There is no recovery override for this situation: someone unable to complete the approvals must create a new account if they need to use a different address. The resulting loss of continuity with their existing memberships, RSVPs, and other account data is an accepted product trade-off. We considered requiring only the current password and confirmation of the new address, with a notice to the old inbox, but chose both approvals to prevent a stolen password alone from authorizing the transfer.

Resends allow one request per minute and five per hour per account. Resending does not invalidate unexpired links for the same address and confirmation attempt; links expire after three days. Completing confirmation, correcting the address, or cancelling a pending change invalidates obsolete links. For a change requiring two approvals, consuming one approval does not remove the other required approval.

Automatic expiration or deletion of unconfirmed accounts is out of scope. Existing unconfirmed accounts retain their data, receive the banner, and must confirm before further participation. Expired or incomplete email-change approvals never switch the address.

Participation is enforced through resource policies as well as the browser. Confirmation uses the account’s current status, so existing API credentials and already-open pages cannot retain permission to participate without it. The saved destination is limited to local huddl, group, and invitation pages and grants no access of its own.
