defmodule AccountReportsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
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
    context
  end

  # ── helpers ─────────────────────────────────────────────────────────

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
