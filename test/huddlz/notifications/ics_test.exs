defmodule Huddlz.Notifications.ICSTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.ICS

  setup do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    %{owner: owner, group: group}
  end

  defp build_huddl(ctx, opts) do
    base = [group_id: ctx.group.id, creator_id: ctx.owner.id, actor: ctx.owner]
    generate(huddl(Keyword.merge(base, opts)))
  end

  describe "event_for/1" do
    test "returns the expected filename", ctx do
      huddl = build_huddl(ctx, [])
      assert {"huddl.ics", _content} = ICS.event_for(huddl)
    end

    test "produced ics is a non-empty UTF-8 binary", ctx do
      huddl = build_huddl(ctx, [])
      {_filename, ics} = ICS.event_for(huddl)
      assert is_binary(ics)
      assert ics != ""
      assert String.valid?(ics)
    end

    test "ics carries the iCalendar envelope", ctx do
      huddl = build_huddl(ctx, [])
      {_filename, ics} = ICS.event_for(huddl)

      assert ics =~ "BEGIN:VCALENDAR"
      assert ics =~ "END:VCALENDAR"
      assert ics =~ "BEGIN:VEVENT"
      assert ics =~ "END:VEVENT"
      assert ics =~ "VERSION:2.0"
    end

    test "ics carries the huddl identity and timing", ctx do
      date = Date.add(Date.utc_today(), 30)
      start_time = ~T[14:00:00]

      huddl =
        build_huddl(ctx,
          title: "Coffee meetup",
          description: "Casual chat",
          date: date,
          start_time: start_time,
          duration_minutes: 90
        )

      {_filename, ics} = ICS.event_for(huddl)

      assert ics =~ "UID:huddl-#{huddl.id}@huddlz.com"
      assert ics =~ "SUMMARY:Coffee meetup"
      assert ics =~ "DTSTART:#{Calendar.strftime(huddl.starts_at, "%Y%m%dT%H%M%SZ")}"
      assert ics =~ "DTEND:#{Calendar.strftime(huddl.ends_at, "%Y%m%dT%H%M%SZ")}"
      assert ics =~ "Casual chat"
    end

    test "carries the authoritative instant as UTC across a daylight-saving boundary", ctx do
      group =
        generate(
          group(
            owner_id: ctx.owner.id,
            is_public: true,
            actor: ctx.owner,
            time_zone: "America/Los_Angeles"
          )
        )

      huddl =
        build_huddl(%{ctx | group: group},
          title: "Spring Forward Coffee",
          event_type: :virtual,
          virtual_link: "https://meet.example.com/spring-forward",
          date: ~D[2027-03-14],
          start_time: ~T[01:30:00],
          duration_minutes: 120
        )

      {_filename, ics} = ICS.event_for(huddl)

      assert ics =~ "DTSTART:20270314T093000Z"
      assert ics =~ "DTEND:20270314T113000Z"
      refute ics =~ "DTSTART;TZID="
      refute ics =~ "DTEND;TZID="

      assert [calendar_entry] = ICal.from_ics(ics).events
      assert DateTime.compare(calendar_entry.dtstart, huddl.starts_at) == :eq
      assert DateTime.compare(calendar_entry.dtend, huddl.ends_at) == :eq
    end

    test "physical location surfaces as LOCATION", ctx do
      venue =
        generate(
          group_location(
            group_id: ctx.group.id,
            actor: ctx.owner,
            name: "Roastery",
            address: "Roastery, 123 Main St"
          )
        )

      huddl =
        build_huddl(ctx,
          event_type: :in_person,
          physical_location: venue.address,
          group_location_id: venue.id
        )

      {_filename, ics} = ICS.event_for(huddl)
      assert ics =~ "Roastery"
    end

    test "virtual_link surfaces as URL and is mentioned in the description", ctx do
      link = "https://example.com/zoom/abc"

      huddl =
        build_huddl(ctx,
          event_type: :virtual,
          description: "Quick sync",
          virtual_link: link
        )

      {_filename, ics} = ICS.event_for(huddl)
      assert ics =~ "Quick sync"
      assert ics =~ link
    end

    test "round-trips through ICal.from_ics/1 back to a recognizable event", ctx do
      huddl =
        build_huddl(ctx,
          title: "Roundtrip Test",
          date: Date.add(Date.utc_today(), 45),
          start_time: ~T[09:00:00],
          duration_minutes: 60
        )

      {_filename, ics} = ICS.event_for(huddl)
      parsed = ICal.from_ics(ics)

      assert [event] = parsed.events
      assert event.summary == "Roundtrip Test"
      assert event.dtstart == huddl.starts_at
      assert event.dtend == huddl.ends_at
      assert event.uid == "huddl-#{huddl.id}@huddlz.com"
    end
  end
end
