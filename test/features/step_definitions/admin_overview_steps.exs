defmodule AdminOverviewSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  step "the platform {string} figure shows {string}",
       %{args: [figure, value], session: session} = context do
    assert_has(session, "output[aria-label='#{figure}']", text: value, exact: true)
    context
  end

  step "the platform {string} figure shows {string} and {string}",
       %{args: [figure, value, detail], session: session} = context do
    session
    |> assert_has("output[aria-label='#{figure}']", text: value, exact: true)
    |> assert_has("##{kpi_id(figure)}", text: detail)

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

  step "the API overview omits unmeasured active users", context do
    refute Map.has_key?(overview_payload(context.overview_response), "active")
    context
  end

  step "the platform chart buckets begin at midnight UTC", context do
    for bucket <- overview_payload(context.overview_response)["held"]["buckets"] do
      {:ok, at, 0} = DateTime.from_iso8601(bucket["starts_at"])
      assert DateTime.to_time(at) == ~T[00:00:00]
    end

    context
  end

  step "a huddl in {string} ended just before the twelve calendar months",
       %{args: [name]} = context do
    seed_annual_huddl(name, -1)
    context
  end

  step "a huddl in {string} ended in the first of the twelve calendar months",
       %{args: [name]} = context do
    seed_annual_huddl(name, 1)
    context
  end

  step "the annual platform total and chart both show {int} huddl held",
       %{args: [count]} = context do
    held = overview_payload(context.overview_response)["held"]
    assert held["count"] == count
    assert length(held["buckets"]) == 12
    assert Enum.sum(Enum.map(held["buckets"], & &1["held"])) == count
    assert hd(held["buckets"])["held"] == count
    context
  end

  defp seed_annual_huddl(name, days_from_start) do
    group = find_group(name)

    ends_at =
      Date.utc_today()
      |> Date.beginning_of_month()
      |> Date.shift(month: -11)
      |> Date.add(days_from_start)
      |> DateTime.new!(~T[12:00:00], "Etc/UTC")

    generate(
      past_huddl(
        group_id: group.id,
        creator_id: group.owner_id,
        is_private: false,
        starts_at: DateTime.add(ends_at, -2, :hour),
        ends_at: ends_at
      )
    )
  end

  step "the sign-up date for {string} was estimated from {word}",
       %{args: [email, source]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)

    source =
      case source do
        "confirmation" -> :confirmation
        "migration" -> :migration
      end

    Ash.Seed.update!(user, %{signup_date_source: source})
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
    Enum.each(texts, &assert_group_cell(session, row, name, &1))
    context
  end

  step "the active group row for {string} shows no show rate",
       %{args: [name], session: session} = context do
    assert_has(session, "output[aria-label='Show rate for #{name}']",
      text: "—",
      exact: true
    )

    context
  end

  step "the Coming up panel shows {string} huddl and {string} RSVPs",
       %{args: [huddlz, rsvps], session: session} = context do
    session
    |> assert_has("output[aria-label='Scheduled huddlz']", text: huddlz, exact: true)
    |> assert_has("output[aria-label='Upcoming RSVPs']", text: rsvps, exact: true)

    context
  end

  step "the Coming up panel lists {string}", %{args: [title], session: session} = context do
    assert_has(session, "#coming-up", text: title)
    context
  end

  # "4 RSVPs" is the RSVPs cell reading 4; a bare figure like "75%" can
  # sit in any cell of the row.
  defp assert_group_cell(session, row, name, text) do
    case Regex.run(~r/^(\S+) (RSVPs|huddlz|huddl|members|member)$/, text) do
      [_, value, label] ->
        assert_has(session, "output[aria-label='#{column(label)} for #{name}']",
          text: value,
          exact: true
        )

      nil ->
        assert_has(session, row, text: text)
    end
  end

  defp column("RSVPs"), do: "RSVPs"
  defp column(label) when label in ["huddlz", "huddl"], do: "Huddlz held"
  defp column(label) when label in ["members", "member"], do: "Members"

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp kpi_id("Huddlz held"), do: "kpi-huddlz"
  defp kpi_id("Show rate"), do: "kpi-showrate"
  defp kpi_id("People"), do: "kpi-people"
  defp kpi_id("Groups"), do: "kpi-groups"
  defp kpi_id("RSVPs"), do: "kpi-rsvps"

  step "I can change the role of {string}", %{args: [email], session: session} = context do
    session =
      session
      |> select("Role for #{email}", option: "Admin")
      |> click_button("Update role for #{email}")
      |> assert_has("*", text: "User role updated successfully")

    session =
      session
      |> visit("/admin/users")
      |> assert_has("select", label: "Role for #{email}", selected: "Admin")

    Map.merge(context, %{conn: session, session: session})
  end
end
