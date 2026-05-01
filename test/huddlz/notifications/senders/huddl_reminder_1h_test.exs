defmodule Huddlz.Notifications.Senders.HuddlReminder1hTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HuddlReminder1h

  defp setup_huddl(attrs \\ %{}) do
    owner = generate(user(role: :user))

    group =
      generate(
        group(
          name: attrs[:group_name] || "Coffee Hour",
          slug: attrs[:group_slug] || "coffee-hour",
          is_public: true,
          owner_id: owner.id,
          actor: owner
        )
      )

    huddl_overrides = [
      title: attrs[:title] || "Morning Standup",
      group_id: group.id,
      creator_id: owner.id,
      event_type: :in_person,
      physical_location: "123 Main St, Anytown, USA",
      virtual_link: nil,
      actor: owner
    ]

    huddl_overrides =
      if Map.has_key?(attrs, :virtual_link) do
        huddl_overrides
        |> Keyword.put(:event_type, :virtual)
        |> Keyword.put(:virtual_link, attrs[:virtual_link])
        |> Keyword.put(:physical_location, nil)
      else
        huddl_overrides
      end

    generate(huddl(huddl_overrides))
  end

  describe "build/2" do
    test "subject frames it as starting soon" do
      user = generate(user())
      huddl = setup_huddl(%{title: "Morning Standup"})

      email = HuddlReminder1h.build(user, %{"huddl_id" => huddl.id})

      assert email.subject == "Starting soon: Morning Standup"
    end

    test "to and from are correct" do
      user = generate(user())
      huddl = setup_huddl()

      email = HuddlReminder1h.build(user, %{"huddl_id" => huddl.id})

      assert email.to == [{"", to_string(user.email)}]
      assert email.from == Mailer.from()
    end

    test "leads with the virtual link prominently when one is set" do
      user = generate(user())
      huddl = setup_huddl(%{virtual_link: "https://meet.example.com/abc-xyz"})

      email = HuddlReminder1h.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "Join the call"
      assert email.html_body =~ "https://meet.example.com/abc-xyz"
      assert email.text_body =~ "Join the call: https://meet.example.com/abc-xyz"
    end

    test "omits the join-call line for in-person huddlz" do
      user = generate(user())
      huddl = setup_huddl()

      email = HuddlReminder1h.build(user, %{"huddl_id" => huddl.id})

      refute email.html_body =~ "Join the call"
      refute email.text_body =~ "Join the call"
    end

    test "attaches an .ics calendar event" do
      user = generate(user())
      huddl = setup_huddl()

      email = HuddlReminder1h.build(user, %{"huddl_id" => huddl.id})

      assert [attachment] = email.attachments
      assert attachment.filename == "huddl.ics"
      assert attachment.content_type == "text/calendar"
    end

    test "includes the unsubscribe footer (activity)" do
      user = generate(user())
      huddl = setup_huddl()

      email = HuddlReminder1h.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "/unsubscribe/"
      assert email.text_body =~ "Unsubscribe"
    end
  end
end
