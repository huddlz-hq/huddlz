# Group Membership: Roles, Verification, and Access Rules

This document defines the canonical rules and rationale for group membership in the huddlz platform. It covers role definitions, verification requirements, and access policies for member visibility.

---

## Roles

A group member is any user who has a membership in a group. Membership roles are:

- **owner**: The creator and primary leader of a group. There is only one owner per group, and the owner must be a verified user.
- **organizer**: Trusted, verified users who help manage the group. There can be multiple organizers per group.
- **member**: Regular participants. Members can be either verified or regular (non-verified) users.

### Role Assignment Rules

- Only verified users can be assigned as `owner` or `organizer`.
- When creating a group, the owner must be a verified user.
- Organizers must also be verified users.
- Members can be either verified or regular (non-verified).

---

## Verification

- **Verified users**: Users who have completed the verification process and have elevated trust and permissions.
- **Regular users**: Users who have not been verified.

Verification status is critical for role assignment and access control.

---

## Access Matrix

| User Type/Role         | Group Type | Can See Members? | Notes                  |
|------------------------|------------|------------------|------------------------|
| owner (verified)       | any        | Yes              |                        |
| organizer (verified)   | any        | Yes              |                        |
| member (verified)      | any        | Yes              |                        |
| member (regular)       | any        | No (count only)  |                        |
| non-member (verified)  | public     | Yes              |                        |
| non-member (verified)  | private    | No               |                        |
| non-member (regular)   | any        | No (count only)  |                        |

---

## Policy Summary

- Owners and organizers (must be verified) can always see the full member list for their group.
- Verified members can see the full member list for groups they belong to.
- Regular (non-verified) members and non-members can only see the count of members, not the member list.
- Only verified users can be assigned as owner or organizer.
- When creating a group, the owner must be a verified user.

---

## Rationale

- **Security & Trust:** Restricting elevated roles to verified users ensures that only trusted individuals can manage groups and access sensitive member information.
- **Privacy:** Regular users and non-members cannot see the member list, protecting user privacy in both public and private groups.
- **Consistency:** Modeling all roles (including owner) as group members allows for uniform policy checks and simplifies access control logic.

---

## Examples

### Example 1: Public Group

- **Owner (verified):** Can see all members.
- **Organizer (verified):** Can see all members.
- **Member (verified):** Can see all members.
- **Member (regular):** Can only see the count.
- **Non-member (verified):** Can see all members.
- **Non-member (regular):** Can only see the count.

### Example 2: Private Group

- **Owner (verified):** Can see all members.
- **Organizer (verified):** Can see all members.
- **Member (verified):** Can see all members.
- **Member (regular):** Can only see the count.
- **Non-member (verified):** Cannot see members, only the count.
- **Non-member (regular):** Can only see the count.

---

## Implementation Notes

- The `GroupMember` resource should have a `role` field with values: `"owner"`, `"organizer"`, `"member"`.
- The `User` resource should have a `verified` boolean or equivalent.
- Policies should enforce:
  - Only verified users can be assigned as owner or organizer.
  - Member list visibility according to the matrix above.
- When querying for members, the API should return either the full list (if allowed) or only the count (if not).

---

## See Also

- [CLAUDE.md](../CLAUDE.md) — Project conventions and terminology
- [README.md](../README.md) — Project overview
- [LEARNINGS.md](../LEARNINGS.md) — Rationale and design decisions

---