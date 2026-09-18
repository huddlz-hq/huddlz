defmodule DropInEmailsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions

  @joining_line "joining is how you hear about their next huddlz"

  step "the RSVP confirmation email to {string} says {string} hosts it and that joining is how to hear about its next huddlz",
       %{args: [email, group_name]} = context do
    sent = rsvp_confirmation!(email)

    assert sent.text_body =~ "Hosted by #{group_name}."
    assert sent.text_body =~ @joining_line
    assert sent.html_body =~ @joining_line
    context
  end

  step "the RSVP confirmation email to {string} does not suggest joining the group",
       %{args: [email]} = context do
    sent = rsvp_confirmation!(email)

    refute sent.text_body =~ @joining_line
    refute sent.html_body =~ @joining_line
    context
  end

  defp rsvp_confirmation!(email) do
    email
    |> emails_to()
    |> Enum.find(&(&1.subject =~ "You're going to")) ||
      flunk("no RSVP confirmation email reached #{email}")
  end

  # Delivers everything queued, then collects what reached one address.
  defp emails_to(email) do
    Oban.drain_queue(queue: :notifications)

    Stream.repeatedly(fn ->
      receive do
        {:email, sent} -> sent
      after
        0 -> nil
      end
    end)
    |> Enum.take_while(& &1)
    |> Enum.filter(fn sent -> Enum.any?(sent.to, fn {_name, to} -> to == email end) end)
  end
end
