defmodule Huddlz.Communities.TimeZoneRequirementsTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities

  @tag issue403: true
  test "virtual huddlz derive the Group zone and reject caller-supplied zones" do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner))

    attrs = %{
      title: "Required time zone",
      date: Date.add(Date.utc_today(), 1),
      start_time: ~T[09:00:00],
      duration_minutes: 60,
      event_type: :virtual,
      virtual_link: "https://meet.example.com/required-zone",
      group_id: group.id,
      lifecycle_state: :published
    }

    assert {:ok, defaulted_huddl} =
             Communities.create_huddl(attrs, actor: owner)

    assert defaulted_huddl.time_zone == group.time_zone

    for submitted <- [nil, "US/Eastern", "America/Los_Angeles"] do
      assert {:error, error} =
               Communities.create_huddl(Map.put(attrs, :time_zone, submitted), actor: owner)

      assert Exception.message(error) =~ "time_zone"
    end
  end

  @tag issue403: true
  test "the migration leaves Group and huddl time zones required and fully backfilled" do
    [migration_path] =
      Path.wildcard(
        Path.expand("../../../priv/repo/migrations/*_calendar_time_zones.exs", __DIR__)
      )

    migration = File.read!(migration_path)

    assert migration =~
             "UPDATE groups SET time_zone = 'America/New_York' WHERE time_zone IS NULL"

    assert migration =~
             "UPDATE huddlz SET time_zone = 'America/New_York' WHERE time_zone IS NULL"

    result =
      Repo.query!("""
      SELECT table_name, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND column_name = 'time_zone'
        AND table_name IN ('groups', 'huddlz')
      ORDER BY table_name
      """)

    assert result.rows == [["groups", "NO"], ["huddlz", "NO"]]

    assert %{rows: [[0]]} =
             Repo.query!("""
             SELECT
               (SELECT COUNT(*) FROM groups WHERE time_zone IS NULL) +
               (SELECT COUNT(*) FROM huddlz WHERE time_zone IS NULL)
             """)
  end
end
