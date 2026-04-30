defmodule Huddlz.Notifications.Senders.GroupRoleChangedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.GroupRoleChanged

  defp payload(overrides \\ %{}) do
    Map.merge(
      %{
        "group_id" => "group-1",
        "group_name" => "Inner Circle",
        "group_slug" => "inner-circle",
        "previous_role" => "member",
        "new_role" => "organizer"
      },
      overrides
    )
  end

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = GroupRoleChanged.build(user, payload())

      assert email.html_body =~ "Hi Sam"
    end

    test "subject names the group; bodies state the role transition" do
      user = generate(user())
      email = GroupRoleChanged.build(user, payload())

      assert email.subject == "Your role in Inner Circle changed"
      assert email.html_body =~ "<strong>member</strong>"
      assert email.html_body =~ "<strong>organizer</strong>"
      assert email.text_body =~ "from member to organizer"
    end

    test "links to the group page using the slug" do
      user = generate(user())
      email = GroupRoleChanged.build(user, payload())

      assert email.html_body =~ "/groups/inner-circle"
    end

    test "renders an unsubscribe footer (Activity)" do
      user = generate(user())
      email = GroupRoleChanged.build(user, payload())

      assert email.html_body =~ "/unsubscribe/"
      assert email.text_body =~ "/profile/notifications"
    end

    test "html-escapes user-controlled strings" do
      user = generate(user(display_name: "<script>x</script>"))

      email =
        GroupRoleChanged.build(
          user,
          payload(%{"group_name" => "<img src=x>", "new_role" => "<b>boss</b>"})
        )

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>boss</b>"
      assert email.html_body =~ "&lt;script&gt;"
      assert email.html_body =~ "&lt;img"
      assert email.html_body =~ "&lt;b&gt;boss"
    end

    test "accepts atom roles in the payload" do
      user = generate(user())

      email =
        GroupRoleChanged.build(
          user,
          payload(%{"previous_role" => :member, "new_role" => :organizer})
        )

      assert email.html_body =~ "<strong>member</strong>"
      assert email.html_body =~ "<strong>organizer</strong>"
    end
  end
end
