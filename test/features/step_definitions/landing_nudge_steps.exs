defmodule LandingNudgeSteps do
  @moduledoc """
  Steps for the adaptive landing nudge.

  "Leaving my landing page" is driven by actually visiting another in-app
  page, so the POC's stand-in detector (a counter on the user record,
  bumped when a signed-in person mounts a page that is not their landing)
  is exercised the way a real visit would exercise it.
  """

  use Cucumber.StepDefinition

  import PhoenixTest

  step "I leave my landing page for {string} {int} times",
       %{args: [path, times]} = context do
    session =
      Enum.reduce(1..times, session(context), fn _n, sess ->
        sess |> visit(path) |> visit("/agenda")
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I have left my landing page often enough to be offered a change", context do
    session =
      Enum.reduce(1..3, session(context), fn _n, sess ->
        sess |> visit("/discover") |> visit("/agenda")
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I sign in again with password {string}", %{args: [password]} = context do
    email = to_string(context.current_user.email)

    session =
      Phoenix.ConnTest.build_conn()
      |> visit("/sign-in")
      |> within("#password-sign-in-form", fn s ->
        s
        |> fill_in("Email", with: email)
        |> fill_in("Password", with: password)
        |> click_button("Sign in")
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I should land on {string}", %{args: [path]} = context do
    assert_path(session(context), path)
    {:ok, context}
  end

  defp session(context), do: context[:session] || context[:conn]
end
