defmodule AdminOverviewSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Admin
  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}
  alias Huddlz.Test.Helpers.Authentication

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

  step "{string} views the platform overview for {string}",
       %{args: [email, period]} = context do
    user = find_user(email)

    session =
      build_conn()
      |> Authentication.login(user)
      |> visit("/admin?period=#{period}")
      |> assert_has("h1", text: "Overview")

    # The visit exercises dashboard access and records usage. Inspect the public
    # action's figures for period boundaries and coverage that the page rounds.
    stats = Admin.platform_overview!(period, actor: user)
    Map.merge(context, %{session: session, conn: session, overview_stats: stats})
  end

  step "the platform chart buckets begin at midnight UTC", context do
    for bucket <- context.overview_stats.held.buckets do
      assert DateTime.to_time(bucket.starts_at) == ~T[00:00:00]
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
    held = context.overview_stats.held
    assert held.count == count
    assert length(held.buckets) == 12
    assert Enum.sum(Enum.map(held.buckets, & &1.held)) == count
    assert hd(held.buckets).held == count
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

    assert Enum.any?(
             response["errors"],
             &(&1["message"] =~ "Cannot query field \"platformOverview\"")
           )

    context
  end

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

  step "the most active groups do not list {string}",
       %{args: [name], session: session} = context do
    refute_has(session, "#active-group-#{find_group(name).id}")
    context
  end

  step "the RSVPs for {string} were made {int} days ago",
       %{args: [title, days]} = context do
    huddl = Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
    rsvped_at = DateTime.add(DateTime.utc_now(), -days, :day)

    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl.id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.Seed.update!(&1, %{rsvped_at: rsvped_at}))

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

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp kpi_id("Huddlz held"), do: "kpi-huddlz"
  defp kpi_id("Show rate"), do: "kpi-showrate"
  defp kpi_id("People"), do: "kpi-people"
  defp kpi_id("Active people"), do: "kpi-active"
  defp kpi_id("Groups"), do: "kpi-groups"
  defp kpi_id("RSVPs"), do: "kpi-rsvps"

  step "I can change the role of {string}", %{args: [email], session: session} = context do
    user = find_user(email)
    menu = "[role='menu'][aria-label='Manage #{user.display_name}']"

    session =
      session
      |> within(menu, &click_button(&1, "Make an administrator"))
      |> within("[role='dialog']", &click_button(&1, "Make an administrator"))
      |> assert_has("*", text: "User role updated successfully")
      |> visit("/admin/users")
      |> assert_has("section[aria-labelledby='role-admins-heading']", text: user.display_name)

    Map.merge(context, %{conn: session, session: session})
  end
end
