defmodule SearchIndexingSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn, only: [get_resp_header: 2]
  @endpoint HuddlzWeb.Endpoint

  step "a crawler visits account access pages with and without a return destination", context do
    responses =
      for path <- ["/sign-in", "/register", "/reset", "/account-suspended"],
          query <- ["", "?return_to=%2Fgroups%2Fcode-and-coffee"] do
        conn = get(build_conn(), path <> query)
        assert html_response(conn, 200)
        conn
      end

    {:ok, Map.put(context, :account_access_responses, responses)}
  end

  step "each account access response asks search engines not to index it", context do
    for conn <- context.account_access_responses do
      assert get_resp_header(conn, "x-robots-tag") == ["noindex"],
             "Expected a search exclusion for #{conn.request_path}?#{conn.query_string}"
    end

    :ok
  end

  step "public discovery, group and huddl pages still allow indexing", context do
    group_path = "/groups/#{context.sitemap_group.slug}"

    for path <- [
          "/",
          "/discover",
          "/discover?scope=groups",
          group_path,
          "#{group_path}/huddlz/#{context.sitemap_huddl.id}"
        ] do
      conn = get(build_conn(), path)
      assert html_response(conn, 200)
      assert get_resp_header(conn, "x-robots-tag") == []
    end

    :ok
  end
end
