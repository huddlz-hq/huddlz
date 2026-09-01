defmodule Huddlz.Notifications.Senders.HuddlReminder24hTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HuddlReminder24h

  defp setup_huddl(attrs \\ %{}) do
    owner = generate(user(role: :user))

    group =
      generate(
        group(
          name: attrs[:group_name] || "Pickup Sports",
          slug: attrs[:group_slug] || "pickup-sports",
          is_public: true,
          owner_id: owner.id,
          actor: owner
        )
      )

    huddl =
      generate(
        huddl(
          title: attrs[:title] || "Saturday Soccer",
          group_id: group.id,
          creator_id: owner.id,
          time_zone: attrs[:time_zone] || "Etc/UTC",
          date: attrs[:date] || Date.add(Date.utc_today(), 1),
          start_time: attrs[:start_time] || ~T[14:00:00],
          duration_minutes: attrs[:duration_minutes] || 60,
          actor: owner
        )
      )

    huddl
  end

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      huddl = setup_huddl()

      email = HuddlReminder24h.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "to and from are correct" do
      user = generate(user())
      huddl = setup_huddl()

      email = HuddlReminder24h.build(user, %{"huddl_id" => huddl.id})

      assert email.to == [{"", to_string(user.email)}]
      assert email.from == Mailer.from()
    end

    test "subject names the huddl and frames it as tomorrow" do
      user = generate(user())
      huddl = setup_huddl(%{title: "Saturday Soccer"})

      email = HuddlReminder24h.build(user, %{"huddl_id" => huddl.id})

      assert email.subject == "Tomorrow: Saturday Soccer"
    end

    test "body links to the huddl and names the group" do
      user = generate(user())

      huddl =
        setup_huddl(%{
          title: "Saturday Soccer",
          group_name: "Pickup Sports",
          group_slug: "pickup-sports"
        })

      email = HuddlReminder24h.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "Saturday Soccer"
      assert email.html_body =~ "Pickup Sports"
      assert email.html_body =~ "/groups/pickup-sports/huddlz/#{huddl.id}"
    end

    test "attaches an .ics calendar event" do
      user = generate(user())
      huddl = setup_huddl()

      email = HuddlReminder24h.build(user, %{"huddl_id" => huddl.id})

      assert [attachment] = email.attachments
      assert attachment.filename == "huddl.ics"
      assert attachment.content_type == "text/calendar"
      assert attachment.data =~ "BEGIN:VCALENDAR"
    end

    test "formats the schedule in the authoritative huddl time zone" do
      user = generate(user())

      huddl =
        setup_huddl(%{
          time_zone: "America/Los_Angeles",
          date: ~D[2030-05-04],
          start_time: ~T[09:00:00]
        })

      email =
        HuddlReminder24h.build(user, %{
          "huddl_id" => huddl.id,
          "time_zone" => "America/New_York"
        })

      assert email.html_body =~ "May 4, 2030 at 9:00 AM PDT"
      refute email.html_body =~ "EDT"
    end

    test "includes the unsubscribe footer (activity)" do
      user = generate(user())
      huddl = setup_huddl()

      email = HuddlReminder24h.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "/unsubscribe/"
      assert email.text_body =~ "Unsubscribe"
    end

    test "html-escapes user-controlled strings in html_body" do
      user = generate(user(display_name: "<script>x</script>"))
      huddl = setup_huddl(%{title: "<img src=x>", group_name: "<b>Boom</b>"})

      email = HuddlReminder24h.build(user, %{"huddl_id" => huddl.id})

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>Boom"
      assert email.html_body =~ "&lt;script&gt;"
    end
  end
end
