defmodule Huddlz.Notifications.Senders.GroupArchivedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.GroupArchived

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = GroupArchived.build(user, %{"group_name" => "Doomed Group"})

      assert email.html_body =~ "Hi Sam"
    end

    test "subject and bodies name the group" do
      user = generate(user())
      email = GroupArchived.build(user, %{"group_name" => "Doomed Group"})

      assert email.subject == "Doomed Group has been deleted"
      assert email.html_body =~ "Doomed Group"
      assert email.text_body =~ "Doomed Group"
    end

    test "no unsubscribe footer (transactional)" do
      user = generate(user())
      email = GroupArchived.build(user, %{"group_name" => "X"})

      refute email.html_body =~ "unsubscribe"
      refute email.text_body =~ "unsubscribe"
    end

    test "html-escapes user-controlled strings" do
      user = generate(user(display_name: "<script>x</script>"))
      email = GroupArchived.build(user, %{"group_name" => "<img src=x>"})

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      assert email.html_body =~ "&lt;script&gt;"
      assert email.html_body =~ "&lt;img"
    end

    test "falls back when group_name is missing" do
      user = generate(user())
      email = GroupArchived.build(user, %{})

      assert email.subject == "a group has been deleted"
    end
  end
end
