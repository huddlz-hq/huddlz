defmodule Huddlz.Notifications.Senders.GroupMemberRemovedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.GroupMemberRemoved

  describe "build/2" do
    test "addresses the removed user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = GroupMemberRemoved.build(user, %{"group_name" => "Cyberpunk Book Club"})

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "names the group in the subject and bodies" do
      user = generate(user())
      email = GroupMemberRemoved.build(user, %{"group_name" => "Cyberpunk Book Club"})

      assert email.subject == "You were removed from Cyberpunk Book Club"
      assert email.html_body =~ "Cyberpunk Book Club"
      assert email.text_body =~ "Cyberpunk Book Club"
    end

    test "sends to the user's email" do
      user = generate(user(email: "removed@example.com"))
      email = GroupMemberRemoved.build(user, %{"group_name" => "X"})

      assert email.to == [{"", "removed@example.com"}]
    end

    test "uses the configured from-address" do
      user = generate(user())
      email = GroupMemberRemoved.build(user, %{"group_name" => "X"})

      assert {_name, "support@huddlz.com"} = email.from
    end

    test "does not include an unsubscribe footer (transactional)" do
      user = generate(user())
      email = GroupMemberRemoved.build(user, %{"group_name" => "X"})

      refute email.html_body =~ "unsubscribe"
      refute email.text_body =~ "unsubscribe"
    end

    test "html-escapes user-controlled strings" do
      user = generate(user(display_name: "<script>x</script>"))

      email =
        GroupMemberRemoved.build(user, %{"group_name" => "<img src=x onerror=alert(1)>"})

      refute email.html_body =~ "<script>"
      assert email.html_body =~ "&lt;script&gt;"
      refute email.html_body =~ "<img src=x"
      assert email.html_body =~ "&lt;img"
    end

    test "falls back gracefully when group_name is missing from the payload" do
      user = generate(user())
      email = GroupMemberRemoved.build(user, %{})

      assert email.subject == "You were removed from a group"
    end
  end
end
