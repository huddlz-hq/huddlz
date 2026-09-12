defmodule Huddlz.Accounts.EmailChangeDeliveryTest do
  use ExUnit.Case, async: true

  alias Huddlz.Accounts.EmailChangeDelivery
  alias Huddlz.Mailer
  alias HuddlzWeb.Endpoint

  for recipient <- ["old@example.com", "new@example.com"] do
    @recipient recipient

    test "delivers a complete approval message to #{recipient}" do
      args = %{
        "to" => @recipient,
        "old_email" => "old@example.com",
        "new_email" => "new@example.com",
        "token" => "approval-token"
      }

      assert :ok = EmailChangeDelivery.perform(%Oban.Job{args: args})
      assert_receive {:email, %Swoosh.Email{} = email}

      assert email.to == [{"", @recipient}]
      assert email.from == Mailer.from()
      assert email.subject == "Approve your huddlz email change"

      url = Endpoint.url() <> "/email-change/approval-token"

      for body <- [email.html_body, email.text_body] do
        assert body =~ "old@example.com"
        assert body =~ "new@example.com"
        assert body =~ "Both inboxes must approve"
        assert body =~ "your current sign-in and recovery address stays the same"
        assert body =~ "expires after three days"
        assert body =~ "report and cancel this request"
        assert body =~ url
        assert body =~ "You're receiving this email because it concerns your huddlz account."
        refute body =~ "unsubscribe"
      end

      assert email.text_body =~ "Review email change: #{url}"
      refute email.text_body =~ "<"

      links = email.html_body |> Floki.parse_document!() |> Floki.find("a")

      for label <- ["Review email change", "report and cancel this request"] do
        assert links
               |> Enum.filter(&(Floki.text(&1) == label))
               |> Floki.attribute("href") == [url]
      end
    end
  end

  test "escapes both request addresses in HTML" do
    args = %{
      "to" => "recipient@example.com",
      "old_email" => "<script>old</script>@example.com",
      "new_email" => "<script>new</script>@example.com",
      "token" => "approval-token"
    }

    assert :ok = EmailChangeDelivery.perform(%Oban.Job{args: args})
    assert_receive {:email, %Swoosh.Email{} = email}

    refute email.html_body =~ "<script>"
    assert email.html_body =~ "&lt;script&gt;old&lt;/script&gt;@example.com"
    assert email.html_body =~ "&lt;script&gt;new&lt;/script&gt;@example.com"
  end
end
