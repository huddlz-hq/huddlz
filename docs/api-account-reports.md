# Account reporting API

Confirmed members can submit account reports through either API using a bearer
JWT or API key. Both entry points use the same reporting action, eligibility
checks, validation, and retry handling. Reporting an account never suspends it.

A confirmed member may report the organizer of a publicly visible huddl without
joining its group or RSVPing. This does not grant access to the attendee list.

| Operation | JSON:API | GraphQL mutation |
| --- | --- | --- |
| Submit a report | `POST /api/json/account_reports` | `reportAccount(input: ...)` |

Send JSON:API requests with `Content-Type: application/vnd.api+json`:

```json
{
  "data": {
    "type": "account_report",
    "attributes": {
      "reported_user_id": "ACCOUNT_UUID",
      "reason": "spam",
      "details": "Repeated advertising"
    }
  }
}
```

`reason` is required: `spam` (Spam or advertising) or `other`. Details are
optional, with a maximum of 1,000 characters. Optional `source_type` (`huddl`
or `group`) and `source_id` record where the report was submitted from.

A successful JSON:API submission returns HTTP 201 and the report resource.
Repeating a submission while the same caller has an open, unexpired report
about that account returns the original report unchanged, even when switching
between APIs. After handling or expiry, another submission can be recorded.

GraphQL uses camelCase field names and enum values `SPAM` or `OTHER`:

```graphql
mutation ReportAccount($accountId: ID!) {
  reportAccount(input: {reportedUserId: $accountId, reason: SPAM}) {
    result { id }
    errors { message }
  }
}
```

The response exposes no reporter or account relationships. No report
notifications are sent. Trusted huddlz staff review reports and use account
administration through the dashboard; neither API exposes report listing,
report handling, account suspension, or restoration.
