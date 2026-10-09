defmodule CombinedLandingSteps do
  @moduledoc """
  Steps for the combination: the return destination carried from the header
  sign-in, the agenda filter a person opens on, and the nearby filter, all on
  one page. Only the steps this interaction needs live here — the three
  behaviours each keep their own steps, and reusing them is the point.
  """
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  alias Huddlz.Accounts.User

  # The nearby and group seeding steps act on `current_user`, and so does the
  # preference. Two of these scenarios sign in through the form afterwards, so
  # the person has to be named before the browser knows them.
  step "{string} has set no agenda preference", %{args: [email]} = context do
    user = Ash.get!(User, %{email: email}, authorize?: false)

    assert user.agenda_landing == :groups,
           "expected the untouched preference to be the default filter, got #{inspect(user.agenda_landing)}"

    Map.put(context, :current_user, user)
  end

  step "the user lands on everything their groups have on", context do
    session = context[:session] || context[:conn]

    session
    |> assert_path("/agenda")
    |> assert_has(".cal-scope .chip.is-active", text: "Groups")

    Map.merge(context, %{conn: session, session: session})
  end
end
