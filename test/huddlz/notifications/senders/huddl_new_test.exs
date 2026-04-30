defmodule Huddlz.Notifications.Senders.HuddlNewTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HuddlNew

  defp default_payload(overrides \\ %{}) do
    Map.merge(
      %{
        "huddl_id" => Ash.UUID.generate(),
        "huddl_title" => "Saturday Soccer",
        "starts_at_iso" => "2030-05-04T17:00:00Z",
        "group_name" => "Pickup Sports",
        "group_slug" => "pickup-sports"
      },
      overrides
    )
  end

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = HuddlNew.build(user, default_payload())

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "to and from are correct" do
      user = generate(user())
      email = HuddlNew.build(user, default_payload())

      assert email.to == [{"", to_string(user.email)}]
      assert email.from == Mailer.from()
    end

    test "subject names the group and the huddl" do
      user = generate(user())

      email =
        HuddlNew.build(
          user,
          default_payload(%{"group_name" => "Pickup Sports", "huddl_title" => "Saturday Soccer"})
        )

      assert email.subject == "New huddl in Pickup Sports: Saturday Soccer"
    end

    test "body links to the huddl page" do
      user = generate(user())
      huddl_id = Ash.UUID.generate()

      email =
        HuddlNew.build(
          user,
          default_payload(%{"huddl_id" => huddl_id, "group_slug" => "pickup-sports"})
        )

      assert email.html_body =~ "/groups/pickup-sports/huddlz/#{huddl_id}"
      assert email.text_body =~ "/groups/pickup-sports/huddlz/#{huddl_id}"
    end

    test "renders the start time in a readable form" do
      user = generate(user())
      email = HuddlNew.build(user, default_payload(%{"starts_at_iso" => "2030-05-04T17:00:00Z"}))

      assert email.html_body =~ "May 4, 2030"
    end

    test "includes the unsubscribe footer (activity)" do
      user = generate(user())
      email = HuddlNew.build(user, default_payload())

      assert email.html_body =~ "/unsubscribe/"
      assert email.text_body =~ "Unsubscribe"
    end

    test "html-escapes user-controlled strings in html_body" do
      user = generate(user(display_name: "<script>x</script>"))

      email =
        HuddlNew.build(
          user,
          default_payload(%{"huddl_title" => "<img src=x>", "group_name" => "<b>Boom</b>"})
        )

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>Boom"
      assert email.html_body =~ "&lt;script&gt;"
    end

    test "falls back gracefully when payload keys are missing" do
      user = generate(user())
      email = HuddlNew.build(user, %{})

      assert email.subject =~ "a new huddl"
      assert email.html_body =~ "a group"
    end
  end
end
