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

  step "a public group with more than one page of past huddlz", context do
    owner = generate(user())
    group = generate(group(actor: owner))

    huddlz =
      for day <- 1..12 do
        generate(
          past_huddl(
            group_id: group.id,
            creator_id: owner.id,
            title: "Public archive huddl #{day}",
            lifecycle_state: if(day == 12, do: :completed, else: :published),
            starts_at: DateTime.add(DateTime.utc_now(), -day, :day),
            ends_at: DateTime.add(DateTime.utc_now(), -day, :day) |> DateTime.add(3600)
          )
        )
      end

    {:ok, Map.merge(context, %{crawl_group: group, crawl_huddlz: huddlz})}
  end

  step "a crawler follows group discovery to the group's Past link", context do
    [discover] = Floki.attribute(document("/"), "a[href='/discover']", "href")
    [groups] = Floki.attribute(document(discover), "a[href='/discover?scope=groups']", "href")
    [group] = Floki.attribute(document(groups), "a.card", "href")
    [past] = Floki.attribute(document(group), "a#group-huddlz-past", "href")
    assert past == group <> "?tab=past"
    {:ok, Map.put(context, :crawl_document, document(past))}
  end

  step "the crawler can follow archive pages to every past public huddl", context do
    first = context.crawl_document
    [next] = Floki.attribute(first, "a[aria-label='Next page']", "href")
    assert URI.decode_query(URI.parse(next).query) == %{"tab" => "past", "page" => "2"}
    second = document(next)
    [previous] = Floki.attribute(second, "a[aria-label='Previous page']", "href")
    assert huddl_links(document(previous)) == huddl_links(first)
    assert length(huddl_links(first)) == 10
    assert length(huddl_links(second)) == 2
    assert Floki.attribute(second, "a[aria-label='Next page']", "href") == []

    for doc <- [first, second] do
      [canonical] = Floki.attribute(doc, "head link[rel=canonical]", "href")
      assert Floki.attribute(doc, "head meta[property='og:url']", "content") == [canonical]
    end

    assert Floki.attribute(second, "head link[rel=canonical]", "href") == [
             HuddlzWeb.Endpoint.url() <> next
           ]

    for huddl <- context.crawl_huddlz do
      path = "/groups/#{context.crawl_group.slug}/huddlz/#{huddl.id}"
      assert path in (huddl_links(first) ++ huddl_links(second))
      assert Floki.text(document(path)) =~ huddl.title
    end

    [upcoming] = Floki.attribute(second, "a#group-huddlz-upcoming", "href")
    assert upcoming == "/groups/#{context.crawl_group.slug}"
    assert Floki.text(document(upcoming)) =~ "No upcoming huddlz scheduled."
    :ok
  end

  defp document(path),
    do: build_conn() |> get(path) |> html_response(200) |> Floki.parse_document!()

  defp huddl_links(doc), do: Floki.attribute(doc, "a[href*='/huddlz/']", "href")
end
