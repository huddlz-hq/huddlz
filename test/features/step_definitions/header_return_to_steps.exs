defmodule HeaderReturnToSteps do
  @moduledoc """
  Steps for signing in from the global header and landing back on the huddl
  or group page the person was reading.
  """
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  alias Huddlz.Communities.Huddl
  alias HuddlzWeb.AuthReturnTo

  require Ash.Query

  step "I visit the {string} huddl page while signed out", %{args: [title]} = context do
    huddl =
      Huddl
      |> Ash.Query.filter(title == ^title)
      |> Ash.Query.load(:group)
      |> Ash.read_one!(authorize?: false)

    session =
      (context[:session] || Phoenix.ConnTest.build_conn())
      |> visit("/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")

    Map.merge(context, %{session: session, conn: session, target_huddl: huddl})
  end

  step "I arrive at {string}", %{args: [path]} = context do
    session = (context[:session] || Phoenix.ConnTest.build_conn()) |> visit(path)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I sign in as {string} with password {string}",
       %{args: [email, password]} = context do
    session =
      context.session
      |> fill_in("Email", with: email)
      |> fill_in("Password", with: password)
      |> click_button("Sign in")

    Map.merge(context, %{session: session, conn: session})
  end

  # The header is the site-wide navigation strip. Naming it keeps this
  # distinct from the in-page "Sign in to RSVP" / "Sign in to join" calls to
  # action, which already carried a return destination before this change.
  step "I choose {string} in the site header", %{args: [label]} = context do
    session =
      context.session
      |> within(".content-actions", fn header -> click_link(header, label) end)

    Map.merge(context, %{session: session, conn: session})
  end

  step "unsafe header return destinations are offered:", context do
    results =
      Map.new(context.datatable.maps, fn row ->
        {row["destination"], AuthReturnTo.validate(row["destination"])}
      end)

    Map.put(context, :header_return_results, results)
  end

  step "each unsafe header return destination is refused", context do
    for {destination, result} <- context.header_return_results do
      assert result == nil, "#{inspect(destination)} was accepted as a return destination"
    end

    context
  end
end
