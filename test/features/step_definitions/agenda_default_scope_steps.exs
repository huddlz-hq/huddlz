defmodule AgendaDefaultScopeSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  step "the {string} filter is the one I am looking at",
       %{args: [label], session: session} = context do
    assert_has(session, "a[aria-current='page']", text: label)
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
end
