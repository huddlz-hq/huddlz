defmodule BrowserKeyboardFocusSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Huddlz.Test.MoxHelpers

  alias Fluffy.Playwright.Keyboard

  step "I am signed in and looking at my groups in a browser", %{session: session} do
    member = generate(user(role: :user))
    session |> sign_in(member) |> visit("/groups")
    :ok
  end

  step "I open {string} in a browser", %{args: [page]} = context do
    open_page(context, page)
  end

  step "I press Tab from the top of the page", %{session: session} do
    press(session, by_css("body"), "Tab")
    :ok
  end

  step "I press Tab", %{session: session} do
    Keyboard.press(session, "Tab")
    :ok
  end

  step "I follow the skip link with Enter", %{session: session} do
    Keyboard.press(session, "Enter")
    :ok
  end

  step "{string} has keyboard focus", %{args: [name], session: session} do
    assert_focused(session, name)
    :ok
  end

  step "{string} still has keyboard focus", %{args: [name], session: session} = context do
    # Let the save's reply land before looking.
    session
    |> assert(visible(by_css(context.focus_form <> ":not(.phx-submit-loading)")))
    |> assert_focused(name)

    :ok
  end

  step "keyboard focus is in the page content", %{session: session} do
    assert(session, focused(by_css("#main-content")))
    :ok
  end

  step "the main content landmark has keyboard focus", %{session: session} do
    assert(session, focused(by_role(:main)))
    :ok
  end

  step "keyboard focus is still in the page content", %{session: session} do
    assert(session, attached(by_css("#main-content :focus")))
    :ok
  end

  step "I open the {string} form in a browser", %{args: [form]} = context do
    open_form(context, form)
  end

  step "I save it with {string} left empty", %{args: [label]} = context do
    save_with(context, label, "")
  end

  step "I save it with {string} set to {string}", %{args: [label, value]} = context do
    save_with(context, label, value)
  end

  step "I register without accepting the terms", %{session: session} do
    session
    |> fill(
      by_label("Email", exact: true),
      "focus-#{System.unique_integer([:positive])}@example.com"
    )
    |> fill(by_label("Display Name", exact: true), "Keyboard Person")
    |> fill(by_label("Password", exact: true), "ValidPassword123!")
    |> fill(by_label("Confirm Password", exact: true), "ValidPassword123!")
    |> press(by_css("#registration-form button[type=submit]"), "Enter")

    :ok
  end

  step "I send an invitation twice to someone who already has an account", context do
    invitee = generate(user(role: :user))
    email = to_string(invitee.email)
    save_with(context, "Email", email)
    assert(context.session, visible(flash_info("Invitation sent to #{email}.")))
    save_with(context, "Email", email)
  end

  step "I save the new group without a location", %{session: session} do
    session
    |> fill(by_label("Group name", exact: true), "Keyboard Review Group")
    |> fill(by_label("Description", exact: true), "A group for reviewing keyboard access")
    |> press(by_css("#group-form button[type=submit]"), "Enter")

    :ok
  end

  step "I clear the group location and save", %{session: session} do
    session
    |> click(by_role(by_css("#group-location"), :button, name: "Clear"))
    |> assert(visible(by_css("#group-location-input")))
    |> press(by_css("#edit-group-form button[type=submit]"), "Enter")

    :ok
  end

  step "I finish with an opening line longer than 140 characters", %{session: session} do
    session
    |> fill(by_label("Opening line", exact: true), String.duplicate("a", 141))
    |> press(by_css("#schedule-form button[type=submit]"), "Enter")

    :ok
  end

  step "I try to record turnout without a count", %{session: session} do
    session
    |> click(by_role(by_css("#turnout-nudge"), :button, name: "Add turnout"))
    |> press(by_css("#turnout-form-nudge button[type=submit]"), "Enter")

    :ok
  end

  step "the agreement has keyboard focus and describes what is wrong", %{session: session} do
    session
    |> assert_focused(Huddlz.Legal.acceptance_text())
    |> assert(attribute(focused_field(), "aria-invalid", "true"))
    |> assert_browser("""
    (document.activeElement.getAttribute('aria-describedby') || '').split(/\\s+/).some(id =>
      document.getElementById(id)?.textContent.includes('accept'))
    """)

    :ok
  end

  step "{string} describes what is wrong with it", %{args: [name], session: session} do
    session
    |> assert_focused(name)
    |> assert(attribute(focused_field(), "aria-invalid", "true"))
    |> assert_browser("""
    (document.activeElement.getAttribute('aria-describedby') || '').split(/\\s+/)
      .map(id => document.getElementById(id))
      .some(element => element?.getAttribute('role') === 'alert' && element.textContent.trim() !== '')
    """)

    :ok
  end

  defp open_page(context, "the home page"), do: visit_signed_out(context, "/")
  defp open_page(context, "sign in"), do: visit_signed_out(context, "/sign-in")
  defp open_page(context, "discover"), do: visit_signed_out(context, "/discover")

  defp visit_signed_out(context, path) do
    visit(context.session, path)
    :ok
  end

  defp open_form(context, "sign in"),
    do: signed_out_form(context, "/sign-in", "#password-sign-in-form")

  defp open_form(context, "registration"),
    do: signed_out_form(context, "/register", "#registration-form")

  defp open_form(context, "password reset"),
    do: signed_out_form(context, "/reset", "#reset-password-form")

  defp open_form(context, "profile") do
    member = generate(user(role: :user))
    signed_in_form(context, member, "/profile", "#profile-form")
  end

  defp open_form(context, "new group") do
    member = generate(user(role: :user))
    signed_in_form(context, member, "/groups/new", "#group-form")
  end

  defp open_form(context, "edit group") do
    {owner, group} = owned_group()
    signed_in_form(context, owner, "/groups/#{group.slug}/edit", "#edit-group-form")
  end

  defp open_form(context, "new huddl") do
    {owner, group} = owned_group()

    signed_in_form(
      context,
      owner,
      "/groups/#{group.slug}/huddlz/new",
      "#huddl-form",
      "#publish-huddl"
    )
  end

  defp open_form(context, "edit huddl") do
    {owner, group} = owned_group()
    huddl = generate(huddl(group_id: group.id, actor: owner))

    signed_in_form(
      context,
      owner,
      "/groups/#{group.slug}/huddlz/#{huddl.id}/edit",
      "#huddl-form"
    )
  end

  defp open_form(context, "address book") do
    {owner, group} = owned_group()
    generate(group_location(group_id: group.id, actor: owner))

    signed_in_form(context, owner, "/groups/#{group.slug}/locations", nil)
    click(context.session, by_role(:button, name: "Edit", exact: true))
    %{focus_form: "#location-rename-form"}
  end

  defp open_form(context, "new address") do
    {owner, group} = owned_group()
    stub_places_autocomplete(%{"saint" => [:saint_augustine]})
    stub_place_details(:defaults)

    form =
      signed_in_form(context, owner, "/groups/#{group.slug}/locations/new", "#new-location-form")

    search = by_label("Search for an address", exact: true)

    context.session
    |> fill(search, "saint")
    |> assert(visible(by_role(:option) |> first()))
    |> press(search, "ArrowDown")
    |> assert(attribute(by_css("#modal-address-autocomplete"), "data-has-highlight", "true"))
    |> press(search, "Enter")
    |> assert(enabled(by_css("#new-location-form button[type=submit]")))

    form
  end

  defp open_form(context, "invitation") do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: false, actor: owner))

    signed_in_form(
      context,
      owner,
      "/organize/#{group.slug}/members",
      "#group-invitation-form"
    )
  end

  defp owned_group do
    owner = generate(user(role: :user))
    {owner, generate(group(owner_id: owner.id, is_public: true, actor: owner))}
  end

  defp signed_out_form(context, path, form) do
    visit(context.session, path)
    %{focus_form: form}
  end

  defp signed_in_form(context, member, path, form, submit \\ nil) do
    context.session |> sign_in(member) |> visit(path)
    %{focus_form: form, focus_submit: submit}
  end

  # Clear or set the field, then press Enter on the form's submit button,
  # the way a keyboard user saves.
  defp save_with(context, label, value) do
    submit = context[:focus_submit] || context.focus_form <> " button[type=submit]"

    context.session
    |> fill(by_label(by_css(context.focus_form), label, exact: true), value)
    |> press(by_css(submit), "Enter")

    :ok
  end

  defp flash_info(text), do: by_css("#flash-info") |> filter(has_text: text)

  defp focused_field, do: by_css(":focus")

  # A control's accessible name: its label, else its aria-label, else its own text.
  defp assert_focused(session, name), do: assert(session, accessible_name(focused_field(), name))
end
