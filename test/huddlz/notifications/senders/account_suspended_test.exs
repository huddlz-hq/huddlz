defmodule Huddlz.Notifications.Senders.AccountSuspendedTest do
  use ExUnit.Case, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.AccountSuspended

  test "identifies the account and suspension date with a working support contact" do
    user = %User{
      email: "person@example.com",
      suspended_at: ~U[2026-09-14 12:00:00Z]
    }

    email = AccountSuspended.build(user, %{})
    {_name, support} = Mailer.from()

    assert email.to == [{"", "person@example.com"}]
    assert email.from == Mailer.from()
    assert email.subject == "Your huddlz account has been suspended"
    assert email.html_body =~ "mailto:#{support}"

    for body <- [email.html_body, email.text_body] do
      assert body =~ "person@example.com"
      assert body =~ "Sep 14, 2026"
      assert body =~ support
      assert body =~ "upcoming RSVPs have been released"
      assert body =~ "Your groups and huddlz remain in place"
    end

    refute email.text_body =~ "<"
  end

  test "omits the profile name, moderation notes, reports and reporters from both bodies" do
    user = %User{
      email: "member&tag@example.com",
      display_name: "<script>spam_profile()</script>",
      suspension_reason: "Internal moderation notes",
      suspended_at: ~U[2026-09-14 12:00:00Z]
    }

    email =
      AccountSuspended.build(user, %{
        "reason" => "Internal moderation notes",
        "report" => "Private report text",
        "reporter" => "reporter@example.com"
      })

    assert email.html_body =~ "member&amp;tag@example.com"
    assert email.text_body =~ "member&tag@example.com"

    for body <- [email.subject, email.html_body, email.text_body],
        hidden <- [
          "spam_profile",
          "Internal moderation notes",
          "Private report text",
          "reporter@example.com"
        ] do
      refute body =~ hidden
    end

    refute email.text_body =~ "<"
  end
end
