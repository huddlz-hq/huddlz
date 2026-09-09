defmodule DiscoverCombinedSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Phoenix.LiveViewTest
  import Huddlz.Test.MoxHelpers

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  require Ash.Query

  step "I expand the discover distance to {int} miles", %{args: [distance]} = context do
    context.session.view
    |> form("#distance-filter-form", %{"distance_miles" => Integer.to_string(distance)})
    |> render_change()

    render_async(context.session.view)
    context
  end

  step "{string} has Austin as their home search location", %{args: [email]} = context do
    member = lookup_user(email)

    Huddlz.Accounts.update_home_location!(
      member,
      "Austin, TX",
      30.2672,
      -97.7431,
      "America/Chicago",
      actor: member
    )

    context
  end

  step "I change the discover location to Houston", context do
    stub_places_autocomplete(%{
      "Houston" => [
        %{
          place_id: "houston",
          display_text: "Houston, TX, USA",
          main_text: "Houston",
          secondary_text: "TX, USA"
        }
      ]
    })

    stub_place_details(%{
      "houston" => %{latitude: 29.7604, longitude: -95.3698, time_zone: "America/Chicago"}
    })

    view = context.session.view
    view |> element("[aria-label='Edit location']") |> render_click()

    view
    |> element("#location-autocomplete-input")
    |> render_change(%{"location-autocomplete_search" => "Houston"})

    render_async(view)
    view |> element("[role='option']", "Houston") |> render_click()
    render_async(view)
    context
  end

  step "discover groups are based in Austin and Houston", context do
    owner = lookup_user("host+discover-combined@example.com")

    for {name, lat, lng} <- [
          {"Austin Neighbors", 30.2672, -97.7431},
          {"Houston Neighbors", 29.7604, -95.3698}
        ] do
      generate(
        group(
          name: name,
          location: name,
          latitude: lat,
          longitude: lng,
          time_zone: "America/Chicago",
          actor: owner
        )
      )
    end

    context
  end

  step "a group named {string} is owned by {string}",
       %{args: [group_name, owner_email]} = context do
    owner = lookup_user(owner_email)

    generate(
      group(
        name: group_name,
        owner_id: owner.id,
        is_public: true,
        actor: owner
      )
    )

    context
  end

  step "the group {string} has an upcoming huddl titled {string}",
       %{args: [group_name, huddl_title]} = context do
    group = lookup_group(group_name)
    owner = Ash.get!(User, group.owner_id, authorize?: false)

    generate(
      huddl(
        group_id: group.id,
        creator_id: owner.id,
        is_private: false,
        title: huddl_title,
        actor: owner
      )
    )

    context
  end

  defp lookup_user(email) do
    User
    |> Ash.Query.filter(email: email)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_group(name) do
    Group
    |> Ash.Query.filter(name: name)
    |> Ash.read_one!(authorize?: false)
  end
end
