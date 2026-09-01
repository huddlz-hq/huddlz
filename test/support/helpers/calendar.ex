defmodule Huddlz.Test.Helpers.Calendar do
  @moduledoc false

  import Huddlz.Generator

  def create_calendar_member_group(opts \\ []) do
    member = opts[:member] || generate(user(role: :user))
    owner = opts[:owner] || generate(user(role: :user))

    {group, [membership]} =
      generate_group_with_members(
        owner: owner,
        group: opts[:group] || [is_public: true],
        members: [%{user: member, role: opts[:role] || :member}]
      )

    %{member: member, owner: owner, group: group, membership: membership}
  end

  def create_today_huddl(group, creator, title, opts \\ []) do
    time_zone = "America/New_York"
    today = DateTime.now!(time_zone) |> DateTime.to_date()
    starts_at = DateTime.new!(today, ~T[12:00:00], time_zone) |> DateTime.shift_zone!("Etc/UTC")

    defaults = [
      group_id: group.id,
      creator_id: creator.id,
      title: title,
      time_zone: time_zone,
      starts_at: starts_at,
      ends_at: DateTime.add(starts_at, 60, :minute),
      lifecycle_state: :published,
      is_private: !group.is_public
    ]

    defaults
    |> Keyword.merge(opts)
    |> past_huddl()
    |> generate()
  end
end
