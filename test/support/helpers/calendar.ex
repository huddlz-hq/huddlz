defmodule Huddlz.Test.Helpers.Calendar do
  @moduledoc false

  import Huddlz.Generator

  alias Huddlz.Calendar.Clock
  alias Huddlz.Communities

  def current_calendar_date(time_zone \\ "America/New_York") do
    Clock.utc_now()
    |> DateTime.shift_zone!(time_zone)
    |> DateTime.to_date()
  end

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

  def create_calendar_host_and_group do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    {host, group}
  end

  def create_calendar_huddl(group, creator, title, starts_at, opts \\ []) do
    defaults = [
      group_id: group.id,
      creator_id: creator.id,
      title: title,
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

  def create_personal_calendar_huddl(attendee, group, creator, title, starts_at, opts \\ []) do
    huddl = create_calendar_huddl(group, creator, title, starts_at, opts)
    Communities.rsvp_huddl!(huddl, actor: attendee)
    huddl
  end

  def create_today_huddl(group, creator, title, opts \\ []) do
    time_zone = "America/New_York"
    today = current_calendar_date(time_zone)
    starts_at = DateTime.new!(today, ~T[12:00:00], time_zone) |> DateTime.shift_zone!("Etc/UTC")

    calendar_opts =
      Keyword.merge(
        [
          time_zone: time_zone,
          ends_at: DateTime.add(starts_at, 60, :minute)
        ],
        opts
      )

    create_calendar_huddl(group, creator, title, starts_at, calendar_opts)
  end
end
