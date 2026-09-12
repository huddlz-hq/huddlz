defmodule AdminOverviewSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User

  step "the {word} KPI shows {string}", %{args: [kpi, value], session: session} = context do
    assert_has(session, "##{kpi_id(kpi)} .value", text: value, exact: true)
    context
  end

  step "the Active people KPI shows {string}", %{args: [value], session: session} = context do
    assert_has(session, "#kpi-active .value", text: value, exact: true)
    context
  end

  step "the Huddlz held KPI shows {string}", %{args: [value], session: session} = context do
    assert_has(session, "#kpi-huddlz .value", text: value, exact: true)
    context
  end

  step "the Huddlz held KPI shows {string} and {string}",
       %{args: [value, delta], session: session} = context do
    session
    |> assert_has("#kpi-huddlz .value", text: value, exact: true)
    |> assert_has("#kpi-huddlz .delta", text: delta)

    context
  end

  step "{string} reads the platform overview for {string} through GraphQL",
       %{args: [email, period]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)

    response =
      build_conn()
      |> authenticated_conn(user)
      |> gql_post(~s|{ platformOverview(period: "#{period}") }|)
      |> json_response(200)

    Map.put(context, :overview_response, response)
  end

  step "the API platform overview shows {int} huddl held and {int} RSVPs",
       %{args: [held, rsvps]} = context do
    overview = overview_payload(context.overview_response)
    assert overview["held"]["count"] == held
    assert overview["rsvps"]["count"] == rsvps
    context
  end

  step "the API refuses the platform overview", context do
    response = context.overview_response
    assert is_nil(response["data"]["platformOverview"])
    assert [_ | _] = response["errors"]
    context
  end

  # The action returns a map; GraphQL carries it as JSON, sometimes as a
  # string, so accept both.
  defp overview_payload(%{"data" => %{"platformOverview" => payload}}) when is_binary(payload),
    do: Jason.decode!(payload)

  defp overview_payload(%{"data" => %{"platformOverview" => payload}}) when is_map(payload),
    do: payload

  defp overview_payload(response), do: flunk("unexpected overview response: #{inspect(response)}")

  defp kpi_id("People"), do: "kpi-people"
  defp kpi_id("Groups"), do: "kpi-groups"
  defp kpi_id("RSVPs"), do: "kpi-rsvps"

  step "I can change the role of {string}", %{args: [email], session: session} = context do
    session =
      session
      |> select("Role for #{email}", option: "Admin")
      |> click_button("Update role for #{email}")
      |> assert_has("*", text: "User role updated successfully")

    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    assert user.role == :admin

    Map.merge(context, %{conn: session, session: session})
  end
end
