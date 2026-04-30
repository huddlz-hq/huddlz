defmodule Huddlz.Notifications.Senders.GroupMemberJoinedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.GroupMemberJoined

  defp payload(overrides \\ %{}) do
    Map.merge(
      %{
        "group_id" => "group-1",
        "group_name" => "Cyberpunk Book Club",
        "group_slug" => "cyberpunk-book-club",
        "joiner_display_name" => "Trinity"
      },
      overrides
    )
  end

  describe "build/2" do
    test "addresses the recipient with their display name" do
      user = generate(user(display_name: "Sam"))
      email = GroupMemberJoined.build(user, payload())

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "subject names the joiner and the group" do
      user = generate(user())
      email = GroupMemberJoined.build(user, payload())

      assert email.subject == "Trinity joined Cyberpunk Book Club"
      assert email.html_body =~ "Trinity"
      assert email.html_body =~ "Cyberpunk Book Club"
    end

    test "links to the group page using the slug" do
      user = generate(user())
      email = GroupMemberJoined.build(user, payload())

      assert email.html_body =~ "/groups/cyberpunk-book-club"
      assert email.text_body =~ "/groups/cyberpunk-book-club"
    end

    test "renders an unsubscribe footer (Activity)" do
      user = generate(user())
      email = GroupMemberJoined.build(user, payload())

      assert email.html_body =~ "/unsubscribe/"
      assert email.html_body =~ "/profile/notifications"
      assert email.text_body =~ "/unsubscribe/"
    end

    test "html-escapes user-controlled strings" do
      user = generate(user(display_name: "<script>alert(1)</script>"))

      email =
        GroupMemberJoined.build(
          user,
          payload(%{
            "group_name" => "<img src=x>",
            "joiner_display_name" => "<b>raw</b>"
          })
        )

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>raw</b>"
      assert email.html_body =~ "&lt;script&gt;"
      assert email.html_body =~ "&lt;img"
      assert email.html_body =~ "&lt;b&gt;raw"
    end

    test "falls back when payload fields are missing" do
      user = generate(user())
      email = GroupMemberJoined.build(user, %{})

      assert email.subject == "Someone joined your group"
    end
  end
end
