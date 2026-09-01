defmodule AuthoritativeScheduleDeliverySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  alias Huddlz.Accounts
  alias Huddlz.Communities
  alias Huddlz.Notifications

  @date ~D[2027-05-04]

  step "my Display time zone is {string} for schedule delivery",
       %{args: [time_zone]} = context do
    recipient = generate(user(role: :user))
    recipient = Accounts.update_display_time_zone!(recipient, :fixed, time_zone, actor: recipient)

    Map.put(context, :recipient, recipient)
  end

  step "a huddl is scheduled for 9:00 AM in {string} for schedule delivery",
       %{args: [time_zone]} = context do
    setup_huddl(context, time_zone)
  end

  step "I receive its schedule email", context do
    :sent =
      Notifications.deliver_now(context.recipient, :rsvp_confirmation, %{
        "huddl_id" => context.huddl.id
      })

    Map.put(context, :email, receive_email!())
  end

  step "the email identifies 9:00 AM with the Pacific abbreviation", context do
    assert context.email.html_body =~ "9:00 AM PDT"
    assert context.email.text_body =~ "9:00 AM PDT"
    context
  end

  step "it contains one schedule time", context do
    assert Regex.scan(~r/\d{1,2}:\d{2} [AP]M [A-Z]{2,5}/, context.email.html_body)
           |> length() == 1

    context
  end

  step "a physical huddl is scheduled for 9:00 AM at a venue resolved to {string}",
       %{args: [time_zone]} = context do
    owner = generate(user(role: :user))
    recipient = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))

    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 37.77, -122.42 ->
      {:ok, time_zone}
    end)

    location =
      Communities.create_group_location!(
        "Pacific Coffee",
        "1 Market St, San Francisco, CA",
        37.77,
        -122.42,
        group.id,
        actor: owner
      )

    huddl =
      Communities.create_huddl!(
        %{
          title: "Pacific Morning Coffee",
          group_id: group.id,
          group_location_id: location.id,
          physical_location: location.address,
          event_type: :in_person,
          date: @date,
          start_time: ~T[09:00:00],
          duration_minutes: 90,
          time_zone: "America/New_York"
        },
        actor: owner
      )

    Map.merge(context, %{
      owner: owner,
      recipient: recipient,
      group: group,
      location: location,
      huddl: huddl,
      expected_time_zone: time_zone
    })
  end

  step "I receive its calendar attachment", context do
    :sent =
      Notifications.deliver_now(context.recipient, :rsvp_confirmation, %{
        "huddl_id" => context.huddl.id
      })

    email = receive_email!()
    assert [attachment] = email.attachments

    context
    |> Map.put(:email, email)
    |> Map.put(:attachment, attachment.data)
  end

  step "the physical huddl keeps the venue time zone and correct UTC instant", context do
    assert context.location.time_zone == context.expected_time_zone
    assert context.huddl.time_zone == context.expected_time_zone
    assert context.huddl.starts_at == ~U[2027-05-04 16:00:00Z]
    assert context.huddl.ends_at == ~U[2027-05-04 17:30:00Z]
    context
  end

  step "the attachment carries that schedule as UTC timestamps", context do
    assert context.attachment =~ "DTSTART:20270504T160000Z"
    assert context.attachment =~ "DTEND:20270504T173000Z"
    refute context.attachment =~ "DTSTART;TZID="
    refute context.attachment =~ "DTEND;TZID="
    context
  end

  step "its schedule resolves to the authoritative Huddl instant", context do
    calendar = ICal.from_ics(context.attachment)
    assert [calendar_entry] = calendar.events
    assert DateTime.compare(calendar_entry.dtstart, context.huddl.starts_at) == :eq
    assert DateTime.compare(calendar_entry.dtend, context.huddl.ends_at) == :eq
    context
  end

  defp setup_huddl(context, time_zone) do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: time_zone))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          title: "Pacific Morning Coffee",
          event_type: :virtual,
          virtual_link: "https://meet.example.com/pacific-coffee",
          time_zone: time_zone,
          date: @date,
          start_time: ~T[09:00:00],
          duration_minutes: 90
        )
      )

    Map.merge(context, %{owner: owner, group: group, huddl: huddl})
  end

  defp receive_email! do
    receive do
      {:email, %Swoosh.Email{} = email} -> email
    after
      100 -> flunk("expected a schedule email")
    end
  end
end
