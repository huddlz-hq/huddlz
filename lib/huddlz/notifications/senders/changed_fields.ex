defmodule Huddlz.Notifications.Senders.ChangedFields do
  @moduledoc """
  Renders the `changed_fields` payload list as a human-readable
  summary for huddl-update emails.
  """

  @spec summary(map()) :: String.t()
  def summary(%{"changed_fields" => fields}) when is_list(fields) and fields != [] do
    Enum.map_join(fields, ", ", &humanize/1)
  end

  def summary(_), do: "huddl details"

  defp humanize("title"), do: "the title"
  defp humanize("starts_at"), do: "the start time"
  defp humanize("ends_at"), do: "the end time"
  defp humanize("physical_location"), do: "the location"
  defp humanize("time_zone"), do: "the time zone"
  defp humanize("virtual_link"), do: "the virtual link"
  defp humanize("max_attendees"), do: "the capacity"
  defp humanize("is_private"), do: "the privacy"
  defp humanize("schedule"), do: "the recurring schedule"
  defp humanize(other) when is_binary(other), do: other
end
