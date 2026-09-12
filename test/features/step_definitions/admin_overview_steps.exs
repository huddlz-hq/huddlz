defmodule AdminOverviewSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

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

  step "the most active groups list {string} before {string}",
       %{args: [first, second], session: session} = context do
    first_id = find_group(first).id
    second_id = find_group(second).id

    session
    |> assert_has("#active-group-#{first_id}", text: first)
    |> assert_has("#active-group-#{first_id} ~ #active-group-#{second_id}", text: second)

    context
  end

  step "the active group row for {string} shows {string} and {string}",
       %{args: [name | texts], session: session} = context do
    row = "#active-group-#{find_group(name).id}"
    Enum.each(texts, &assert_group_cell(session, row, &1))
    context
  end

  step "the active group row for {string} shows no show rate",
       %{args: [name], session: session} = context do
    assert_has(session, "#active-group-#{find_group(name).id} [data-label='Show rate']",
      text: "—",
      exact: true
    )

    context
  end

  step "the Show rate KPI reads as not yet available", %{session: session} = context do
    assert_has(session, "#kpi-showrate .value", text: "—", exact: true)
    context
  end

  step "the Coming up panel shows {string} huddl and {string} RSVPs",
       %{args: [huddlz, rsvps], session: session} = context do
    session
    |> assert_has("#coming-up-huddlz .big", text: huddlz, exact: true)
    |> assert_has("#coming-up-rsvps .big", text: rsvps, exact: true)

    context
  end

  step "the Coming up panel lists {string}", %{args: [title], session: session} = context do
    assert_has(session, "#coming-up", text: title)
    context
  end

  # "4 RSVPs" is the RSVPs cell reading 4; a bare figure like "75%" can
  # sit in any cell of the row.
  defp assert_group_cell(session, row, text) do
    case Regex.run(~r/^(\S+) (RSVPs|huddlz|huddl|members|member)$/, text) do
      [_, value, label] ->
        assert_has(session, "#{row} [data-label='#{column(label)}']", text: value, exact: true)

      nil ->
        assert_has(session, row, text: text)
    end
  end

  defp column("RSVPs"), do: "RSVPs"
  defp column(label) when label in ["huddlz", "huddl"], do: "Huddlz"
  defp column(label) when label in ["members", "member"], do: "Members"

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

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
