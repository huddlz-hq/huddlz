defmodule Huddlz.Notifications.Senders.AccountRoleChangedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications
  alias Huddlz.Notifications.Senders.AccountRoleChanged

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = AccountRoleChanged.build(user, %{"new_role" => "admin"})

      assert email.html_body =~ "Hi Sam"
    end

    test "sends to the user's email" do
      user = generate(user(email: "alice@example.com"))
      email = AccountRoleChanged.build(user, %{"new_role" => "admin"})

      assert email.to == [{"", "alice@example.com"}]
    end

    test "uses the configured from-address" do
      user = generate(user())
      email = AccountRoleChanged.build(user, %{"new_role" => "admin"})

      assert {_name, "support@huddlz.com"} = email.from
    end

    test "names the new role in the subject and body" do
      user = generate(user(role: :admin))

      email =
        AccountRoleChanged.build(user, %{
          "new_role" => "admin",
          "previous_role" => "user"
        })

      assert email.subject == "Your huddlz account role was updated"
      assert email.html_body =~ "admin"
      assert email.html_body =~ "from <strong>user</strong> to <strong>admin</strong>"
    end

    test "omits the 'from X' phrasing when previous_role is missing" do
      user = generate(user(role: :admin))
      email = AccountRoleChanged.build(user, %{"new_role" => "admin"})

      refute email.html_body =~ ~r{from <strong>}
      assert email.html_body =~ "to <strong>admin</strong>"
    end

    test "includes a working unsubscribe link in both bodies" do
      user = generate(user())
      email = AccountRoleChanged.build(user, %{"new_role" => "admin"})

      assert email.html_body =~ "/unsubscribe/"
      assert email.text_body =~ "/unsubscribe/"

      [_full, token] = Regex.run(~r{/unsubscribe/([^"\s]+)}, email.html_body)

      assert {:ok, {user_id, :account_role_changed}} =
               Notifications.verify_unsubscribe_token(token)

      assert user_id == user.id
    end

    test "includes a link to the notification settings page" do
      user = generate(user())
      email = AccountRoleChanged.build(user, %{"new_role" => "admin"})

      assert email.html_body =~ "/profile/notifications"
      assert email.text_body =~ "/profile/notifications"
    end

    test "includes a plain-text body alongside the html body" do
      user = generate(user(display_name: "Pat"))

      email =
        AccountRoleChanged.build(user, %{
          "new_role" => "admin",
          "previous_role" => "user"
        })

      assert email.text_body =~ "Hi Pat"
      assert email.text_body =~ "from user to admin"
      refute email.text_body =~ "<"
    end

    test "html-escapes the display name to prevent injection" do
      user = generate(user(display_name: "<script>alert(1)</script>"))
      email = AccountRoleChanged.build(user, %{"new_role" => "admin"})

      refute email.html_body =~ "<script>alert"
      assert email.html_body =~ "&lt;script&gt;"
    end
  end
end
