defmodule AddressBookUnitsSteps do
  use Cucumber.StepDefinition

  import Huddlz.Test.Helpers.LocationSelection

  step "I choose the address book street address {string}", %{args: [address]} = context do
    session =
      select_location(context.session,
        id: "modal-address-autocomplete",
        display_text: address,
        main_text: "Beach meeting place",
        latitude: 30.292,
        longitude: -81.39,
        time_zone: "America/New_York"
      )

    Map.merge(context, %{session: session, conn: session})
  end
end
