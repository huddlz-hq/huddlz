defmodule Huddlz.Notifications.Senders.PasswordChangedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.PasswordChanged

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      email = PasswordChanged.build(user, %{})

      assert email.html_body =~ "Hi Sam"
    end

    test "sends to the user's email" do
      user = generate(user(email: "alice@example.com"))
      email = PasswordChanged.build(user, %{})

      assert email.to == [{"", "alice@example.com"}]
    end

    test "uses the configured from-address" do
      user = generate(user())
      email = PasswordChanged.build(user, %{})

      assert {_name, "support@huddlz.com"} = email.from
    end

    test "includes a security notice and a reset link" do
      user = generate(user())
      email = PasswordChanged.build(user, %{})

      assert email.subject == "Your huddlz password was changed"
      assert email.html_body =~ "security notice"
      assert email.html_body =~ "wasn't"
      assert email.html_body =~ "/reset"
    end
  end
end
