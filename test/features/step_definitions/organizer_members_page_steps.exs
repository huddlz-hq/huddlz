defmodule OrganizerMembersPageSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  step "{string} is listed under {string}", %{args: [name, heading]} = context do
    names = names_under(context.session, heading)

    assert name in names,
           "expected #{inspect(name)} under #{inspect(heading)}, found #{inspect(names)}"

    context
  end

  step "the menu for {string} offers {string}", %{args: [name, action]} = context do
    assert_has(context.session, menu_for(name), text: action)
    context
  end

  step "the menu for {string} does not offer {string}", %{args: [name, action]} = context do
    assert_has(context.session, menu_for(name))
    refute_has(context.session, "#{menu_for(name)} button", text: action)
    context
  end

  step "there is no menu for {string}", %{args: [name]} = context do
    refute_has(context.session, menu_for(name))
    context
  end

  step "I choose {string} from the menu for {string}", %{args: [action, name]} = context do
    session =
      within(context.session, menu_for(name), fn session ->
        click_button(session, action)
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I confirm with {string}", %{args: [label]} = context do
    session =
      within(context.session, "[role='dialog']", fn session ->
        click_button(session, label)
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  defp menu_for(name), do: "[role='menu'][aria-label='Manage #{name}']"

  # The people named inside the roster section whose heading reads `heading`.
  defp names_under(session, heading) do
    doc = session |> page_html() |> Floki.parse_document!()

    section =
      doc
      |> Floki.find("section[aria-labelledby]")
      |> Enum.find(fn section ->
        [id] = Floki.attribute(section, "aria-labelledby")

        doc
        |> Floki.find("##{id}")
        |> Floki.text()
        |> String.trim() == heading
      end)

    assert section, "no roster section headed #{inspect(heading)}"

    section
    |> Floki.find(".row-title")
    |> Enum.map(&(&1 |> Floki.text() |> String.trim()))
  end

  defp page_html(%PhoenixTest.Live{view: view}), do: Phoenix.LiveViewTest.render(view)
  defp page_html(%PhoenixTest.Static{conn: conn}), do: conn.resp_body
end
