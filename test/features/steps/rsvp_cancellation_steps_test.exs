defmodule RsvpCancellationSteps do
  use Cucumber, feature: "rsvp_cancellation.feature"
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  alias Huddlz.Communities.{Huddl, Group}
  alias Huddlz.Accounts.User

  require Ash.Query

  # Background steps - users and groups
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

    # Use the group owner as the actor to add the member
    generate(
      group_member(
        group_id: group.id,
        user_id: user.id,
        role: "member",
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

    starts_at = parse_relative_time(huddl_data["starts_at"])
    ends_at = 
      case Map.get(huddl_data, "ends_at") do
        nil -> DateTime.add(starts_at, 3600, :second)  # Default to 1 hour after start
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

    {:ok, context}
  end

  defstep "I am logged in as {string}", context do
    email = List.first(context.args)

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    conn =
      context.conn
      |> login(user)

    {:ok, Map.merge(context, %{conn: conn, current_user: user})}
  end

  defstep "I am on the {string} group page", context do
    group_name = List.first(context.args)

    group =
      Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    {:ok, live, _html} = live(context.conn, "/groups/#{group.id}")
    {:ok, Map.put(context, :live, live)}
  end

  defstep "I click on {string}", context do
    link_text = List.first(context.args)
    
    result =
      context.live
      |> element("a", link_text)
      |> render_click()

    case result do
      {:error, {:redirect, %{to: path}}} ->
        {:ok, live, _html} = live(context.conn, path)
        {:ok, Map.put(context, :live, live)}
      
      {:error, {:live_redirect, %{to: path}}} ->
        {:ok, live, _html} = live(context.conn, path)
        {:ok, Map.put(context, :live, live)}
      
      html when is_binary(html) ->
        {:ok, Map.put(context, :html, html)}
    end
  end

  defstep "I should see {string}", context do
    text = List.first(context.args)
    html = render(context.live)
    
    # Handle HTML entities - convert common ones
    normalized_html = html
      |> String.replace("&#39;", "'")
      |> String.replace("&quot;", "\"")
      |> String.replace("&amp;", "&")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")
    
    assert normalized_html =~ text
    {:ok, context}
  end

  defstep "I should not see {string}", context do
    text = List.first(context.args)
    html = render(context.live)
    
    # Handle HTML entities - convert common ones
    normalized_html = html
      |> String.replace("&#39;", "'")
      |> String.replace("&quot;", "\"")
      |> String.replace("&amp;", "&")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")
    
    refute normalized_html =~ text
    {:ok, context}
  end

  defstep "I should be on the huddl page for {string}", context do
    huddl_title = List.first(context.args)
    
    # Just verify we can see the huddl content - the navigation already happened
    html = render(context.live)
    assert html =~ huddl_title
    {:ok, context}
  end

  defstep "I log out", context do
    {:ok, Map.put(context, :conn, build_conn())}
  end

  # Given steps
  defstep "I have RSVPed to {string}", context do
    huddl_title = List.first(context.args)
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

  defstep "{string} has RSVPed to {string}", context do
    [email, huddl_title] = context.args

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
  defstep "I visit the {string} huddl page", context do
    huddl_title = List.first(context.args)
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.Query.load(:group)
      |> Ash.read_one!(actor: user)

    {:ok, live, _html} =
      context.conn
      |> live("/groups/#{huddl.group_id}/huddlz/#{huddl.id}")

    {:ok, Map.put(context, :live, live)}
  end

  defstep "I click {string}", context do
    button_text = List.first(context.args)

    # Try button first, then link
    result =
      try do
        context.live
        |> element("button", button_text)
        |> render_click()
      rescue
        _ ->
          # If button fails, try link
          context.live
          |> element("a", button_text)
          |> render_click()
      end

    case result do
      {:error, {:redirect, %{to: path}}} ->
        {:ok, live, _html} = live(context.conn, path)
        {:ok, Map.put(context, :live, live)}
      
      {:error, {:live_redirect, %{to: path}}} ->
        {:ok, live, _html} = live(context.conn, path)
        {:ok, Map.put(context, :live, live)}
      
      html when is_binary(html) ->
        {:ok, Map.put(context, :html, html)}
    end
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
