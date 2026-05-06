defmodule Huddlz.Notifications.Summary do
  @moduledoc """
  Builds in-app feed copy for a triggered notification.

  Returns `%{title, description, source_url}` from a trigger atom plus its
  payload. The Updates tab on `/me` renders one card per Notification row,
  using these fields directly.

  Phrasing rule: tense-agnostic, action-oriented. The card already shows a
  relative timestamp ("2 days ago"); titles must read cleanly long after
  the moment they fired. Avoid first-person-present ("you're going") and
  time-relative words ("tomorrow", "in 5 minutes", "now").
  """

  alias Huddlz.Notifications.Triggers

  @type result :: %{
          title: String.t(),
          description: String.t() | nil,
          source_url: String.t() | nil
        }

  @spec summarize(atom(), map()) :: result()
  def summarize(trigger, payload) when is_atom(trigger) and is_map(payload) do
    %{
      title: title(trigger, payload),
      description: description(trigger, payload),
      source_url: source_url(trigger, payload)
    }
  end

  # ─── Titles ────────────────────────────────────────────────────────────

  # Authentication / account
  defp title(:password_changed, _), do: "Password changed"
  defp title(:email_changed, _), do: "Email address changed"
  defp title(:account_role_changed, %{"new_role" => role}), do: "Account role changed to #{role}"
  defp title(:account_role_changed, _), do: "Account role changed"

  # Group membership
  defp title(:group_member_joined, %{"joiner_display_name" => name, "group_name" => group}),
    do: "#{name} joined #{group}"

  defp title(:group_member_added, %{"group_name" => group}), do: "Added to #{group}"
  defp title(:group_member_removed, %{"group_name" => group}), do: "Removed from #{group}"
  defp title(:group_role_changed, %{"group_name" => group}), do: "Role changed in #{group}"
  defp title(:group_archived, %{"group_name" => group}), do: "Archived: #{group}"

  defp title(:group_ownership_transferred, %{"group_name" => group, "role" => "previous_owner"}),
    do: "Ownership transferred: #{group}"

  defp title(:group_ownership_transferred, %{"group_name" => group}),
    do: "You're now the owner of #{group}"

  # Huddl lifecycle
  defp title(:huddl_new, %{"group_name" => group, "huddl_title" => huddl}),
    do: "New in #{group}: #{huddl}"

  defp title(:huddl_updated, %{"huddl_title" => huddl}), do: "Updated: #{huddl}"
  defp title(:huddl_cancelled, %{"huddl_title" => huddl}), do: "Cancelled: #{huddl}"

  defp title(:huddl_series_updated, %{"huddl_title" => huddl}),
    do: "Series updated: #{huddl}"

  # Reminders
  defp title(:huddl_reminder_24h, %{"huddl_title" => huddl}),
    do: "Reminder: #{huddl} (24h)"

  defp title(:huddl_reminder_1h, %{"huddl_title" => huddl}),
    do: "Reminder: #{huddl} (1h)"

  # RSVPs
  defp title(:rsvp_received, %{"huddl_title" => huddl, "rsvper_display_name" => name}),
    do: "#{name} RSVPed to #{huddl}"

  defp title(:rsvp_received, %{"huddl_title" => huddl}), do: "New RSVP: #{huddl}"

  defp title(:rsvp_cancelled, %{"huddl_title" => huddl, "rsvper_display_name" => name}),
    do: "#{name} cancelled their RSVP to #{huddl}"

  defp title(:rsvp_cancelled, %{"huddl_title" => huddl}), do: "RSVP cancelled: #{huddl}"

  defp title(:rsvp_confirmation, %{"huddl_title" => huddl}),
    do: "RSVP confirmed: #{huddl}"

  defp title(:waitlist_promoted, %{"huddl_title" => huddl}),
    do: "Waitlist promoted: #{huddl}"

  # Digests
  defp title(:weekly_digest, _), do: "Weekly digest"
  defp title(:reactivation_nudge, _), do: "We've missed you on huddlz"

  # Fallback to the registry label for any trigger missing a clause above
  defp title(trigger, _) do
    case Triggers.fetch(trigger) do
      {:ok, %{label: label}} -> label
      :error -> "Notification"
    end
  end

  # ─── Descriptions ──────────────────────────────────────────────────────
  # Use absolute dates rather than relative phrasing. Leave nil when a
  # description would just restate the title.

  defp description(:rsvp_confirmation, %{"starts_at_iso" => iso}),
    do: maybe_absolute_date("Starts ", iso)

  defp description(:huddl_new, %{"starts_at_iso" => iso}),
    do: maybe_absolute_date("Starts ", iso)

  defp description(:huddl_updated, %{"starts_at_iso" => iso}),
    do: maybe_absolute_date("Now starts ", iso)

  defp description(:huddl_reminder_24h, %{"starts_at_iso" => iso}),
    do: maybe_absolute_date("Starts ", iso)

  defp description(:huddl_reminder_1h, %{"starts_at_iso" => iso}),
    do: maybe_absolute_date("Starts ", iso)

  defp description(_, _), do: nil

  defp maybe_absolute_date(prefix, iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> prefix <> Calendar.strftime(dt, "%b %d, %Y")
      _ -> nil
    end
  end

  defp maybe_absolute_date(_prefix, _), do: nil

  # ─── Source URLs ───────────────────────────────────────────────────────

  defp source_url(_trigger, %{"group_slug" => slug, "huddl_id" => huddl_id})
       when is_binary(slug) and is_binary(huddl_id),
       do: "/groups/#{slug}/huddlz/#{huddl_id}"

  defp source_url(_trigger, %{"group_slug" => slug}) when is_binary(slug),
    do: "/groups/#{slug}"

  defp source_url(:password_changed, _), do: "/profile"
  defp source_url(:email_changed, _), do: "/profile"
  defp source_url(:account_role_changed, _), do: "/profile"
  defp source_url(_trigger, _payload), do: nil
end
