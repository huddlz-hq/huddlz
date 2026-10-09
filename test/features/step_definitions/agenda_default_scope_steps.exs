defmodule AgendaDefaultScopeSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  alias Huddlz.Accounts.User

  step "the {string} filter is the one I am looking at",
       %{args: [label], session: session} = context do
    assert_has(session, ".cal-scope .chip.is-active", text: label)
    context
  end

  step "I switch to just my RSVPs", %{session: session} = context do
    session = click_link(session, "#calendar-scope-mine", "RSVPs")
    Map.merge(context, %{conn: session, session: session})
  end

  step "the agenda invites me to find a huddl", %{session: session} = context do
    assert_has(session, "#calendar-first-run", text: "Find a huddl")
    context
  end

  step "I choose to open the agenda on {string}", %{args: [label], session: session} = context do
    session = choose(session, label)
    Map.merge(context, %{conn: session, session: session})
  end

  step "{string} opens the agenda on just their RSVPs", %{args: [email]} = context do
    user = Ash.get!(User, %{email: email}, authorize?: false)

    user
    |> Ash.Changeset.for_update(:update_agenda_landing, %{agenda_landing: :mine}, actor: user)
    |> Ash.update!()

    context
  end

  step "the user lands on their own RSVPs", context do
    session = context[:session] || context[:conn]

    session
    |> assert_path("/agenda", query_params: %{"scope" => "mine"})
    |> assert_has(".cal-scope .chip.is-active", text: "RSVPs")

    context
  end
end
