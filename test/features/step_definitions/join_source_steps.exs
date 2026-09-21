defmodule JoinSourceSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 5, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupActivity, GroupMember}

  @sources %{
    "the huddl page" => :huddl_page,
    "the groups page" => :groups_page,
    "the group page" => :group_page,
    "the join suggestion email" => :join_suggestion_email,
    "the join suggestion notification" => :join_suggestion_notification,
    "the RSVP confirmation email" => :rsvp_confirmation_email
  }

  step "I visit the {string} group page tagged {string}",
       %{args: [group_name, tag]} = context do
    session = visit(context.session, "/groups/#{find_group(group_name).slug}?from=#{tag}")
    Map.put(context, :session, session)
  end

  step "I follow the email's link to the group page", %{suggestion: sent} = context do
    follow_group_link(context, sent)
  end

  step "I follow the RSVP confirmation email's link to the group page", context do
    Oban.drain_queue(queue: :notifications)
    assert_received {:email, %{subject: "You're going to" <> _} = sent}
    follow_group_link(context, sent)
  end

  step "I sign in to join as {string} with password {string}",
       %{args: [email, password]} = context do
    session =
      context.session
      |> click_link("Sign in to join")
      |> within("#password-sign-in-form", fn form ->
        form
        |> fill_in("Email", with: email)
        |> fill_in("Password", with: password)
        |> click_button("Sign in")
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  step "{string} joins {string} through {string} without naming a source",
       %{args: [email, group_name, api]} = context do
    Map.put(context, :join_refused?, join_through(api, email, group_name, %{}))
  end

  step "{string} joins {string} through {string} naming the source {string}",
       %{args: [email, group_name, api, source]} = context do
    Map.put(context, :join_refused?, join_through(api, email, group_name, %{source: source}))
  end

  step "the join is refused", context do
    assert context.join_refused?
    context
  end

  step "{string} joined {string} from {string}", %{args: [email, group_name, source]} = context do
    Communities.join_group!(
      find_group(group_name).id,
      %{source: Map.fetch!(@sources, source)},
      actor: find_user(email)
    )

    context
  end

  step "{string} leaves {string}", %{args: [email, group_name]} = context do
    user = find_user(email)
    :ok = Communities.leave_group!(membership(find_group(group_name), user), actor: user)
    context
  end

  step "the join of {string} to {string} has no recorded source",
       %{args: [email, group_name]} = context do
    assert_recorded(email, group_name, nil)
    context
  end

  step "the activity log of {string} still says the join of {string} came from {string}",
       %{args: [group_name, email, source]} = context do
    entry = joined_entry(find_group(group_name), find_user(email))
    assert entry.source == Map.fetch!(@sources, source)
    context
  end

  step "the join of {string} to {string} is recorded as coming from {string}",
       %{args: [email, group_name, source]} = context do
    assert_recorded(email, group_name, Map.fetch!(@sources, source))
    context
  end

  # The email's own link, followed the way a mail client would open it.
  defp follow_group_link(context, sent) do
    [link] = Regex.run(~r{https?://[^\s)]+/groups/[^/\s)]+(?=[\s).]|$)}, sent.text_body)
    %URI{path: path, query: query} = URI.parse(link)
    session = context[:session] || context[:conn] || Phoenix.ConnTest.build_conn()
    session = visit(session, if(query, do: "#{path}?#{query}", else: path))
    Map.merge(context, %{session: session, conn: session})
  end

  defp assert_recorded(email, group_name, source) do
    user = find_user(email)
    group = find_group(group_name)

    assert membership(group, user).join_source == source
    assert joined_entry(group, user).source == source
  end

  defp membership(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
  end

  # Joins as the person through one of the public APIs. Returns whether the
  # API refused the join.
  defp join_through("GraphQL", email, group_name, extra) do
    input =
      Map.merge(
        %{"groupId" => find_group(group_name).id},
        Map.new(extra, fn {:source, source} -> {"source", String.upcase(source)} end)
      )

    body =
      build_conn()
      |> authenticated_conn(find_user(email))
      |> gql_post(
        """
        mutation($input: JoinGroupInput!) {
          joinGroup(input: $input) { result { id } errors { message } }
        }
        """,
        %{"input" => input}
      )
      |> Map.fetch!(:resp_body)
      |> Jason.decode!()

    Map.has_key?(body, "errors") or body["data"]["joinGroup"]["errors"] != []
  end

  defp join_through("JSON:API", email, group_name, extra) do
    attributes = Map.merge(%{group_id: find_group(group_name).id}, extra)

    conn =
      build_conn()
      |> authenticated_conn(find_user(email))
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> dispatch(
        HuddlzWeb.Endpoint,
        :post,
        "/api/json/group_members/join",
        Jason.encode!(%{data: %{type: "group_member", attributes: attributes}})
      )

    if conn.status == 201, do: false, else: is_map(json_response(conn, 400))
  end

  defp joined_entry(group, user) do
    GroupActivity
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id and kind == :joined)
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end
