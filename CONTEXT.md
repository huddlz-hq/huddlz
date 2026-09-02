# huddlz

huddlz helps people discover, organize, and participate in huddlz through the groups that bring them together.

## Language

**Calendar**:
The signed-in home and chronological view of a person's personal huddlz and the visible huddlz from their groups. It offers Day, Week, and Month ranges.
_Avoid_: My huddlz, My calendar

**Today**:
The Calendar control that returns Day to the person's current date. It is not a separate schedule, range, or primary navigation destination.
_Avoid_: Today view, Today feed

**Day**:
The Calendar range covering an entire selected date in the Calendar time zone, defaulting to the person's current date. It includes any huddl whose scheduled span overlaps that date.
_Avoid_: Today view, Next 24 hours

**Week**:
The Calendar range from Sunday through Saturday in the Calendar time zone. It includes any huddl whose scheduled span overlaps the selected week.
_Avoid_: Next seven days

**Month**:
The full calendar overview of a selected calendar month in the Calendar time zone. Selecting a date reveals its Day contents below while preserving the month and selected date for continued exploration.
_Avoid_: Next 30 days

**Calendar time zone**:
The viewing preference that determines date boundaries and schedule presentation within Calendar. It defaults to the browser time zone and may be changed from Calendar without becoming part of a person's profile.
_Avoid_: Profile time zone, account time zone, Huddl time zone

**Huddl time zone**:
The authoritative IANA time zone in which a huddl's scheduled wall-clock time is expressed. Physical and hybrid huddlz use their physical location's time zone; virtual huddlz copy their group's time zone when created.
_Avoid_: Calendar time zone, browser time zone

**Location time zone**:
The IANA time zone derived from a selected physical location.
_Avoid_: Calendar time zone, UTC offset

**Group location**:
The required physical city or area that serves as a group's geographic home, even when the group organizes virtual huddlz.
_Avoid_: Optional location, virtual location

**Group time zone**:
The IANA time zone derived from the Group location and copied to new virtual huddlz. Changing the Group location does not alter the Huddl time zone of existing huddlz.
_Avoid_: Huddl time zone, Calendar time zone

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
