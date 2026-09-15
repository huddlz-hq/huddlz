defmodule AccountReportsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, api_key_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 5, json_response: 2, response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts
  alias Huddlz.Accounts.{AccountReport, User}
  alias Huddlz.Communities.{Group, Huddl}

  # ── sending reports ─────────────────────────────────────────────────

  step "{string} has reported {string} for {string}",
       %{args: [reporter, reported, reason]} = context do
    report!(reporter, reported, reason, nil, nil)
    context
  end

  step "{string} has reported {string} for {string} saying {string}",
       %{args: [reporter, reported, reason, details]} = context do
    report!(reporter, reported, reason, details, nil)
    context
  end

  step "{string} has reported {string} for {string} from the group {string}",
       %{args: [reporter, reported, reason, group_name]} = context do
    report!(reporter, reported, reason, nil, {:group, find_group(group_name).id})
    context
  end

  step "{string} has reported {string} for {string} saying {string} from the huddl {string}",
       %{args: [reporter, reported, reason, details, title]} = context do
    report!(reporter, reported, reason, details, {:huddl, find_huddl(title).id})
    context
  end

  step "{string} reported {string} for {string} two years ago",
       %{args: [reporter, reported, reason]} = context do
    report = report!(reporter, reported, reason, nil, nil)
    sent_at = DateTime.shift(DateTime.utc_now(), year: -2, day: -1)

    Ash.Seed.update!(report, %{
      inserted_at: sent_at,
      expires_at: DateTime.shift(sent_at, year: 2)
    })

    context
  end

  step "I click {string} in the review card", %{args: [label]} = context do
    session =
      within(context.session, ".review-card", fn session -> click_button(session, label) end)

    Map.merge(context, %{session: session, conn: session})
  end

  # ── what is on record ───────────────────────────────────────────────

  step "there are no reports about {string}", %{args: [email]} = context do
    assert reports_about(email) == []
    context
  end

  step "there is exactly {int} report about {string}", %{args: [count, email]} = context do
    assert length(reports_about(email)) == count
    context
  end

  step "{string} has an open report about {string} for {string} saying {string}",
       %{args: [reporter, reported, reason, details]} = context do
    reporter_id = find_user(reporter).id

    assert [%AccountReport{reporter_id: ^reporter_id, handled_at: nil} = report] =
             reports_about(reported)

    assert report.reason == String.to_existing_atom(reason)
    assert report.details == details
    assert DateTime.after?(report.expires_at, DateTime.shift(DateTime.utc_now(), year: 1))
    context
  end

  step "the report about {string} is handled by {string}",
       %{args: [reported, admin]} = context do
    admin_id = find_user(admin).id

    assert [%AccountReport{handled_at: %DateTime{}, handled_by_id: ^admin_id}] =
             reports_about(reported)

    context
  end

  step "no email is sent about the report", context do
    Oban.drain_queue(queue: :notifications)

    for %Swoosh.Email{} = email <- collect_emails([]) do
      refute email.subject =~ ~r/report/i, "unexpected email: #{email.subject}"
      refute (email.text_body || "") =~ ~r/report/i, "unexpected email: #{email.subject}"
    end

    context
  end

  # ── API ─────────────────────────────────────────────────────────────

  step "I use an API key to submit reports", context do
    Map.put(context, :report_authentication, :api_key)
  end

  step "I report {string} for {string} saying {string} through JSON:API",
       %{args: [email, reason, details]} = context do
    attributes = %{
      "reported_user_id" => find_user(email).id,
      "reason" => reason,
      "details" => details
    }

    attributes = if reason == "", do: Map.delete(attributes, "reason"), else: attributes

    response =
      context
      |> report_api_conn()
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> dispatch(HuddlzWeb.Endpoint, :post, "/api/json/account_reports", %{
        "data" => %{
          "type" => "account_report",
          "attributes" => attributes
        }
      })

    Map.put(context, :json_report_response, response)
  end

  step "the JSON:API report is accepted", context do
    response = json_response(context.json_report_response, 201)
    assert %{"type" => "account_report", "id" => id} = response["data"]
    assert is_binary(id)
    refute Map.has_key?(response, "included")
    assert Map.get(response["data"], "relationships", %{}) == %{}
    refute Map.has_key?(response["data"]["attributes"], "reporter_id")
    refute Map.has_key?(response["data"]["attributes"], "handled_by_id")
    context
  end

  step "the JSON:API report is refused", context do
    assert %{"errors" => [_ | _]} = json_response(context.json_report_response, 403)
    context
  end

  step "JSON:API asks for a report reason", context do
    assert %{"errors" => errors} = json_response(context.json_report_response, 400)
    assert Enum.any?(errors, &(&1["detail"] =~ "Say what's wrong"))
    context
  end

  step "the API offers member reporting without account administration", context do
    response =
      gql_as(context.current_user, """
      { __schema { queryType { fields { name } } mutationType { fields { name } } } }
      """)

    schema = response["data"]["__schema"]
    queries = Enum.map(schema["queryType"]["fields"], & &1["name"])
    mutations = Enum.map(schema["mutationType"]["fields"], & &1["name"])

    refute "accountReports" in queries
    refute "platformOverview" in queries
    refute "suspendAccount" in mutations
    refute "restoreAccount" in mutations
    assert "reportAccount" in mutations
    context
  end

  step "JSON:API offers report submission without administration", context do
    spec =
      context
      |> report_api_conn()
      |> dispatch(HuddlzWeb.Endpoint, :get, "/api/json/open_api", %{})
      |> response(200)
      |> Jason.decode!()

    report_routes =
      for {path, operations} <- spec["paths"],
          String.contains?(path, "/account_reports"),
          {method, _operation} <- operations,
          method in ["get", "post", "patch", "put", "delete"],
          do: {path, method}

    assert [{"/api/json/account_reports", "post"}] = report_routes
    context
  end

  step "I report {string} through the API", %{args: [email]} = context do
    target = find_user(email)

    response =
      gql_as(
        context.current_user,
        ~s|mutation { reportAccount(input: {reportedUserId: "#{target.id}", reason: SPAM}) { result { id } errors { message } } }|
      )

    Map.put(context, :api_response, response)
  end

  step "the report is refused", context do
    response = context.api_response
    assert get_in(response, ["data", "reportAccount", "result"]) == nil, inspect(response)

    messages =
      (response["errors"] || get_in(response, ["data", "reportAccount", "errors"]) || [])
      |> Enum.map(& &1["message"])

    assert Enum.any?(messages, &(&1 =~ ~r/forbidden/i)), inspect(response)

    context
  end

  step "the report is accepted", context do
    response = context.api_response
    assert %{"id" => _} = get_in(response, ["data", "reportAccount", "result"]), inspect(response)
    context
  end

  step "I read the reports through the API", context do
    response = gql_as(context.current_user, "{ accountReports { id details } }")
    Map.put(context, :api_response, response)
  end

  step "no reports are returned", context do
    assert context.api_response["data"]["accountReports"] in [nil, []]

    assert Enum.any?(
             context.api_response["errors"],
             &(&1["message"] =~ "Cannot query field \"accountReports\"")
           )

    context
  end

  # ── helpers ─────────────────────────────────────────────────────────

  defp report_api_conn(%{current_user: %User{} = user, report_authentication: :api_key}),
    do: api_key_conn(build_conn(), user)

  defp report_api_conn(%{current_user: %User{} = user}),
    do: authenticated_conn(build_conn(), user)

  defp report_api_conn(_context), do: build_conn()

  defp report!(reporter, reported, reason, details, source) do
    {source_type, source_id} = source || {nil, nil}

    Accounts.report_account!(
      %{
        reported_user_id: find_user(reported).id,
        reason: String.to_existing_atom(reason),
        details: details,
        source_type: source_type,
        source_id: source_id
      },
      actor: find_user(reporter)
    )
  end

  defp reports_about(email) do
    AccountReport
    |> Ash.Query.filter(reported_user_id == ^find_user(email).id)
    |> Ash.read!(authorize?: false)
  end

  defp collect_emails(acc) do
    receive do
      {:email, email} -> collect_emails([email | acc])
    after
      100 -> acc
    end
  end

  defp gql_as(user, query) do
    build_conn()
    |> authenticated_conn(user)
    |> gql_post(query, %{})
    |> json_response(200)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.for_read(:read_for_group_lifecycle)
    |> Ash.Query.filter(title == ^title)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end
