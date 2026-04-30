defmodule Huddlz.Notifications.Triggers do
  @moduledoc """
  Registry of every notification trigger the system knows about.

  Each entry is keyed by a trigger atom (e.g. `:password_changed`) and stores:

    * `:category` — `:transactional`, `:activity`, or `:digest`
    * `:sender` — the module implementing `Huddlz.Notifications.Sender` for
      this trigger. Some senders may not exist yet at compile time; they ship
      in their respective phase issues. The registry references them by
      module atom regardless.
    * `:default` — the boolean preference value used when the user has not
      explicitly opted in or out.
    * `:label` — human-readable label used by the settings page UI.

  See `docs/notifications.md` for the full spec and rationale.
  """

  alias Huddlz.Notifications.Senders

  @triggers %{
    # A — Authentication & account
    password_changed: %{
      category: :transactional,
      sender: Senders.PasswordChanged,
      default: true,
      label: "Password changed"
    },
    email_changed: %{
      category: :transactional,
      sender: Senders.EmailChanged,
      default: true,
      label: "Email address changed"
    },
    account_role_changed: %{
      category: :activity,
      sender: Senders.AccountRoleChanged,
      default: true,
      label: "Your account role changed"
    },

    # B — Group membership
    group_member_joined: %{
      category: :activity,
      sender: Senders.GroupMemberJoined,
      default: true,
      label: "Someone joined a group I organize"
    },
    group_member_added: %{
      category: :activity,
      sender: Senders.GroupMemberAdded,
      default: true,
      label: "I was added to a group"
    },
    group_member_removed: %{
      category: :transactional,
      sender: Senders.GroupMemberRemoved,
      default: true,
      label: "I was removed from a group"
    },
    group_role_changed: %{
      category: :activity,
      sender: Senders.GroupRoleChanged,
      default: true,
      label: "My role in a group changed"
    },
    group_archived: %{
      category: :transactional,
      sender: Senders.GroupArchived,
      default: true,
      label: "A group I belong to was archived"
    },
    group_ownership_transferred: %{
      category: :transactional,
      sender: Senders.GroupOwnershipTransferred,
      default: true,
      label: "Group ownership transferred"
    },

    # C — Huddl lifecycle
    huddl_new: %{
      category: :activity,
      sender: Senders.HuddlNew,
      default: true,
      label: "New huddl scheduled in a group I'm in"
    },
    huddl_updated: %{
      category: :activity,
      sender: Senders.HuddlUpdated,
      default: true,
      label: "A huddl I'm RSVPd to was updated"
    },
    huddl_cancelled: %{
      category: :transactional,
      sender: Senders.HuddlCancelled,
      default: true,
      label: "A huddl I'm RSVPd to was cancelled"
    },
    huddl_series_updated: %{
      category: :activity,
      sender: Senders.HuddlSeriesUpdated,
      default: true,
      label: "A recurring huddl series I'm in was updated"
    },

    # D — Huddl reminders
    huddl_reminder_24h: %{
      category: :activity,
      sender: Senders.HuddlReminder24h,
      default: true,
      label: "24-hour reminder for a huddl I'm RSVPd to"
    },
    huddl_reminder_1h: %{
      category: :activity,
      sender: Senders.HuddlReminder1h,
      default: true,
      label: "1-hour reminder for a huddl I'm RSVPd to"
    },

    # E — RSVPs
    rsvp_received: %{
      category: :activity,
      sender: Senders.RsvpReceived,
      default: true,
      label: "Someone RSVPd to a huddl I organize"
    },
    rsvp_cancelled: %{
      category: :activity,
      sender: Senders.RsvpCancelled,
      default: true,
      label: "Someone cancelled an RSVP to a huddl I organize"
    },
    rsvp_confirmation: %{
      category: :activity,
      sender: Senders.RsvpConfirmation,
      default: true,
      label: "Confirmation when I RSVP to a huddl"
    },

    # F — Digests (deferred, default OFF)
    weekly_digest: %{
      category: :digest,
      sender: Senders.WeeklyDigest,
      default: false,
      label: "Weekly digest of upcoming huddlz"
    },
    reactivation_nudge: %{
      category: :digest,
      sender: Senders.ReactivationNudge,
      default: false,
      label: "Re-engagement email after long absence"
    }
  }

  @doc "All trigger entries, keyed by atom."
  @spec all() :: %{atom() => map()}
  def all, do: @triggers

  @doc "Fetch a single trigger entry. Returns `:error` if the trigger is unknown."
  @spec fetch(atom()) :: {:ok, map()} | :error
  def fetch(trigger), do: Map.fetch(@triggers, trigger)

  @doc "Fetch a single trigger entry. Raises if the trigger is unknown."
  @spec fetch!(atom()) :: map()
  def fetch!(trigger), do: Map.fetch!(@triggers, trigger)

  @doc "All trigger entries in a given category."
  @spec by_category(:transactional | :activity | :digest) :: %{atom() => map()}
  def by_category(category) do
    @triggers
    |> Enum.filter(fn {_atom, entry} -> entry.category == category end)
    |> Map.new()
  end

  @doc """
  The string key used in `User.notification_preferences` for this trigger.

  JSONB keys come back from postgres as strings, so we store and look up with
  the string form.
  """
  @spec preference_key(atom()) :: String.t()
  def preference_key(trigger) when is_atom(trigger), do: Atom.to_string(trigger)
end
