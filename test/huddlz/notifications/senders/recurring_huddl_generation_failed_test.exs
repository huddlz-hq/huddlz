defmodule Huddlz.Notifications.Senders.RecurringHuddlGenerationFailedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.RecurringHuddlGenerationFailed

  test "tells the organizer which recurring huddl needs attention" do
    user = generate(user(display_name: "Sam"))

    email =
      RecurringHuddlGenerationFailed.build(user, %{
        "huddl_id" => "00000000-0000-0000-0000-000000000000",
        "huddl_title" => "Weekly Workshop",
        "group_name" => "Austin Elixir",
        "group_slug" => "austin-elixir"
      })

    assert email.subject == "Recurring dates need attention: Weekly Workshop"
    assert email.html_body =~ "Hi Sam"
    assert email.html_body =~ "Weekly Workshop"
    assert email.html_body =~ "Austin Elixir"
    assert email.text_body =~ "/groups/austin-elixir/huddlz/00000000-0000-0000-0000-000000000000"
  end

  test "escapes organizer-controlled content" do
    user = generate(user(display_name: "<script>x</script>"))

    email =
      RecurringHuddlGenerationFailed.build(user, %{
        "huddl_title" => "<img src=x>",
        "group_name" => "<strong>Group</strong>"
      })

    refute email.html_body =~ "<script>"
    refute email.html_body =~ "<img src=x"
    assert email.html_body =~ "&lt;script&gt;"
    assert email.html_body =~ "&lt;img"
  end
end
