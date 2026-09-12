defmodule PendingEmailChangeSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import PhoenixTest

  step "I approve the email change from {string}", %{args: [recipient]} = context do
    context = open_link(context, recipient)
    session = click_button(context.session, "Approve email change")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I open the email-change link sent to {string}", %{args: [recipient]} = context do
    open_link(context, recipient)
  end

  step "I open the email-change link sent to {string} in a signed-out browser",
       %{args: [recipient]} = context do
    open_link(%{context | session: Phoenix.ConnTest.build_conn()}, recipient)
  end

  defp open_link(context, recipient) do
    Oban.drain_queue(queue: :notifications)

    email =
      receive do
        {:email,
         %Swoosh.Email{subject: "Approve your huddlz email change", to: [{"", ^recipient}]} =
             email} ->
          email
      after
        100 -> flunk("No email-change approval received for #{recipient}")
      end

    [url] =
      email.html_body
      |> Floki.parse_document!()
      |> Floki.find("a")
      |> Enum.filter(&(Floki.text(&1) == "Review email change"))
      |> Floki.attribute("href")

    session =
      (context[:session] || context.conn)
      |> visit(URI.parse(url).path)

    Map.merge(context, %{session: session, conn: session})
  end
end
