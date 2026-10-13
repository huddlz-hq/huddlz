defmodule ScheduleHuddlApiSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest

  require Ash.Query

  alias Huddlz.Communities.Huddl

  step "I organize a group as an API client", context do
    owner = generate(user())
    group = generate(group(actor: owner, owner_id: owner.id, is_public: true))

    Map.merge(context, %{
      owner: owner,
      group: group,
      conn: authenticated_conn(context.conn, owner)
    })
  end

  step "I schedule a virtual huddl through {string} starting an hour ago",
       %{args: [api]} = context do
    schedule(context, api, DateTime.add(DateTime.utc_now(), -1, :hour))
  end

  step "I schedule a virtual huddl through {string} starting an hour from now",
       %{args: [api]} = context do
    schedule(context, api, DateTime.add(DateTime.utc_now(), 1, :hour))
  end

  step "the huddl is refused because {string} {string}", %{args: [field, message]} = context do
    errors = refusal_errors(context)

    assert Enum.any?(errors, &(&1.field == field and &1.message =~ message)),
           "expected #{field} #{message}, got #{inspect(errors)}"

    context
  end

  step "my group has no huddlz", context do
    assert group_huddlz(context) == []
    context
  end

  step "my group has that huddl", context do
    assert [huddl] = group_huddlz(context)
    assert DateTime.compare(huddl.starts_at, context.starts_at) == :eq
    context
  end

  defp schedule(context, api, starts_at) do
    starts_at = DateTime.truncate(starts_at, :second)

    attributes = %{
      "title" => "Lunchtime check-in",
      "group_id" => context.group.id,
      "event_type" => "virtual",
      "virtual_link" => "https://meet.example.com/lunch",
      "starts_at" => DateTime.to_iso8601(starts_at),
      "ends_at" => DateTime.to_iso8601(DateTime.add(starts_at, 1, :hour))
    }

    response = request(context.conn, api, attributes)
    Map.merge(context, %{response: response, api: api, starts_at: starts_at})
  end

  defp request(conn, "JSON:API", attributes) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
    |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
    |> dispatch(HuddlzWeb.Endpoint, :post, "/api/json/huddlz", %{
      "data" => %{"type" => "huddl", "attributes" => attributes}
    })
  end

  defp request(conn, "GraphQL", attributes) do
    input = Map.new(attributes, fn {key, value} -> {camelize(key), value} end)

    gql_post(
      conn,
      """
      mutation ScheduleHuddl($input: CreateHuddlInput!) {
        createHuddl(input: $input) {
          result { id }
          errors { message fields }
        }
      }
      """,
      %{"input" => input}
    )
  end

  defp camelize(key) do
    [first | rest] = String.split(key, "_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end

  defp refusal_errors(%{api: "JSON:API", response: response}) do
    body = Jason.decode!(response.resp_body)
    assert response.status in [400, 422], inspect(body)

    Enum.map(body["errors"], fn error ->
      pointer = get_in(error, ["source", "pointer"]) || ""
      %{field: pointer |> String.split("/") |> List.last(), message: error["detail"] || ""}
    end)
  end

  defp refusal_errors(%{api: "GraphQL", response: response}) do
    body = json_response(response, 200)

    (get_in(body, ["data", "createHuddl", "errors"]) || body["errors"] || [])
    |> Enum.map(&%{field: Enum.join(&1["fields"] || [], ","), message: &1["message"] || ""})
  end

  defp group_huddlz(context) do
    Huddl
    |> Ash.Query.filter(group_id == ^context.group.id)
    |> Ash.read!(authorize?: false)
  end
end
