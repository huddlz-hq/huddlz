defmodule Huddlz.Communities.Huddl.Changes.NotificationPayload do
  @moduledoc """
  Builds the shared schedule payload used by huddl notifications.

  Keeping the authoritative instant and Huddl time zone together prevents
  individual notification producers from accidentally emitting UTC copy.
  """

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.Huddl

  @spec schedule(Huddl.t(), Group.t()) :: map()
  def schedule(%Huddl{} = huddl, %Group{} = group) do
    %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "time_zone" => huddl.time_zone,
      "group_name" => to_string(group.name),
      "group_slug" => to_string(group.slug)
    }
  end
end
