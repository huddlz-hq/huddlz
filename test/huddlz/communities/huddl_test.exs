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
end
