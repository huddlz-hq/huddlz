defmodule AdminCopiesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl}

  @panel "#copies"

  step "{string} copied {int} huddl(z) of {string}",
       %{args: [email, count, group_name]} = context do
    for _copy <- 1..count, do: copy(email, upcoming_huddl(group_name, email))
    context
  end

  step "{string} created a huddl of {string} from scratch",
       %{args: [email, group_name]} = context do
    upcoming_huddl(group_name, email)
    context
  end

  step "{string} copied a huddl of {string} that had already happened",
       %{args: [email, group_name]} = context do
    copy(email, past_huddl_of(group_name, email, 2))
    context
  end

  step "{string} copied a huddl of {string} that was still upcoming",
       %{args: [email, group_name]} = context do
    copy(email, upcoming_huddl(group_name, email))
    context
  end

  step "{string} copied a huddl of {string} {int} days ago that ended {int} days ago",
       %{args: [email, group_name, copied_days, ended_days]} = context do
    email |> copy(past_huddl_of(group_name, email, ended_days)) |> backdate(copied_days)
    context
  end

  step "{string} copied a huddl of {string} {int} days ago",
       %{args: [email, group_name, days]} = context do
    email |> copy(upcoming_huddl(group_name, email)) |> backdate(days)
    context
  end

  step "the Copies panel shows {int} for {string}", %{args: [count, label]} = context do
    assert_has(context.session, "#{@panel} output[aria-label=\"#{label}\"]",
      text: "#{count}",
      exact: true
    )

    context
  end

  step "the Copies panel says {string}", %{args: [text]} = context do
    assert_has(context.session, @panel, text: text)
    context
  end

  step "the Copies panel says it has been measured since {int} days ago",
       %{args: [days]} = context do
    since = Date.add(Date.utc_today(), -days)
    # The page keeps the date on one line with a no-break space.
    assert_has(context.session, @panel,
      text: "Measured since #{Calendar.strftime(since, "%b %-d")}"
    )

    context
  end

  step "the Copies panel does not say when it has been measured since", context do
    refute_has(context.session, @panel, text: "Measured since")
    context
  end

  step "the Copies panel does not compare with the previous period", context do
    refute_has(context.session, @panel, text: "in the previous")
    context
  end

  step "its copy figures count {int} huddlz by {int} organizer",
       %{args: [count, organizers], overview_result: result} = context do
    assert {:ok, %{copies: %{count: ^count, organizers: ^organizers}}} = result
    context
  end

  # Copies go through the huddl create action, as the form and the API do,
  # so the audit history records them.
  defp copy(email, source) do
    Communities.create_huddl!(
      %{copied_from_id: source.id, date: Date.add(Date.utc_today(), 14)},
      actor: find_user(email)
    )
  end

  defp backdate(copy, days) do
    Huddl.Version
    |> Ash.Query.filter(version_source_id == ^copy.id and version_action_name == :create)
    |> Ash.read_one!(authorize?: false)
    |> Ash.Seed.update!(%{version_inserted_at: DateTime.add(DateTime.utc_now(), -days, :day)})
  end

  defp upcoming_huddl(group_name, email) do
    group = find_group(group_name)
    generate(huddl(group_id: group.id, actor: find_user(email), is_private: false))
  end

  # Seeded, so it has no history of its own: its current dates stand in.
  defp past_huddl_of(group_name, email, ended_days) do
    group = find_group(group_name)
    ends_at = DateTime.add(DateTime.utc_now(), -ended_days, :day)

    generate(
      past_huddl(
        group_id: group.id,
        creator_id: find_user(email).id,
        group_location_id: address_book_location_id(group.id),
        time_zone: group.time_zone,
        starts_at: DateTime.add(ends_at, -2, :hour),
        ends_at: ends_at,
        lifecycle_state: :completed
      )
    )
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end
end
