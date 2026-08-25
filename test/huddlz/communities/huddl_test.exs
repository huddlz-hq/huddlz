defmodule Huddlz.Communities.HuddlTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Huddl

  describe "time_zone resolution" do
    test "defaults to Etc/UTC for an in-person huddl whose address can't be geocoded" do
      # GeocodingStub returns {:error, :not_found} by default; the generator's
      # group also gets no coordinates, so there's nothing to inherit either.
      huddl = generate(huddl())
      assert huddl.time_zone == "Etc/UTC"
    end

    test "is geo-derived from the huddl's own geocoded physical_location" do
      stub_geocode(%{latitude: 30.27, longitude: -97.74})

      huddl = generate(huddl())
      assert huddl.time_zone == "America/Chicago"
    end

    test "an explicit time_zone override is kept even when the location is geocoded" do
      stub_geocode(%{latitude: 30.27, longitude: -97.74})

      huddl = generate(huddl(time_zone: "America/New_York"))

      assert huddl.time_zone == "America/New_York"
    end

    test "a virtual huddl with no browser timezone falls back to the group's time_zone" do
      stub_geocode(%{latitude: 30.27, longitude: -97.74})
      owner = generate(user(role: :user))

      group = generate(group(owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            event_type: :virtual,
            physical_location: nil,
            virtual_link: "https://example.com/meet"
          )
        )

      assert huddl.time_zone == group.time_zone
    end

    test "a virtual huddl with no location and no group time_zone falls back to the browser-detected zone" do
      owner = generate(user(role: :user))

      group = generate(group(owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            event_type: :virtual,
            physical_location: nil,
            virtual_link: "https://example.com/meet",
            browser_time_zone: "America/Denver"
          )
        )

      assert huddl.time_zone == "America/Denver"
    end

    test "update re-derives time_zone when physical_location changes to a new geocoded address" do
      stub_geocode(%{latitude: 30.27, longitude: -97.74})
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      huddl = generate(huddl(group_id: group.id, actor: owner))
      assert huddl.time_zone == "America/Chicago"

      stub_geocode(%{latitude: 29.89, longitude: -81.31})

      {:ok, updated} =
        Huddl
        |> Ash.get!(huddl.id, authorize?: false)
        |> Ash.Changeset.for_update(:update, %{physical_location: "Saint Augustine, FL"},
          actor: owner
        )
        |> Ash.update()

      assert updated.time_zone == "America/New_York"
    end

    test "update keeps an explicit time_zone even when physical_location changes" do
      stub_geocode(%{latitude: 30.27, longitude: -97.74})
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      huddl = generate(huddl(group_id: group.id, actor: owner))

      stub_geocode(%{latitude: 29.89, longitude: -81.31})

      {:ok, updated} =
        Huddl
        |> Ash.get!(huddl.id, authorize?: false)
        |> Ash.Changeset.for_update(
          :update,
          %{physical_location: "Saint Augustine, FL", time_zone: "America/Denver"},
          actor: owner
        )
        |> Ash.update()

      assert updated.time_zone == "America/Denver"
    end

    test "update that touches neither location nor time_zone leaves it unchanged" do
      stub_geocode(%{latitude: 30.27, longitude: -97.74})
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      huddl = generate(huddl(group_id: group.id, actor: owner))

      {:ok, updated} =
        Huddl
        |> Ash.get!(huddl.id, authorize?: false)
        |> Ash.Changeset.for_update(:update, %{title: "Renamed"}, actor: owner)
        |> Ash.update()

      assert updated.time_zone == huddl.time_zone
    end
  end

  describe "wall-time conversion" do
    test "interprets date/start_time as wall time in the resolved time_zone, not UTC" do
      owner = generate(user(role: :user))

      group = generate(group(owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            time_zone: "America/Los_Angeles",
            date: ~D[2030-06-15],
            start_time: ~T[19:00:00],
            duration_minutes: 60
          )
        )

      # 7:00 PM PDT (UTC-7 in June) == 2:00 AM UTC the next day.
      assert huddl.starts_at == ~U[2030-06-16 02:00:00Z]
    end
  end

  describe "daylight saving transitions" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "a start time inside a spring-forward gap is a field error, not a crash", %{
      owner: owner,
      group: group
    } do
      # 2:30 AM on 2027-03-14 never happens in America/New_York: the clocks
      # jump from 2:00 to 3:00 EDT.
      assert {:error, %Ash.Error.Invalid{} = error} =
               create_huddl(group, owner, ~D[2027-03-14], ~T[02:30:00])

      assert Enum.any?(error.errors, &(Map.get(&1, :field) == :start_time))
      assert Exception.message(error) =~ "the clocks change"
    end

    test "an ambiguous fall-back start time resolves to the earlier instant", %{
      owner: owner,
      group: group
    } do
      # 1:30 AM on 2027-11-07 happens twice in America/New_York: once at
      # 05:30 UTC (EDT, still -4) and again at 06:30 UTC (EST, -5).
      assert {:ok, huddl} = create_huddl(group, owner, ~D[2027-11-07], ~T[01:30:00])

      assert huddl.starts_at == ~U[2027-11-07 05:30:00Z]
      assert huddl.time_zone == "America/New_York"
    end

    defp create_huddl(group, owner, date, start_time) do
      Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Clock change huddl",
          description: "Scheduled across a daylight saving transition.",
          group_id: group.id,
          event_type: :virtual,
          virtual_link: "https://example.com/meet",
          time_zone_selection: "America/New_York",
          date: date,
          start_time: start_time,
          duration_minutes: 60,
          lifecycle_state: :published
        },
        actor: owner
      )
      |> Ash.create()
    end
  end
end
