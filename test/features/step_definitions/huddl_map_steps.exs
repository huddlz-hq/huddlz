defmodule HuddlMapSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Communities.Group

  require Ash.Query

  step "the group {string} has a virtual huddl {string}",
       %{args: [group_name, title]} = context do
    group = Group |> Ash.Query.filter(name == ^group_name) |> Ash.read_one!(authorize?: false)
    owner = Enum.find(context.users, &(&1.id == group.owner_id))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          title: title,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/planning",
          actor: owner
        )
      )

    Map.put(context, :current_huddl, huddl)
  end

  step "I see a map of the place {string}", %{args: [place_id]} = context do
    assert_has(context.session, "iframe[src*='#{URI.encode_www_form("place_id:" <> place_id)}']")
    context
  end

  step "I see a map at the coordinates {float}, {float}", %{args: [lat, lng]} = context do
    assert_has(context.session, "iframe[src*='#{URI.encode_www_form("#{lat},#{lng}")}']")
    context
  end

  step "I see no map", context do
    refute_has(context.session, "iframe")
    context
  end
end
