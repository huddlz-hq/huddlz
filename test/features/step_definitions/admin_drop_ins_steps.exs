defmodule AdminDropInsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Admin
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}

  @panel "#drop-ins"

  step "{int} people RSVPd to a huddl of {string} without joining the group",
       %{args: [count, group_name]} = context do
    huddl = upcoming_huddl(find_group(group_name))

    for _ <- 1..count//1 do
      Communities.rsvp_huddl!(huddl, actor: generate(user(role: :user)))
    end

    context
  end

  step "{int} members of {string} RSVPd to one of its huddlz",
       %{args: [count, group_name]} = context do
    group = find_group(group_name)
    huddl = upcoming_huddl(group)

    for _ <- 1..count//1 do
      member = generate(user(role: :user))
      Communities.join_group!(group.id, actor: member)
      Communities.rsvp_huddl!(huddl, actor: member)
    end

    context
  end

  step "{string} joined {string} and then RSVPd to one of its huddlz",
       %{args: [email, group_name]} = context do
    group = find_group(group_name)
    user = find_user(email)
    Communities.join_group!(group.id, actor: user)
    Communities.rsvp_huddl!(upcoming_huddl(group), actor: user)
    context
  end

  step "{string} dropped in on {string}", %{args: [email, group_name]} = context do
    drop_in(email, group_name)
    context
  end

  step "{string} dropped in on {string} {int} days ago",
       %{args: [email, group_name, days]} = context do
    huddl = drop_in(email, group_name)
    backdate_rsvp(huddl, find_user(email), days)

    context
  end

  step "{string} RSVPd to another huddl of {string}", %{args: [email, group_name]} = context do
    drop_in(email, group_name)
    context
  end

  step "the RSVP from {string} to {string} was made {int} days ago",
       %{args: [email, title, days]} = context do
    huddl = Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
    backdate_rsvp(huddl, find_user(email), days)
    context
  end

  step "the Drop-ins panel shows {int} for {string}", %{args: [count, label]} = context do
    assert_has(context.session, "#{@panel} output[aria-label=\"#{label}\"]",
      text: "#{count}",
      exact: true
    )

    context
  end

  step "{string} transfers {string} to {string}",
       %{args: [owner_email, group_name, successor_email]} = context do
    Communities.transfer_group_ownership!(find_group(group_name), find_user(successor_email).id,
      actor: find_user(owner_email)
    )

    context
  end

  step "the Drop-ins panel says it has been measured since {int} days ago",
       %{args: [days]} = context do
    since = Date.add(Date.utc_today(), -days)
    # The page keeps the date on one line with a no-break space.
    assert_has(context.session, @panel,
      text: "Measured since #{Calendar.strftime(since, "%b\u00a0%-d")}"
    )

    context
  end

  step "the Drop-ins panel does not say when it has been measured since", context do
    refute_has(context.session, @panel, text: "Measured since")
    context
  end

  step "the Drop-ins panel does not offer a breakdown", context do
    refute_has(context.session, @panel, text: "What they did next")
    refute_has(context.session, @panel, text: "joins came from")
    refute_has(context.session, @panel, text: "suggestion to join was emailed")
    refute_has(context.session, @panel, text: "suggestions to join were emailed")
    context
  end

  step "{string} runs the platform overview action", %{args: [email]} = context do
    Map.put(context, :overview_result, Admin.platform_overview("90d", actor: find_user(email)))
  end

  step "its drop-in figures count {int} of {int} RSVPs",
       %{args: [drop_ins, total], overview_result: result} = context do
    assert {:ok, %{drop_ins: %{rsvps: ^drop_ins, total_rsvps: ^total}}} = result
    context
  end

  step "the platform overview action is refused", %{overview_result: result} = context do
    assert {:error, %Ash.Error.Forbidden{}} = result
    context
  end

  step "the Drop-ins panel says {string}", %{args: [text]} = context do
    assert_has(context.session, @panel, text: text)
    context
  end

  defp drop_in(email, group_name) do
    huddl = upcoming_huddl(find_group(group_name))
    Communities.rsvp_huddl!(huddl, actor: find_user(email))
    huddl
  end

  defp backdate_rsvp(huddl, user, days) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
    |> Ash.Seed.update!(%{rsvped_at: DateTime.add(DateTime.utc_now(), -days, :day)})
  end

  # Creating a huddl RSVPs its creator. The scenarios count RSVPs, so the
  # creator's own is cancelled to leave only the ones they describe.
  defp upcoming_huddl(group) do
    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: group.owner_id,
          is_private: false,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/#{System.unique_integer([:positive])}"
        )
      )

    owner = Ash.get!(User, group.owner_id, authorize?: false)
    Communities.cancel_rsvp_huddl!(huddl, actor: owner)
    huddl
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end
end
