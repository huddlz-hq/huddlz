defmodule CrawlableLinksSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Huddlz.Generator
  import Phoenix.ConnTest
  @endpoint HuddlzWeb.Endpoint

  step "more than one page of public huddlz for crawling", context do
    owner = generate(user())
    group = generate(group(actor: owner))

    huddlz =
      for day <- 1..21 do
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            title: "Crawl huddl #{day}",
            date: Date.add(Date.utc_today(), day),
            event_type: :virtual,
            virtual_link: "https://example.test/join"
          )
        )
      end

    {:ok, Map.merge(context, %{crawl_group: group, crawl_huddlz: huddlz})}
  end

  step "a crawler follows Browse huddlz from the home page", context do
    home = document("/")
    [href] = Floki.attribute(home, "a[href='/discover']", "href")
    {:ok, Map.put(context, :crawl_document, document(href))}
  end

  step "the crawler can follow discovery pages to every public huddl", context do
    first = context.crawl_document
    [next] = Floki.attribute(first, "a[aria-label='Next page']", "href")
    second = document(next)
    [previous] = Floki.attribute(second, "a[aria-label='Previous page']", "href")
    assert previous == "/discover"
    assert huddl_links(document(previous)) == huddl_links(first)
    links = huddl_links(first) ++ huddl_links(second)

    for huddl <- context.crawl_huddlz do
      path = "/groups/#{context.crawl_group.slug}/huddlz/#{huddl.id}"
      assert path in links
      assert Floki.text(document(path)) =~ huddl.title
    end

    :ok
  end

  defp document(path),
    do: build_conn() |> get(path) |> html_response(200) |> Floki.parse_document!()

  defp huddl_links(doc), do: Floki.attribute(doc, "a[href*='/huddlz/']", "href")
end
