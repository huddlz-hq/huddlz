defmodule Huddlz.Notifications.Senders.GroupMemberAddedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.GroupMemberAdded

  defp payload(overrides \\ %{}) do
    Map.merge(
      %{
        "group_id" => "group-1",
        "group_name" => "Inner Circle",
        "group_slug" => "inner-circle"
      },
      overrides
    )
  end

  describe "build/2" do
    test "addresses the added user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = GroupMemberAdded.build(user, payload())

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "subject and bodies name the group" do
      user = generate(user())
      email = GroupMemberAdded.build(user, payload())

      assert email.subject == "You're now a member of Inner Circle"
      assert email.html_body =~ "Inner Circle"
      assert email.text_body =~ "Inner Circle"
    end

    test "links to the group page using the slug" do
      user = generate(user())
      email = GroupMemberAdded.build(user, payload())

      assert email.html_body =~ "/groups/inner-circle"
      assert email.text_body =~ "/groups/inner-circle"
    end

    test "renders an unsubscribe footer (Activity)" do
      user = generate(user())
      email = GroupMemberAdded.build(user, payload())

      assert email.html_body =~ "/unsubscribe/"
      assert email.text_body =~ "/profile/notifications"
    end

    test "html-escapes user-controlled strings" do
      user = generate(user(display_name: "<script>x</script>"))
      email = GroupMemberAdded.build(user, payload(%{"group_name" => "<img src=x>"}))

      refute email.html_body =~ "<script>"
      assert email.html_body =~ "&lt;script&gt;"
      assert email.html_body =~ "&lt;img"
    end

    test "falls back when payload is empty" do
      user = generate(user())
      email = GroupMemberAdded.build(user, %{})

      assert email.subject == "You're now a member of a group"
    end
  end
end
