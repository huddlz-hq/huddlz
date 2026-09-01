defmodule AuthoritativeScheduleDeliverySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  alias Huddlz.Accounts
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

  step "a huddl is scheduled in {string} for calendar export",
       %{args: [time_zone]} = context do
    recipient = generate(user(role: :user))

    context
    |> Map.put(:recipient, recipient)
    |> setup_huddl(time_zone)
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

  step "the attachment uses the Huddl TZID", context do
    assert context.attachment =~ "DTSTART;TZID=#{context.huddl.time_zone}:20270504T090000"
    assert context.attachment =~ "DTEND;TZID=#{context.huddl.time_zone}:20270504T103000"
    context
  end

  step "it includes a matching VTIMEZONE", context do
    assert context.attachment =~ "BEGIN:VTIMEZONE"
    assert context.attachment =~ "TZID:#{context.huddl.time_zone}"
    assert context.attachment =~ "END:VTIMEZONE"
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
