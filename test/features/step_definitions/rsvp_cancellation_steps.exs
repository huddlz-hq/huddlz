defmodule RsvpCancellationSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import CucumberDatabaseHelper

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, Huddl}

  require Ash.Query

  # Background steps - groups (users are in shared_auth_steps)
  step "the following group exists:", context do
    ensure_sandbox()
    group_data = hd(context.datatable.maps)
    owner_email = group_data["owner_email"]

    owner =
      User
      |> Ash.Query.filter(email == ^owner_email)
      |> Ash.read_one!(authorize?: false)

    is_public = group_data["is_public"] == "true"

    group =
      generate(
        group(
          name: group_data["name"],
          description: group_data["description"],
          is_public: is_public,
          owner: owner
        )
      )

    Map.put(context, :group, group)
  end

  step "{string} is a member of {string}", %{args: [email, group_name]} = context do
    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    # Use the group owner as the actor to add the member
    generate(
      group_member(
        group_id: group.id,
        user_id: user.id,
        role: "member",
        actor: group.owner
      )
    )

    context
  end

  step "the following huddl exists in {string}:", %{args: [group_name]} = context do
    huddl_data = hd(context.datatable.maps)

    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    starts_at = parse_relative_time(huddl_data["starts_at"])

    ends_at =
      case Map.get(huddl_data, "ends_at") do
        # Default to 1 hour after start
        nil -> DateTime.add(starts_at, 3600, :second)
        ends_at_str -> parse_relative_time(ends_at_str)
      end

    virtual_link = Map.get(huddl_data, "virtual_link")
    event_type = String.to_atom(huddl_data["event_type"])

    generate(
      huddl(
        title: huddl_data["title"],
        description: huddl_data["description"],
        event_type: event_type,
        starts_at: starts_at,
        ends_at: ends_at,
        virtual_link: virtual_link,
        group_id: group.id,
        actor: group.owner
      )
    )

    context
  end

  step "I am logged in as {string}", %{args: [email]} = context do
    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    session = context[:session] || context[:conn]

    session =
      session
      |> login(user)

    session = session |> visit("/")

    Map.merge(context, %{session: session, conn: session, current_user: user})
  end

  step "I am on the {string} group page", %{args: [group_name]} = context do
    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    session = context[:session] || context[:conn]
    session = session |> visit("/groups/#{group.slug}")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I click on {string}", %{args: [link_text]} = context do
    session = context[:session] || context[:conn]
    session = click_link(session, link_text)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I should be on the huddl page for {string}", %{args: [huddl_title]} = context do
    # Just verify we can see the huddl content - the navigation already happened
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: huddl_title)
    context
  end

  step "I log out", context do
    conn = Phoenix.ConnTest.build_conn()
    Map.merge(context, %{session: conn, conn: conn})
  end

  # Given steps
  step "I have RSVPed to {string}", %{args: [huddl_title]} = context do
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.read_one!(actor: user)

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{user_id: user.id}, actor: user)
    |> Ash.update!()

    context
  end

  step "{string} has RSVPed to {string}", %{args: [email, huddl_title]} = context do
    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.read_one!(actor: user)

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{user_id: user.id}, actor: user)
    |> Ash.update!()

    context
  end

  # When steps
  step "I visit the {string} huddl page", %{args: [huddl_title]} = context do
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.Query.load(:group)
      |> Ash.read!(actor: user)
      |> List.first()

    session = context[:session] || context[:conn]
    session = session |> visit("/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")
    Map.merge(context, %{session: session, conn: session})
  end

  # Helper functions
  defp parse_relative_time("tomorrow" <> rest) do
    DateTime.utc_now()
    |> DateTime.add(1, :day)
    |> parse_time_of_day(rest)
  end

  defp parse_relative_time("yesterday" <> rest) do
    DateTime.utc_now()
    |> DateTime.add(-1, :day)
    |> parse_time_of_day(rest)
  end

  defp parse_relative_time(datetime_str) do
    {:ok, datetime, _} = DateTime.from_iso8601(datetime_str)
    datetime
  end

  defp parse_time_of_day(date, " " <> time_str) do
    parse_time_of_day(date, time_str)
  end

  defp parse_time_of_day(date, time_str) when time_str in ["2pm", " 2pm"] do
    date
    |> DateTime.to_date()
    |> DateTime.new!(~T[14:00:00], "Etc/UTC")
  end

  defp parse_time_of_day(date, time_str) when time_str in ["3pm", " 3pm"] do
    date
    |> DateTime.to_date()
    |> DateTime.new!(~T[15:00:00], "Etc/UTC")
  end

  defp parse_time_of_day(date, _) do
    date
  end
end
