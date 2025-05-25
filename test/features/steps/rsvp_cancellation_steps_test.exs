defmodule RsvpCancellationSteps do
  use Cucumber, feature: "rsvp_cancellation.feature"
  use HuddlzWeb.WallabyCase

  import Huddlz.Generator

  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.MagicLink
  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee

  require Ash.Query

  # Background steps
  defstep "the following users exist:", context do
    users =
      context.datatable.maps
      |> Enum.map(fn user_data ->
        role =
          case user_data["role"] do
            "verified" -> :verified
            "regular" -> :regular
            "admin" -> :admin
            _ -> :regular
          end

        generate(
          user(
            email: user_data["email"],
            display_name: user_data["display_name"],
            role: role
          )
        )
      end)

    {:ok, Map.put(context, :users, users)}
  end

  defstep "the following group exists:", context do
    group_data = hd(context.datatable.maps)

    owner =
      User
      |> Ash.Query.filter(email == ^group_data["owner_email"])
      |> Ash.read_one!(authorize?: false)

    group =
      generate(
        group(
          name: group_data["name"],
          description: group_data["description"],
          is_public: group_data["is_public"] == "true",
          owner_id: owner.id,
          actor: owner
        )
      )

    {:ok, Map.put(context, :group, group)}
  end

  defstep "{string} is a member of {string}", context do
    [email, group_name] = context.args

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    # Create group membership using generator
    generate(
      group_member(
        group_id: group.id,
        user_id: user.id,
        role: :member,
        actor: group.owner
      )
    )

    {:ok, context}
  end

  defstep "the following huddl exists in {string}:", context do
    group_name = List.first(context.args)
    huddl_data = hd(context.datatable.maps)

    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    starts_at =
      case huddl_data["starts_at"] do
        "tomorrow 2pm" ->
          DateTime.utc_now()
          |> DateTime.add(1, :day)
          |> DateTime.truncate(:second)
          |> Map.put(:hour, 14)
          |> Map.put(:minute, 0)
          |> Map.put(:second, 0)

        "yesterday 2pm" ->
          DateTime.utc_now()
          |> DateTime.add(-1, :day)
          |> DateTime.truncate(:second)
          |> Map.put(:hour, 14)
          |> Map.put(:minute, 0)
          |> Map.put(:second, 0)

        other ->
          {:ok, dt, _} = DateTime.from_iso8601(other <> ":00Z")
          dt
      end

    event_type = String.to_existing_atom(huddl_data["event_type"])

    huddl_attrs = %{
      group_id: group.id,
      creator_id: group.owner_id,
      title: huddl_data["title"],
      description: huddl_data["description"],
      event_type: event_type,
      starts_at: starts_at,
      is_private: false,
      actor: group.owner
    }

    # Only add virtual_link if it's provided and not nil
    huddl_attrs =
      if huddl_data["virtual_link"] && huddl_data["virtual_link"] != "" do
        Map.put(huddl_attrs, :virtual_link, huddl_data["virtual_link"])
      else
        huddl_attrs
      end

    huddl = generate(huddl(huddl_attrs))

    {:ok, Map.put(context, :huddl, huddl)}
  end

  defstep "I am logged in as {string}", %{session: session, args: args} = context do
    email = List.first(args)

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    # Generate a magic link token for the user
    strategy = Info.strategy!(User, :magic_link)
    {:ok, token} = MagicLink.request_token_for(strategy, user)

    # Visit the magic link URL directly
    magic_link_url = "/auth/user/magic_link?token=#{token}"
    session = session |> visit(magic_link_url)

    {:ok, context |> Map.put(:session, session) |> Map.put(:current_user, user)}
  end

  # Given steps
  defstep "I have RSVPed to {string}", %{args: args} = context do
    huddl_title = List.first(args)
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.read_one!(actor: user)

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{user_id: user.id}, actor: user)
    |> Ash.update!()

    {:ok, context}
  end

  defstep "{string} has RSVPed to {string}", %{args: args} = context do
    [email, huddl_title] = args

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

    {:ok, context}
  end

  # When steps
  defstep "I am on the {string} group page", %{session: session, args: args} = context do
    group_name = List.first(args)

    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.read_one!(authorize?: false)

    session = visit(session, "/groups/#{group.id}")
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I visit the {string} huddl page", %{session: session, args: args} = context do
    huddl_title = List.first(args)
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.Query.load(:group)
      |> Ash.read_one!(actor: user)

    session =
      session
      |> visit("/groups/#{huddl.group_id}/huddlz/#{huddl.id}")

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I click {string}", %{session: session, args: args} = context do
    button_text = List.first(args)

    session =
      if has?(session, button(button_text)) do
        click(session, button(button_text))
      else
        # If button not found, try as a link
        click(session, link(button_text))
      end

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I click the {string} link", %{session: session, args: args} = context do
    link_text = List.first(args)

    session =
      session
      |> click(link(link_text))

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I log out", %{session: session} = context do
    session = visit(session, "/sign-out")
    {:ok, Map.put(context, :session, session) |> Map.delete(:current_user)}
  end

  defstep "I click on {string}", %{session: session, args: args} = context do
    huddl_title = List.first(args)

    # The huddl title is displayed in a card, not as a clickable link
    # We need to find the "View Details" button for that specific huddl
    # Wallaby doesn't have great support for finding elements relative to each other
    # So we'll use a data attribute or other identifying feature

    # Try clicking the title as a link first
    session =
      if has?(session, link(huddl_title)) do
        click(session, link(huddl_title))
      else
        # If that fails, look for a View Details button
        # Since Wallaby doesn't support complex selectors, we need to work around this
        # For now, let's assume clicking the first "View Details" button works
        # In a real app, we'd add data attributes to make this more reliable
        click(session, link("View Details"))
      end

    {:ok, Map.put(context, :session, session)}
  end

  # Then steps
  defstep "I should see {string}", %{session: session, args: args} = context do
    text = List.first(args)
    assert_has(session, css("body", text: text))
    {:ok, context}
  end

  defstep "I should not see {string}", %{session: session, args: args} = context do
    text = List.first(args)
    refute_has(session, css("body", text: text))
    {:ok, context}
  end

  defstep "my RSVP should be cancelled", context do
    huddl = context.huddl
    user = context.current_user

    # Reload the huddl with attendees
    huddl =
      Huddl
      |> Ash.Query.filter(id == ^huddl.id)
      |> Ash.Query.load(:attendees)
      |> Ash.read_one!(actor: user)

    # Check that the user is not in the attendees list
    attendee_ids = Enum.map(huddl.attendees, & &1.id)
    refute user.id in attendee_ids

    {:ok, context}
  end

  defstep "{string} RSVP count should be {string}", %{args: args} = context do
    [email, count] = args

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    # Count the user's RSVPs
    rsvp_count =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.count!(authorize?: false)

    assert to_string(rsvp_count) == count

    {:ok, context}
  end
end
