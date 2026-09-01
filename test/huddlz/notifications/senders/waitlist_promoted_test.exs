defmodule Huddlz.Notifications.Senders.WaitlistPromotedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.WaitlistPromoted

  setup do
    owner = generate(user(role: :user))
    recipient = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/Los_Angeles"))

    huddl =
      generate(
        huddl(
          title: "Pacific Morning Coffee",
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          time_zone: "America/Los_Angeles",
          date: ~D[2030-05-04],
          start_time: ~T[09:00:00],
          duration_minutes: 60
        )
      )

    %{huddl: huddl, recipient: recipient}
  end

  test "addresses the recipient and explains the promotion", context do
    email = WaitlistPromoted.build(context.recipient, %{"huddl_id" => context.huddl.id})

    assert email.html_body =~ "Hi #{context.recipient.display_name}"
    assert email.to == [{"", to_string(context.recipient.email)}]
    assert email.from == Mailer.from()
    assert email.subject == "You're in: Pacific Morning Coffee"
    assert email.html_body =~ "promoted from the"
    refute email.text_body =~ "<"
  end

  test "escapes user-controlled strings in the HTML body", context do
    unsafe_recipient = %{context.recipient | display_name: "<script>x</script>"}
    email = WaitlistPromoted.build(unsafe_recipient, %{"huddl_id" => context.huddl.id})

    refute email.html_body =~ "<script>"
    assert email.html_body =~ "&lt;script&gt;"
  end

  test "formats the schedule in the authoritative huddl time zone", context do
    email =
      WaitlistPromoted.build(context.recipient, %{
        "huddl_id" => context.huddl.id,
        "time_zone" => "America/New_York"
      })

    assert email.html_body =~ "May 4, 2030 at 9:00 AM PDT"
    refute email.html_body =~ "EDT"
  end
end
