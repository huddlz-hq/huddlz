defmodule Huddlz.Notifications.Senders.HuddlCancelledTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HuddlCancelled

  defp default_payload(overrides \\ %{}) do
    Map.merge(
      %{
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
      email = HuddlCancelled.build(user, default_payload())

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "to and from are correct" do
      user = generate(user())
      email = HuddlCancelled.build(user, default_payload())

      assert email.to == [{"", to_string(user.email)}]
      assert email.from == Mailer.from()
    end

    test "subject and bodies name the huddl" do
      user = generate(user())
      email = HuddlCancelled.build(user, default_payload(%{"huddl_title" => "Saturday Soccer"}))

      assert email.subject == "Cancelled: Saturday Soccer"
      assert email.html_body =~ "Saturday Soccer"
      assert email.text_body =~ "Saturday Soccer"
    end

    test "names the group and links to it" do
      user = generate(user())

      email =
        HuddlCancelled.build(
          user,
          default_payload(%{"group_name" => "Pickup Sports", "group_slug" => "pickup-sports"})
        )

      assert email.html_body =~ "Pickup Sports"
      assert email.html_body =~ "/groups/pickup-sports"
      assert email.text_body =~ "/groups/pickup-sports"
    end

    test "renders the original start time in a readable form" do
      user = generate(user())

      email =
        HuddlCancelled.build(user, default_payload(%{"starts_at_iso" => "2030-05-04T17:00:00Z"}))

      assert email.html_body =~ "May 4, 2030"
      assert email.text_body =~ "May 4, 2030"
    end

    test "no unsubscribe footer (transactional)" do
      user = generate(user())
      email = HuddlCancelled.build(user, default_payload())

      refute email.html_body =~ "unsubscribe"
      refute email.text_body =~ "unsubscribe"
    end

    test "html-escapes user-controlled strings in html_body" do
      user = generate(user(display_name: "<script>x</script>"))

      email =
        HuddlCancelled.build(
          user,
          default_payload(%{"huddl_title" => "<img src=x>", "group_name" => "<b>Boom</b>"})
        )

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>Boom"
      assert email.html_body =~ "&lt;script&gt;"
      assert email.html_body =~ "&lt;img"
      assert email.html_body =~ "&lt;b&gt;"
    end

    test "text body has no html tags" do
      user = generate(user())
      email = HuddlCancelled.build(user, default_payload())

      refute email.text_body =~ "<"
    end

    test "falls back gracefully when payload keys are missing" do
      user = generate(user())
      email = HuddlCancelled.build(user, %{})

      assert email.subject == "Cancelled: a huddl"
      assert email.html_body =~ "a huddl"
      assert email.html_body =~ "a group"
    end
  end
end
