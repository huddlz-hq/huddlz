defmodule ApiDiscoveryOrderingSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  step "these public upcoming huddlz are available for API discovery:", context do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    now = DateTime.utc_now()

    for row <- context.datatable.maps do
      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            title: row["title"],
            date: Date.add(DateTime.to_date(now), String.to_integer(row["starts in days"])),
            is_private: false
          )
        )

      Ash.Seed.update!(huddl, %{
        inserted_at: DateTime.add(now, -String.to_integer(row["created days ago"]), :day)
      })
    end

    context
  end

  step "I discover upcoming huddlz through the API ordered by {string} without signing in",
       %{args: [ordering]} = context do
    discover(context, %{"date_filter" => "upcoming", "sort" => ordering})
  end

  step "I discover upcoming huddlz through the API without choosing an ordering or signing in",
       context do
    discover(context, %{"date_filter" => "upcoming"})
  end

  step "the discovery API should return huddlz in this order:", context do
    response = Phoenix.ConnTest.json_response(context.discovery_response, 200)

    assert Enum.map(response["data"], & &1["attributes"]["title"]) ==
             Enum.map(context.datatable.maps, & &1["title"])

    context
  end

  defp discover(context, params) do
    conn =
      context.conn
      |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
      |> Phoenix.ConnTest.dispatch(HuddlzWeb.Endpoint, :get, "/api/json/huddlz", params)

    Map.put(context, :discovery_response, conn)
  end
end
