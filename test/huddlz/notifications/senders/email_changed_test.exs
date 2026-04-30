defmodule Huddlz.Notifications.Senders.EmailChangedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.EmailChanged

  describe "build/2 - audience: old" do
    test "addresses the old email" do
      user = generate(user(email: "new@example.com", display_name: "Sam"))
      payload = %{"audience" => "old", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)

      assert email.to == [{"", "old@example.com"}]
    end

    test "subject and body call out the new address" do
      user = generate(user(email: "new@example.com"))
      payload = %{"audience" => "old", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)

      assert email.subject == "Your huddlz email address was changed"
      assert email.html_body =~ "new@example.com"
      assert email.html_body =~ "security notice"
    end

    test "includes a password reset link" do
      user = generate(user(email: "new@example.com"))
      payload = %{"audience" => "old", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)

      assert email.html_body =~ "/reset"
      assert email.text_body =~ "/reset"
    end

    test "uses the configured from-address" do
      user = generate(user())
      payload = %{"audience" => "old", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)
      assert {_name, "support@huddlz.com"} = email.from
    end

    test "addresses the user by display name" do
      user = generate(user(display_name: "Pat"))
      payload = %{"audience" => "old", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)
      assert email.html_body =~ "Hi Pat"
      assert email.text_body =~ "Hi Pat"
    end

    test "html-escapes the display name" do
      user = generate(user(display_name: "<script>alert(1)</script>"))
      payload = %{"audience" => "old", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)
      refute email.html_body =~ "<script>alert"
      assert email.html_body =~ "&lt;script&gt;"
    end

    test "text body has no html tags" do
      user = generate(user())
      payload = %{"audience" => "old", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)
      refute email.text_body =~ "<"
    end
  end

  describe "build/2 - audience: new" do
    test "addresses the new email (user.email)" do
      user = generate(user(email: "new@example.com"))
      payload = %{"audience" => "new", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)

      assert email.to == [{"", "new@example.com"}]
    end

    test "body references the previous address" do
      user = generate(user(email: "new@example.com"))
      payload = %{"audience" => "new", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)

      assert email.subject == "Your huddlz email address was changed"
      assert email.html_body =~ "now associated"
      assert email.html_body =~ "old@example.com"
    end

    test "does NOT include a password reset link in the new-address email" do
      # The reset link is for someone hijacked: it goes to the OLD address
      # so the legitimate owner can recover. The new address doesn't need it.
      user = generate(user(email: "new@example.com"))
      payload = %{"audience" => "new", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)

      refute email.html_body =~ "/reset"
    end

    test "html-escapes the previous email" do
      user = generate(user(email: "new@example.com"))
      payload = %{"audience" => "new", "old_email" => "<script>old</script>@example.com"}

      email = EmailChanged.build(user, payload)
      refute email.html_body =~ "<script>old"
      assert email.html_body =~ "&lt;script&gt;"
    end

    test "text body has no html tags" do
      user = generate(user(email: "new@example.com"))
      payload = %{"audience" => "new", "old_email" => "old@example.com"}

      email = EmailChanged.build(user, payload)
      refute email.text_body =~ "<"
    end
  end
end
