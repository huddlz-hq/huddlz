defmodule SeriesCalendarUpdatesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import PhoenixTest

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl.RecurrenceHelper

  step "attendees hold different dates of a weekly series across daylight saving time", context do
    owner = generate(user(role: :user))

    group =
      generate(
        group(is_public: true, time_zone: "America/New_York", owner_id: owner.id, actor: owner)
      )

    source =
      generate(
        huddl(
          title: "Weekly calendar series",
          group_id: group.id,
          actor: owner,
          event_type: :virtual,
          virtual_link: "https://example.com/private-room",
          date: ~D[2030-10-27],
          start_time: ~T[18:00:00],
          duration_minutes: 60,
          is_recurring: true,
          frequency: "weekly",
          repeat_until: ~D[2030-11-18]
        )
      )

    Oban.drain_queue(queue: :default)

    [first, second, third] =
      source |> RecurrenceHelper.future_instances() |> Enum.sort_by(& &1.starts_at, DateTime)

    alice = generate(user())
    bob = generate(user())
    holdings = [{alice, [source, first, second]}, {bob, [second]}]

    for {attendee, huddlz} <- holdings, huddl <- huddlz do
      Communities.rsvp_huddl!(huddl, actor: attendee)
    end

    Oban.drain_queue(queue: :notifications)
    confirmations = emails()

    Map.merge(context, %{
      owner: owner,
      group: group,
      source: source,
      holdings: holdings,
      confirmations: confirmations,
      unheld: third
    })
  end

  step "other people have waitlisted, cancelled, or disabled series emails", context do
    [alice_holding | _] = context.holdings
    {alice, _} = alice_holding
    [cancelled_huddl | _] = RecurrenceHelper.future_instances(context.source)
    cancelled = generate(user())
    opted_out = generate(user(notification_preferences: %{"huddl_series_updated" => false}))
    waitlisted = generate(user())

    Communities.rsvp_huddl!(cancelled_huddl, actor: cancelled)
    Communities.cancel_rsvp_huddl!(cancelled_huddl, actor: cancelled)
    Communities.rsvp_huddl!(context.source, actor: opted_out)
    source = Communities.update_huddl!(context.source, %{max_attendees: 3}, actor: context.owner)

    another_opted_out =
      generate(user(notification_preferences: %{"huddl_series_updated" => false}))

    Communities.rsvp_huddl!(context.unheld, actor: opted_out)
    Communities.rsvp_huddl!(context.unheld, actor: another_opted_out)
    full = Communities.update_huddl!(context.unheld, %{max_attendees: 3}, actor: context.owner)
    Communities.join_waitlist_huddl!(full, actor: waitlisted)
    Communities.join_waitlist_huddl!(full, actor: alice)
    Oban.drain_queue(queue: :notifications)
    emails()

    Map.merge(context, %{
      source: source,
      waitlisted: waitlisted,
      opted_out: opted_out,
      cancelled: cancelled
    })
  end

  step "waitlisted people receive only a summary and opted-out people receive no email",
       context do
    assert email_for(context.updated_emails, context.waitlisted).attachments == []

    for attendee <- [context.opted_out, context.cancelled, context.owner] do
      refute Enum.any?(context.updated_emails, &(&1.to == [{"", to_string(attendee.email)}]))
    end

    context
  end

  step "the organizer moves the whole series one hour later", context do
    session =
      context.conn
      |> login(context.owner)
      |> visit("/groups/#{context.group.slug}/huddlz/#{context.source.id}/edit")
      |> click_button("Whole series")
      |> fill_in("Start time", with: "19:00", exact: false)
      |> click_button("Save changes")
      |> assert_has("#flash-info", text: "Huddl updated successfully!")

    Oban.drain_queue(queue: :notifications)
    Map.merge(context, %{session: session, updated_emails: emails()})
  end

  step "each attendee receives one series email with calendar entries for only their RSVPs",
       context do
    assert length(context.updated_emails) ==
             length(context.holdings) + if(context[:waitlisted], do: 1, else: 0)

    for {attendee, huddlz} <- context.holdings do
      email = email_for(context.updated_emails, attendee)
      assert email.subject == "Recurring series updated: Weekly calendar series"
      assert email.cc == []
      assert email.bcc == []
      assert length(email.attachments) == length(huddlz)
      assert length(Enum.uniq_by(email.attachments, & &1.filename)) == length(huddlz)

      entries =
        Enum.map(email.attachments, fn attachment ->
          assert attachment.content_type == "text/calendar"
          assert attachment.type == :attachment
          assert String.ends_with?(attachment.filename, ".ics")
          assert [entry] = ICal.from_ics(attachment.data).events
          refute attachment.data =~ "private-room"
          entry
        end)

      assert Enum.sort(Enum.map(entries, & &1.uid)) ==
               Enum.sort(Enum.map(huddlz, &"huddl-#{&1.id}@huddlz.com"))
    end

    context
  end

  step "each calendar entry keeps its original identity and the new local schedule", context do
    expected = %{
      ~D[2030-10-27] => ~U[2030-10-27 23:00:00Z],
      ~D[2030-11-03] => ~U[2030-11-04 00:00:00Z],
      ~D[2030-11-10] => ~U[2030-11-11 00:00:00Z]
    }

    for {attendee, _huddlz} <- context.holdings do
      original_entries =
        context.confirmations
        |> Enum.filter(&(&1.to == [{"", to_string(attendee.email)}]))
        |> Enum.flat_map(& &1.attachments)
        |> Enum.flat_map(&ICal.from_ics(&1.data).events)
        |> Map.new(&{&1.uid, &1})

      for attachment <- email_for(context.updated_emails, attendee).attachments do
        [entry] = ICal.from_ics(attachment.data).events
        original = Map.fetch!(original_entries, entry.uid)

        original_date =
          original.dtstart |> DateTime.shift_zone!("America/New_York") |> DateTime.to_date()

        assert entry.dtstart == Map.fetch!(expected, original_date)
        assert DateTime.diff(entry.dtend, entry.dtstart) == 3600

        assert DateTime.to_time(DateTime.shift_zone!(entry.dtstart, "America/New_York")) ==
                 ~T[19:00:00]

        assert DateTime.diff(DateTime.utc_now(), entry.dtstamp) in 0..30
      end
    end

    context
  end

  step "the organizer shortens the series to its first two dates", context do
    context.conn
    |> login(context.owner)
    |> visit("/groups/#{context.group.slug}/huddlz/#{context.source.id}/edit")
    |> click_button("Whole series")
    |> fill_in("Repeat until", with: "2030-11-04", exact: false)
    |> click_button("Save changes")
    |> assert_has("#flash-info", text: "Huddl updated successfully!")

    Oban.drain_queue(queue: :notifications)
    Map.put(context, :updated_emails, emails())
  end

  step "series attachments contain only retained dates and dropped dates have cancellation emails",
       context do
    for {attendee, held} <- context.holdings do
      series_emails =
        Enum.filter(
          context.updated_emails,
          &String.starts_with?(&1.subject, "Recurring series updated:")
        )

      entries =
        email_for(series_emails, attendee).attachments
        |> Enum.flat_map(&ICal.from_ics(&1.data).events)

      retained =
        Enum.filter(held, &(DateTime.compare(&1.starts_at, ~U[2030-11-05 00:00:00Z]) == :lt))

      assert Enum.sort(Enum.map(entries, & &1.uid)) ==
               Enum.sort(Enum.map(retained, &"huddl-#{&1.id}@huddlz.com"))

      assert Enum.any?(
               context.updated_emails,
               &(&1.to == [{"", to_string(attendee.email)}] and
                   String.starts_with?(&1.subject, "Cancelled:"))
             )
    end

    context
  end

  step "an attendee tries to edit the whole series", context do
    [{attendee, _} | _] = context.holdings

    result =
      Communities.update_huddl(
        context.source,
        %{
          start_time: ~T[19:00:00],
          edit_type: "all",
          frequency: "weekly",
          repeat_until: ~D[2030-11-18]
        },
        actor: attendee
      )

    Oban.drain_queue(queue: :notifications)
    Map.merge(context, %{edit_result: result, updated_emails: emails()})
  end

  step "the edit is forbidden and no update email is sent", context do
    assert {:error, %Ash.Error.Forbidden{}} = context.edit_result
    assert context.updated_emails == []
    context
  end

  defp email_for(emails, attendee) do
    assert [email] = Enum.filter(emails, &(&1.to == [{"", to_string(attendee.email)}]))
    email
  end

  defp emails(acc \\ []) do
    receive do
      {:email, email} -> emails([email | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
