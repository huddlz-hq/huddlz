defmodule HuddlMapLinksSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  step "I can view the huddl's physical location on Google Maps in a new tab", context do
    [huddl | _] = context.huddlz
    query = URI.encode_www_form(huddl.physical_location)

    assert_has(
      context.session,
      "a[href='https://www.google.com/maps/search/?api=1&query=#{query}'][target='_blank']",
      text: "View on map"
    )

    context
  end
end
