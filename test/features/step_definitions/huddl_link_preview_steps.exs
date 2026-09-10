defmodule HuddlLinkPreviewSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  @description "Bring your lunch and meet the community."

  step "a public huddl {string} in {string} on {word} at {word}",
       %{args: [title, time_zone, date, time]} = context do
    owner = generate(user(role: :user))

    group =
      generate(group(is_public: true, time_zone: time_zone, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          is_private: false,
          title: title,
          description: @description,
          date: Date.from_iso8601!(date),
          start_time: Time.from_iso8601!(time <> ":00"),
          duration_minutes: 60,
          actor: owner
        )
      )

    Map.merge(context, %{group: group, huddl: huddl})
  end

  step "the preview title reads {string}", %{args: [title]} = context do
    document = Floki.parse_document!(context.page_html)

    assert meta(document, ~s(meta[property="og:title"])) == [title]
    assert meta(document, ~s(meta[name="twitter:title"])) == [title]

    context
  end

  step "the huddl page shows {string}", %{args: [text]} = context do
    body =
      context.page_html
      |> Floki.parse_document!()
      |> Floki.find("body")
      |> Floki.text()

    assert body =~ text, "expected the page body to show #{inspect(text)}"
    context
  end

  step "the preview still carries the huddl's description and picture", context do
    document = Floki.parse_document!(context.page_html)

    assert meta(document, ~s(meta[property="og:description"])) == [@description]

    assert meta(document, ~s(meta[property="og:image"])) ==
             [HuddlzWeb.Endpoint.url() <> "/og/huddlz/#{context.huddl.id}/card.png"]

    context
  end

  defp meta(document, selector), do: Floki.attribute(document, selector, "content")
end
