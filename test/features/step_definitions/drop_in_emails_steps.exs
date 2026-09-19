defmodule DropInEmailsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl}

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

  step "{string} completes", %{args: [title]} = context do
    complete!(title)
    context
  end

  step "{string} is cancelled by its organizer", %{args: [title]} = context do
    huddl = find_huddl(title) |> Ash.load!([group: :owner], authorize?: false)
    Communities.cancel_huddl!(huddl, nil, actor: huddl.group.owner)
    context
  end

  step "a day passes", context do
    a_day_passes()
    context
  end

  step "{string} chose not now for {string}", %{args: [email, group_name]} = context do
    Communities.dismiss_join_suggestion!(find_group(group_name).id, actor: find_user(email))
    context
  end

  step "{string} turned off suggestions to join groups they've dropped in on",
       %{args: [email]} = context do
    user = find_user(email)

    user
    |> Ash.Changeset.for_update(
      :update_notification_preferences,
      %{preferences: %{"group_join_suggestion" => false}},
      actor: user
    )
    |> Ash.update!()

    context
  end

  step "{string} was emailed the suggestion to join {string} after {string}",
       %{args: [email, group_name, title]} = context do
    Communities.rsvp_huddl!(find_huddl(title), actor: find_user(email))
    complete!(title)
    a_day_passes()
    assert suggestion(emails_to(email), group_name)
    context
  end

  step "{string} receives an email suggesting they join {string}",
       %{args: [email, group_name]} = context do
    sent =
      suggestion(emails_to(email), group_name) ||
        flunk("no email suggesting #{group_name} reached #{email}")

    assert sent.text_body =~ "See #{group_name}: "
    assert sent.text_body =~ "Unsubscribe from this kind of email"
    Map.put(context, :suggestion, sent)
  end

  step "{string} receives no email about joining {string}",
       %{args: [email, group_name]} = context do
    refute suggestion(emails_to(email), group_name)
    context
  end

  step "it says they RSVPd to {string}", %{args: [title], suggestion: sent} = context do
    assert sent.text_body =~ "You RSVPd to #{title} on "
    context
  end

  step "it lists {string} as coming up", %{args: [title], suggestion: sent} = context do
    assert sent.text_body =~ "Coming up:"
    assert sent.text_body =~ title
    assert sent.html_body =~ title
    context
  end

  step "it says nothing is on the group's calendar yet", %{suggestion: sent} = context do
    assert sent.text_body =~ "Nothing is on their calendar yet."
    refute sent.text_body =~ "Coming up:"
    context
  end

  step "it says this is the only time huddlz will suggest it", %{suggestion: sent} = context do
    assert sent.text_body =~ "This is the only time we'll suggest it"
    context
  end

  step "my notifications suggest joining {string}", %{args: [group_name]} = context do
    assert_has(context.session, "*", text: "Join #{group_name} to hear about their next huddlz")
    context
  end

  step "the suggestion leads to the {string} group page", %{args: [group_name]} = context do
    group = find_group(group_name)

    session =
      context.session
      |> click_link("Join #{group_name} to hear about their next huddlz")
      |> assert_path("/groups/#{group.slug}")

    Map.put(context, :session, session)
  end

  # The scheduler's own path: end the huddl, then run the completion action.
  defp complete!(title) do
    ended_at = DateTime.add(DateTime.utc_now(), -60, :second)

    title
    |> find_huddl()
    |> Ash.Seed.update!(%{starts_at: DateTime.add(ended_at, -1, :hour), ends_at: ended_at})
    |> Communities.complete_huddl!(authorize?: false)
  end

  # Moves every completion back a day, then runs what the scheduler would.
  defp a_day_passes do
    Huddl
    |> Ash.Query.filter(lifecycle_state == :completed)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn huddl ->
      Ash.Seed.update!(huddl, %{completed_at: DateTime.add(huddl.completed_at, -25, :hour)})
    end)

    [authorize?: false]
    |> Communities.huddlz_due_for_join_suggestions!()
    |> Enum.each(&Communities.suggest_joining!(&1, authorize?: false))
  end

  defp suggestion(emails, group_name) do
    Enum.find(emails, &(&1.subject == "Hear about #{group_name}'s next huddlz"))
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
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
