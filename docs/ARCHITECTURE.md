# Architecture

## Entity Relationships

```mermaid
erDiagram
    User ||--o{ Group : owns
    User ||--o{ GroupMember : "has memberships"
    User ||--o{ Huddl : creates
    User ||--o{ HuddlAttendee : "RSVPs to"

    Group ||--o{ GroupMember : "has members"
    Group ||--o{ Huddl : contains
    Group }o--|| User : "owned by"

    Huddl }o--|| Group : "belongs to"
    Huddl }o--|| User : "created by"
    Huddl ||--o{ HuddlAttendee : "has attendees"
    Huddl }o--o| HuddlTemplate : "from template"

    GroupMember }o--|| User : "is user"
    GroupMember }o--|| Group : "in group"

    HuddlAttendee }o--|| User : "is user"
    HuddlAttendee }o--|| Huddl : "attending"
```

## Group Permissions

| Action               | Admin | Owner | Organizer | Member | Public User | Guest |
|:---------------------|:-----:|:-----:|:---------:|:------:|:-----------:|:-----:|
| View public group    |   ✓   |   ✓   |     ✓     |   ✓    |      ✓      |   ✓   |
| View private group   |   ✓   |   ✓   |     ✓     |   ✓    |      -      |   -   |
| Create group         |   ✓   |   -   |     -     |   -    |      ✓      |   -   |
| Edit group           |   ✓   |   ✓   |     -     |   -    |      -      |   -   |
| Delete group         |   ✓   |   ✓   |     -     |   -    |      -      |   -   |
| View member list     |   ✓   |   ✓   |     ✓     |   ✓    |      -      |   -   |
| Add members          |   ✓   |   ✓   |     ✓     |   -    |      -      |   -   |
| Remove members       |   ✓   |   ✓   |     ✓     |   -    |      -      |   -   |
| Join public group    |   ✓   |   -   |     -     |   -    |      ✓      |   -   |
| Leave group          |   ✓   |   -   |     ✓     |   ✓    |      -      |   -   |

## Huddl Permissions

| Action               | Admin | Owner | Organizer | Creator | Member | Public User | Guest |
|:---------------------|:-----:|:-----:|:---------:|:-------:|:------:|:-----------:|:-----:|
| View public huddl    |   ✓   |   ✓   |     ✓     |    ✓    |   ✓    |      ✓      |   ✓   |
| View private huddl   |   ✓   |   ✓   |     ✓     |    ✓    |   ✓    |      -      |   -   |
| Create huddl         |   ✓   |   ✓   |     ✓     |    -    |   -    |      -      |   -   |
| Edit huddl           |   ✓   |   ✓   |     ✓     |    ✓    |   -    |      -      |   -   |
| Delete huddl         |   ✓   |   ✓   |     ✓     |    ✓    |   -    |      -      |   -   |
| RSVP                 |   ✓   |   ✓   |     ✓     |    ✓    |   ✓    |      ✓      |   -   |
| Cancel own RSVP      |   ✓   |   ✓   |     ✓     |    ✓    |   ✓    |      ✓      |   -   |
| View attendee list   |   ✓   |   ✓   |     ✓     |    ✓    |   ✓*   |      -      |   -   |
| See virtual link     |   ✓   |   ✓   |     ✓     |    ✓    |  ✓**   |      -      |   -   |

\* Members can only see attendee list if they are attending
\*\* Virtual link only visible after RSVP

## Visibility Rules

```mermaid
flowchart TD
    A[User requests resource] --> B{Is Admin?}
    B -->|Yes| Z[Allow access]
    B -->|No| C{Resource type?}

    C -->|Group| D{Is public?}
    D -->|Yes| Z
    D -->|No| E{Is owner or member?}
    E -->|Yes| Z
    E -->|No| X[Deny access]

    C -->|Huddl| F{Is public?}
    F -->|Yes| G{Group is public?}
    G -->|Yes| Z
    G -->|No| H{Is group member?}
    H -->|Yes| Z
    H -->|No| X
    F -->|No| I{Is group member?}
    I -->|Yes| Z
    I -->|No| X
```

## Group Member Roles

```mermaid
flowchart LR
    subgraph Roles
        Owner[Owner]
        Organizer[Organizer]
        Member[Member]
    end

    Owner -->|can do everything| Organizer
    Organizer -->|can manage huddlz| Member
    Member -->|can view & RSVP| Guest[Guest Access]
```

| Role      | Manage Group | Manage Members | Create Huddlz | Edit Any Huddl | View Private |
|:----------|:------------:|:--------------:|:-------------:|:--------------:|:------------:|
| Owner     |      ✓       |       ✓        |       ✓       |       ✓        |      ✓       |
| Organizer |      -       |       ✓        |       ✓       |       ✓        |      ✓       |
| Member    |      -       |       -        |       -       |       -        |      ✓       |

## Huddl Lifecycle

Status is calculated automatically based on current time:

```mermaid
stateDiagram-v2
    [*] --> Upcoming: Create (starts_at in future)
    Upcoming --> InProgress: starts_at reached
    InProgress --> Completed: ends_at reached
    Completed --> [*]
```

| Status | Condition |
|--------|-----------|
| `upcoming` | `starts_at > now()` |
| `in_progress` | `starts_at <= now() <= ends_at` |
| `completed` | `ends_at < now()` |

