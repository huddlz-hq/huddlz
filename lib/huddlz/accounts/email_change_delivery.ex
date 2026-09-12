defmodule Huddlz.Accounts.EmailChangeDelivery do
  @moduledoc "Delivers approval mail to the exact inbox captured by the request."
  use Oban.Worker, queue: :notifications, max_attempts: 5

  alias Huddlz.Notifications.{Footer, Layout}

  @impl true
  def perform(%Oban.Job{args: args}) do
    url = HuddlzWeb.Endpoint.url() <> "/email-change/" <> args["token"]

    email =
      Layout.email(%{
        to: args["to"],
        subject: "Approve your huddlz email change",
        title: "Approve your email change",
        paragraphs: [
          "A change was requested from #{args["old_email"]} to #{args["new_email"]}.",
          "Both inboxes must approve. Until then, your current sign-in and recovery address stays the same. This request expires after three days.",
          [
            "If you did not request this, ",
            {:link, "report and cancel this request", url},
            " and secure your account."
          ]
        ],
        action: {"Review email change", url},
        footer: Footer.account()
      })

    case Huddlz.Mailer.deliver(email) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
