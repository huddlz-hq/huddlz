defmodule HuddlOrganizerModerationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 5, json_response: 2]

  require Ash.Query

  alias Huddlz.Accounts
  alias Huddlz.Accounts.{AccountReport, User, UserBlock}
  alias Huddlz.Communities.Huddl

  # ── reporting ───────────────────────────────────────────────────────

  step "I report the organizer of {string} for {string} saying {string} through JSON:API",
       %{args: [title, reason, details]} = context do
    attributes =
      %{"huddl_id" => find_huddl(title).id, "reason" => reason, "details" => details}
      |> Map.reject(fn {_key, value} -> value == "" end)

    # Generic actions take their inputs directly under "data".
    response =
      api_conn(context)
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> dispatch(HuddlzWeb.Endpoint, :post, "/api/json/account_reports/organizer", %{
        "data" => attributes
      })

    Map.put(context, :organizer_report_response, response)
  end

  step "the organizer report is accepted without naming the organizer", context do
    response = context.organizer_report_response
    assert response.status in 200..299, response.resp_body

    organizer = find_user("spam612@example.com")
    refute response.resp_body =~ organizer.id
    refute response.resp_body =~ to_string(organizer.email)
    refute response.resp_body =~ organizer.display_name

    context
  end

  step "the organizer report is refused", context do
    assert %{"errors" => [_ | _]} = json_response(context.organizer_report_response, 403)
    context
  end

  step "JSON:API asks for an organizer report reason", context do
    assert %{"errors" => errors} = json_response(context.organizer_report_response, 400)
    assert Enum.any?(errors, &(&1["detail"] =~ "Say what's wrong"))
    context
  end

  step "the report about {string} came from the huddl {string}",
       %{args: [email, title]} = context do
    huddl_id = find_huddl(title).id

    assert [%AccountReport{source_type: :huddl, source_id: ^huddl_id}] =
             AccountReport
             |> Ash.Query.filter(reported_user_id == ^find_user(email).id)
             |> Ash.read!(authorize?: false)

    context
  end

  # ── blocking ────────────────────────────────────────────────────────

  step "{string} has blocked the organizer of {string}", %{args: [email, title]} = context do
    Accounts.block_huddl_organizer!(find_huddl(title).id, actor: find_user(email))
    context
  end

  step "I block the organizer of {string} through JSON:API", %{args: [title]} = context do
    response =
      post(context, "/api/json/blocks/organizer", "user_block", %{
        "huddl_id" => find_huddl(title).id
      })

    Map.put(context, :block_response, response)
  end

  step "the block is accepted", context do
    assert %{"data" => %{"type" => "user_block", "attributes" => attributes}} =
             json_response(context.block_response, 201)

    refute Map.has_key?(attributes, "blocked_user_id")
    refute Map.has_key?(attributes, "blocker_id")
    refute context.block_response.resp_body =~ find_user("spam612@example.com").id
    context
  end

  step "the block is refused", context do
    assert %{"errors" => [_ | _]} = json_response(context.block_response, 403)
    context
  end

  step "the block is turned down with {string}", %{args: [message]} = context do
    assert %{"errors" => errors} = json_response(context.block_response, 400)
    assert Enum.any?(errors, &(&1["detail"] =~ message)), inspect(errors)
    context
  end

  step "my blocked people through JSON:API are {string}", %{args: [names]} = context do
    expected = if names == "", do: [], else: String.split(names, ", ")
    assert Enum.map(blocks(context), & &1["attributes"]["blocked_user_name"]) == expected
    context
  end

  step "I unblock {string} through JSON:API", %{args: [name]} = context do
    block = Enum.find(blocks(context), &(&1["attributes"]["blocked_user_name"] == name))
    response =
      api_conn(context)
      |> dispatch(HuddlzWeb.Endpoint, :delete, "/api/json/blocks/#{block["id"]}", %{})

    assert response.status in 200..299, response.resp_body
    context
  end

  step "I try to remove the block {string} made through JSON:API",
       %{args: [email]} = context do
    [block] = blocks_by(email)

    response =
      api_conn(context)
      |> dispatch(HuddlzWeb.Endpoint, :delete, "/api/json/blocks/#{block.id}", %{})

    assert response.status in 400..499
    context
  end

  step "{string} still blocks {string}", %{args: [email, blocked]} = context do
    blocked_id = find_user(blocked).id
    assert [%UserBlock{blocked_user_id: ^blocked_id}] = blocks_by(email)
    context
  end

  # ── what the person sees ────────────────────────────────────────────

  step "discovery through JSON:API shows {string}", %{args: [title]} = context do
    assert title in titles(context, "/api/json/huddlz", %{})
    context
  end

  step "discovery through JSON:API does not show {string}", %{args: [title]} = context do
    refute title in titles(context, "/api/json/huddlz", %{})
    context
  end

  step "the group's upcoming huddlz through JSON:API do not show {string}",
       %{args: [title]} = context do
    huddl = find_huddl(title)
    titles = titles(context, "/api/json/huddlz/by_group", %{"group_id" => huddl.group_id})
    refute title in titles
    assert titles != [], "the group should still list its other huddlz"
    context
  end

  step "I can still open {string} through JSON:API", %{args: [title]} = context do
    huddl = find_huddl(title)

    assert %{"data" => %{"id" => id}} =
             api_conn(context)
             |> dispatch(HuddlzWeb.Endpoint, :get, "/api/json/huddlz/#{huddl.id}", %{})
             |> json_response(200)

    assert id == huddl.id
    context
  end

  step "JSON:API says I organized {string}", %{args: [title]} = context do
    assert organized_by_me(context, title) == true
    context
  end

  step "JSON:API says I did not organize {string}", %{args: [title]} = context do
    assert organized_by_me(context, title) == false
    context
  end

  # ── helpers ─────────────────────────────────────────────────────────

  defp organized_by_me(context, title) do
    api_conn(context)
    |> dispatch(HuddlzWeb.Endpoint, :get, "/api/json/huddlz/#{find_huddl(title).id}", %{})
    |> json_response(200)
    |> get_in(["data", "attributes", "organized_by_me"])
  end

  defp titles(context, path, params) do
    api_conn(context)
    |> dispatch(HuddlzWeb.Endpoint, :get, path, params)
    |> json_response(200)
    |> Map.fetch!("data")
    |> Enum.map(& &1["attributes"]["title"])
  end

  defp blocks(context) do
    api_conn(context)
    |> dispatch(HuddlzWeb.Endpoint, :get, "/api/json/blocks", %{})
    |> json_response(200)
    |> Map.fetch!("data")
  end

  defp blocks_by(email) do
    UserBlock
    |> Ash.Query.filter(blocker_id == ^find_user(email).id)
    |> Ash.read!(authorize?: false)
  end

  defp post(context, path, type, attributes) do
    api_conn(context)
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
    |> dispatch(HuddlzWeb.Endpoint, :post, path, %{
      "data" => %{"type" => type, "attributes" => attributes}
    })
  end

  defp api_conn(%{current_user: %User{} = user}), do: authenticated_conn(build_conn(), user)
  defp api_conn(_context), do: build_conn()

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.for_read(:read_for_group_lifecycle)
    |> Ash.Query.filter(title == ^title)
    |> Ash.read_one!(authorize?: false)
  end
end
