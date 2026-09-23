defmodule HuddlMapLinksSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  @maps_search "https://www.google.com/maps/search/?api=1&query="

  step "I can view the huddl's physical location on Google Maps in a new tab", context do
    [huddl | _] = context.huddlz
    query = URI.encode_www_form(huddl.physical_location)

    assert_has(
      context.session,
      "a[href='#{@maps_search}#{query}'][target='_blank']",
      text: "View on map"
    )

    context
  end

  step "the map link for the huddl points to the place {string}", %{args: [place_id]} = context do
    huddl = context.current_huddl
    query = URI.encode_www_form(huddl.physical_location)

    assert_has(
      context.session,
      "a[href='#{@maps_search}#{query}&query_place_id=#{URI.encode_www_form(place_id)}'][target='_blank']",
      text: "View on map"
    )

    context
  end

  step "the map link for the huddl points to the coordinates {float}, {float}",
       %{args: [lat, lng]} = context do
    query = URI.encode_www_form("#{lat},#{lng}")

    assert_has(
      context.session,
      "a[href='#{@maps_search}#{query}'][target='_blank']",
      text: "View on map"
    )

    context
  end
end
