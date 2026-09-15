# Staff administration is dashboard-only

Account and platform administration are staff workflows performed through the huddlz dashboard: report review and handling, account suspension and restoration, and the platform overview have no public GraphQL or JSON:API operations. This is an explicit product exception to API-first access and agent tooling, chosen because staff will use the dashboard for these operations; authorization remains enforced by shared domain actions. Member report submission remains available through both APIs, with the same eligibility and retry rules as the browser.
