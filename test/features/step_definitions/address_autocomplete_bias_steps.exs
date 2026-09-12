defmodule AddressAutocompleteBiasSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest, only: [visit: 2]
  import Phoenix.LiveViewTest

  step "I add an address from {string}", %{args: [entry_point]} = context do
    group = hd(context.groups)
    path = address_entry_path(entry_point, group, context.current_user)
    session = visit(context[:session] || context[:conn], path)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I search the address book for {string}", %{args: [query]} = context do
    group = hd(context.groups)
    center = %{latitude: group.latitude, longitude: group.longitude}

    # The provider fixture ranks the local match first only when the caller
    # supplies the group's home city. This checks the complete UI request path.
    Mox.stub(Huddlz.MockPlaces, :autocomplete, fn ^query, _token, opts ->
      local = suggestion("local", "222 W King St, Saint Augustine, FL")
      distant = suggestion("distant", "222 W King St, Lancaster, PA")

      results =
        if opts[:location_bias] == center,
          do: [local, distant],
          else: [distant, local]

      {:ok, results}
    end)

    session = context[:session] || context[:conn]

    session.view
    |> element("#modal-address-autocomplete-input")
    |> render_change(%{"modal-address-autocomplete_search" => query})

    render_async(session.view)
    context
  end

  step "the first address suggestion should be {string}", %{args: [address]} = context do
    session = context[:session] || context[:conn]

    [first | _] =
      session.view |> render() |> Floki.parse_document!() |> Floki.find("[role=option]")

    assert Floki.text(first) =~ address
    context
  end

  defp address_entry_path("the address book", group, _owner),
    do: "/groups/#{group.slug}/locations/new"

  defp address_entry_path("a new huddl", group, _owner),
    do: "/groups/#{group.slug}/huddlz/new/locations/new"

  defp address_entry_path("an existing huddl", group, owner) do
    huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
    "/groups/#{group.slug}/huddlz/#{huddl.id}/edit/locations/new"
  end

  defp suggestion(id, address) do
    %{place_id: id, display_text: address, main_text: address, secondary_text: ""}
  end
end
