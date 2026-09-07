defmodule SitemapSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Huddlz.Generator
  import Phoenix.ConnTest
  alias Huddlz.Sitemaps.Refresh
  @endpoint HuddlzWeb.Endpoint

  step "a public group with a published huddl for sitemap discovery", context do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: host, is_private: false))
    {:ok, Map.merge(context, %{sitemap_host: host, sitemap_group: group, sitemap_huddl: huddl})}
  end

  step "the scheduled sitemap refresh finishes" do
    assert :ok = Refresh.perform(%Oban.Job{})
  end

  step "a crawler has cached the sitemap child containing that huddl", context do
    assert :ok = Refresh.perform(%Oban.Job{})

    {child, body} =
      Enum.find(sitemap_children(), fn {_child, body} ->
        body =~ "/huddlz/#{context.sitemap_huddl.id}</loc>"
      end)

    {:ok, Map.merge(context, %{cached_sitemap_child: child, cached_sitemap_body: body})}
  end

  step "another public group is published and the sitemap refreshes", context do
    group = generate(group(actor: context.sitemap_host, is_public: true))
    assert :ok = Refresh.perform(%Oban.Job{})

    assert Enum.any?(sitemap_children(), fn {_child, body} ->
             body =~ "/groups/#{group.slug}</loc>"
           end)

    {:ok, Map.put(context, :other_sitemap_group, group)}
  end

  step "that other group is deleted and the sitemap refreshes", context do
    Ash.destroy!(context.other_sitemap_group, actor: context.sitemap_host)
    assert :ok = Refresh.perform(%Oban.Job{})

    refute Enum.any?(sitemap_children(), fn {_child, body} ->
             body =~ "/groups/#{context.other_sitemap_group.slug}</loc>"
           end)

    :ok
  end

  step "the current sitemap still links to the cached huddl child", context do
    assert {context.cached_sitemap_child, context.cached_sitemap_body} in sitemap_children()
    :ok
  end

  step "the anonymous sitemap index links to XML containing the public canonical pages",
       context do
    index = get(build_conn(), "/sitemap.xml")
    assert response_content_type(index, :xml)
    xml = response(index, 200)
    assert xml =~ "<sitemapindex"
    body = Enum.map_join(sitemap_children(), fn {_child, body} -> body end)
    assert body =~ "<urlset"
    assert body =~ "/groups/#{context.sitemap_group.slug}</loc>"

    assert body =~
             "/groups/#{context.sitemap_group.slug}/huddlz/#{context.sitemap_huddl.id}</loc>"

    :ok
  end

  defp sitemap_children do
    index = build_conn() |> get("/sitemap.xml") |> response(200)

    for [_, child] <- Regex.scan(~r/<loc>([^<]+)<\/loc>/, index) do
      {child, build_conn() |> get(URI.parse(child).path) |> response(200)}
    end
  end
end
