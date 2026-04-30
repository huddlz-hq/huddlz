defmodule Huddlz.Notifications.Senders.RsvpCancelledTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.RsvpCancelled

  defp payload(overrides \\ %{}) do
    Map.merge(
      %{
        "huddl_id" => "00000000-0000-0000-0000-000000000001",
        "huddl_title" => "Saturday Soccer",
        "starts_at_iso" => "2026-05-10T15:00:00Z",
        "group_name" => "Pickup Sports",
        "group_slug" => "pickup-sports",
        "rsvper_display_name" => "Trinity"
      },
      overrides
    )
  end

  describe "build/2" do
    test "addresses the recipient with their display name" do
      user = generate(user(display_name: "Sam"))
      email = RsvpCancelled.build(user, payload())

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "to and from are correct" do
      user = generate(user())
      email = RsvpCancelled.build(user, payload())

      assert email.to == [{"", to_string(user.email)}]
      assert email.from == Mailer.from()
    end

    test "subject names the rsvper, frames the action as a cancellation, and names the huddl" do
      user = generate(user())
      email = RsvpCancelled.build(user, payload())

      assert email.subject == "Trinity cancelled their RSVP to Saturday Soccer"
      assert email.html_body =~ "Trinity"
      assert email.html_body =~ "cancelled their RSVP"
      assert email.html_body =~ "Saturday Soccer"
      assert email.html_body =~ "Pickup Sports"
    end

    test "links to the huddl page using the slug + id" do
      user = generate(user())

      email =
        RsvpCancelled.build(
          user,
          payload(%{
            "group_slug" => "pickup-sports",
            "huddl_id" => "abc123"
          })
        )

      assert email.html_body =~ "/groups/pickup-sports/huddlz/abc123"
      assert email.text_body =~ "/groups/pickup-sports/huddlz/abc123"
    end

    test "renders an unsubscribe footer (Activity)" do
      user = generate(user())
      email = RsvpCancelled.build(user, payload())

      assert email.html_body =~ "/unsubscribe/"
      assert email.html_body =~ "/profile/notifications"
      assert email.text_body =~ "/unsubscribe/"
    end

    test "html-escapes user-controlled strings" do
      user = generate(user(display_name: "<script>alert(1)</script>"))

      email =
        RsvpCancelled.build(
          user,
          payload(%{
            "huddl_title" => "<img src=x>",
            "group_name" => "<b>boom</b>",
            "rsvper_display_name" => "<u>raw</u>"
          })
        )

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>boom"
      refute email.html_body =~ "<u>raw"
      assert email.html_body =~ "&lt;script&gt;"
      assert email.html_body =~ "&lt;img"
    end

    test "leaves user-controlled strings raw in text_body" do
      user = generate(user(display_name: "Sam"))

      email = RsvpCancelled.build(user, payload(%{"huddl_title" => "Sat & Sun"}))

      assert email.text_body =~ "Sat & Sun"
      refute email.text_body =~ "<"
    end

    test "falls back when payload fields are missing" do
      user = generate(user())
      email = RsvpCancelled.build(user, %{})

      assert email.subject == "Someone cancelled their RSVP to your huddl"
    end
  end
end
