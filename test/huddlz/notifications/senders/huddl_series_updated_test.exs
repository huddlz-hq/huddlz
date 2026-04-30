defmodule Huddlz.Notifications.Senders.HuddlSeriesUpdatedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HuddlSeriesUpdated

  defp default_payload(overrides \\ %{}) do
    Map.merge(
      %{
        "huddl_id" => Ash.UUID.generate(),
        "huddl_title" => "Saturday Soccer",
        "starts_at_iso" => "2030-05-04T17:00:00Z",
        "group_name" => "Pickup Sports",
        "group_slug" => "pickup-sports",
        "changed_fields" => ["starts_at"]
      },
      overrides
    )
  end

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = HuddlSeriesUpdated.build(user, default_payload())

      assert email.html_body =~ "Hi Sam"
    end

    test "to and from are correct" do
      user = generate(user())
      email = HuddlSeriesUpdated.build(user, default_payload())

      assert email.to == [{"", to_string(user.email)}]
      assert email.from == Mailer.from()
    end

    test "subject says recurring series updated" do
      user = generate(user())

      email =
        HuddlSeriesUpdated.build(user, default_payload(%{"huddl_title" => "Saturday Soccer"}))

      assert email.subject == "Recurring series updated: Saturday Soccer"
    end

    test "names the next upcoming instance and notes future instances cover themselves" do
      user = generate(user())

      email =
        HuddlSeriesUpdated.build(
          user,
          default_payload(%{"huddl_title" => "Saturday Soccer", "group_name" => "Pickup Sports"})
        )

      assert email.html_body =~ "next upcoming instance"
      assert email.html_body =~ "Saturday Soccer"
      assert email.html_body =~ "Pickup Sports"
      assert email.html_body =~ "Future instances"
      assert email.html_body =~ "24-hour and 1-hour reminders"
    end

    test "humanizes the changed fields list" do
      user = generate(user())

      email =
        HuddlSeriesUpdated.build(
          user,
          default_payload(%{"changed_fields" => ["starts_at", "physical_location"]})
        )

      assert email.html_body =~ "the start time"
      assert email.html_body =~ "the location"
    end

    test "includes the unsubscribe footer (activity)" do
      user = generate(user())
      email = HuddlSeriesUpdated.build(user, default_payload())

      assert email.html_body =~ "/unsubscribe/"
    end

    test "html-escapes user-controlled strings in html_body" do
      user = generate(user(display_name: "<script>x</script>"))

      email =
        HuddlSeriesUpdated.build(
          user,
          default_payload(%{"huddl_title" => "<img src=x>", "group_name" => "<b>Boom</b>"})
        )

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>Boom"
      assert email.html_body =~ "&lt;script&gt;"
    end
  end
end
