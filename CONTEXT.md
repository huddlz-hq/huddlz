# huddlz

huddlz helps people discover, organize, and participate in huddlz through the groups that bring them together.

## Language

**Calendar**:
The signed-in home and chronological view of a person's personal huddlz and the visible huddlz from their groups. It offers Day, Week, and Month ranges.
_Avoid_: My huddlz, My calendar

**Day**:
The Calendar range covering an entire selected date in the Display time zone, defaulting to the person's current date. It includes any huddl whose scheduled span overlaps that date.
_Avoid_: Today view, Next 24 hours

**Week**:
The Calendar range from Sunday through Saturday in the Display time zone. It includes any huddl whose scheduled span overlaps the selected week.
_Avoid_: Next seven days

**Month**:
The full calendar overview of a selected calendar month in the Display time zone. Selecting a date reveals its Day contents below while preserving the month and selected date for continued exploration.
_Avoid_: Next 30 days

**Display time zone**:
The account preference that determines viewer-local date and time presentation, including Calendar boundaries. Automatic mode resolves the browser time zone, then the home location time zone, then Florida's DST-aware Eastern Time; Fixed mode retains an explicitly selected time zone.
_Avoid_: Calendar time zone, Huddl time zone, fixed EST

**Huddl time zone**:
The authoritative IANA time zone in which a huddl's scheduled wall-clock time is expressed. Physical and hybrid huddlz use the physical venue time zone; virtual huddlz default to the group city time zone and allow the organizer to choose another.
_Avoid_: Display time zone, browser time zone

**Location time zone**:
The saved IANA time zone derived when a home, group-city, or venue location is selected. A person must choose it explicitly when location-based resolution is unavailable.
_Avoid_: Display time zone, UTC offset

**Group time zone**:
The organizer-maintained IANA time zone associated with a group's city and used as the default Huddl time zone for new virtual huddlz. Changing the group city does not reschedule existing huddlz or silently change this setting.
_Avoid_: Huddl time zone, Display time zone

**Personal huddl**:
A huddl a person is hosting, attending through a confirmed RSVP, or waitlisted for. It remains relevant whether or not the person belongs to the associated group.
_Avoid_: Personal event, scheduled event

**Hosting**:
The personal relationship of someone who created a huddl or was explicitly assigned to host it. Permission to manage a group's huddlz does not by itself mean someone is Hosting.
_Avoid_: Group organizer, group owner

**Group opportunity**:
A visible huddl from one of a person's groups for which they have no personal relationship.
_Avoid_: Recommendation, event

**Location label**:
The saved human-readable name of the place where a huddl occurs, used on compact surfaces such as cards. The huddl retains the exact address for its detailed view.
_Avoid_: Full address, venue details
