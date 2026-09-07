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
    {:ok, Map.merge(context, %{sitemap_group: group, sitemap_huddl: huddl})}
  end

  step "the scheduled sitemap refresh finishes" do
    assert :ok = Refresh.perform(%Oban.Job{})
  end

  step "the anonymous sitemap index links to XML containing the public canonical pages",
       context do
    index = get(build_conn(), "/sitemap.xml")
    assert response_content_type(index, :xml)
    xml = response(index, 200)
    assert xml =~ "<sitemapindex"
    [_, child] = Regex.run(~r/<loc>([^<]+)<\/loc>/, xml)
    body = build_conn() |> get(URI.parse(child).path) |> response(200)
    assert body =~ "<urlset"
    assert body =~ "/groups/#{context.sitemap_group.slug}</loc>"

    assert body =~
             "/groups/#{context.sitemap_group.slug}/huddlz/#{context.sitemap_huddl.id}</loc>"

    :ok
  end
end
