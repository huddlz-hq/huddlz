defmodule WaitlistSteps do
  use Cucumber.StepDefinition
  import Huddlz.Generator

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, Huddl}

  require Ash.Query

  step "the following capped huddl exists in {string}:", %{args: [group_name]} = context do
    huddl_data = hd(context.datatable.maps)

    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    starts_at = parse_relative_time(huddl_data["starts_at"])
    ends_at = DateTime.add(starts_at, 3600, :second)

    date = DateTime.to_date(starts_at)
    start_time = DateTime.to_time(starts_at)
    duration_minutes = div(DateTime.diff(ends_at, starts_at, :second), 60)

    max_attendees = huddl_data["max_attendees"] |> String.to_integer()

    generate(
      huddl(
        title: huddl_data["title"],
        description: huddl_data["description"],
        event_type: String.to_atom(huddl_data["event_type"]),
        date: date,
        start_time: start_time,
        duration_minutes: duration_minutes,
        virtual_link: huddl_data["virtual_link"],
        max_attendees: max_attendees,
        group_id: group.id,
        actor: group.owner
      )
    )

    context
  end

  step "I have joined the waitlist for {string}", %{args: [huddl_title]} = context do
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.read_one!(actor: user)

    huddl
    |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: user)
    |> Ash.update!()

    context
  end

  step "{string} cancels their RSVP to {string}", %{args: [email, huddl_title]} = context do
    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.read_one!(actor: user)

    huddl
    |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: user)
    |> Ash.update!()

    context
  end

  defp parse_relative_time("tomorrow" <> rest) do
    DateTime.utc_now()
    |> DateTime.add(1, :day)
    |> parse_time_of_day(rest)
  end

  defp parse_time_of_day(date, " " <> time_str), do: parse_time_of_day(date, time_str)

  defp parse_time_of_day(date, "2pm") do
    date
    |> DateTime.to_date()
    |> DateTime.new!(~T[14:00:00], "Etc/UTC")
  end

  defp parse_time_of_day(date, _), do: date
end
