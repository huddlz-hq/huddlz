defmodule BrowserKeyboardFocusSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Huddlz.Test.MoxHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  step "I am signed in and looking at my groups in a browser", context do
    member = generate(user(role: :user))
    conn = context.conn |> sign_in(member) |> visit("/groups") |> assert_has(".phx-connected")
    Map.put(context, :conn, conn)
  end

  step "I open {string} in a browser", %{args: [page]} = context do
    open_page(context, page)
  end

  step "I press Tab from the top of the page", context do
    Map.put(context, :conn, press(context.conn, "body", "Tab"))
  end

  step "I press Tab", context do
    Map.put(context, :conn, press(context.conn, ":focus", "Tab"))
  end

  step "I follow the skip link with Enter", context do
    Map.put(context, :conn, press(context.conn, ":focus", "Enter"))
  end

  step "{string} has keyboard focus", %{args: [name]} = context do
    assert_focused(context.conn, name)
    context
  end

  step "{string} still has keyboard focus", %{args: [name]} = context do
    # Let the save's reply land before looking.
    context.conn |> assert_has(context.focus_form <> ":not(.phx-submit-loading)")
    assert_focused(context.conn, name)
    context
  end

  step "keyboard focus is in the page content", context do
    assert_browser(context.conn, "document.activeElement.id === 'main-content'")
    context
  end

  step "the main content landmark has keyboard focus", context do
    assert_browser(context.conn, "document.activeElement.matches('main, [role=main]')")
    context
  end

  step "keyboard focus is still in the page content", context do
    assert_browser(context.conn, """
    document.activeElement !== document.getElementById('main-content') &&
      document.getElementById('main-content').contains(document.activeElement)
    """)

    context
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

  step "I register without accepting the terms", context do
    conn =
      context.conn
      |> fill_in("Email", with: "focus-#{System.unique_integer([:positive])}@example.com")
      |> fill_in("Display Name", with: "Keyboard Person")
      |> fill_in("Password", with: "ValidPassword123!")
      |> fill_in("Confirm Password", with: "ValidPassword123!")
      |> press("#registration-form button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "I send an invitation twice to someone who already has an account", context do
    invitee = generate(user(role: :user))
    email = to_string(invitee.email)
    context = save_with(context, "Email", email)
    assert_has(context.conn, "#flash-info", text: "Invitation sent to #{email}.")
    save_with(context, "Email", email)
  end

  step "I save the new group without a location", context do
    conn =
      context.conn
      |> fill_in("Group name", with: "Keyboard Review Group")
      |> fill_in("Description", with: "A group for reviewing keyboard access")
      |> press("#group-form button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "I clear the group location and save", context do
    conn =
      context.conn
      |> within("#group-location", &click_button(&1, "Clear"))
      |> assert_has("#group-location-input")
      |> press("#edit-group-form button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "I finish with an opening line longer than 140 characters", context do
    conn =
      context.conn
      |> fill_in("Opening line", with: String.duplicate("a", 141))
      |> press("#schedule-form button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "I try to record turnout without a count", context do
    conn =
      context.conn
      |> click_button("#turnout-nudge button", "Add turnout")
      |> press("#turnout-form-nudge button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "the agreement has keyboard focus and describes what is wrong", context do
    assert_focused(context.conn, Huddlz.Legal.acceptance_text())

    assert_browser(context.conn, """
    (() => {
      const field = document.activeElement;
      return field.getAttribute('aria-invalid') === 'true' &&
        (field.getAttribute('aria-describedby') || '').split(/\\s+/).some(id =>
          document.getElementById(id)?.textContent.includes('accept'));
    })()
    """)

    context
  end

  step "{string} describes what is wrong with it", %{args: [name]} = context do
    assert_browser(context.conn, """
    (() => {
      const field = document.activeElement;
      const described = (field.getAttribute('aria-describedby') || '').split(/\\s+/)
        .map(id => document.getElementById(id))
        .filter(element => element?.getAttribute('role') === 'alert');
      return #{label_matches("field")} === #{Jason.encode!(name)} &&
        field.getAttribute('aria-invalid') === 'true' &&
        described.some(element => element.textContent.trim() !== '');
    })()
    """)

    context
  end

  defp open_page(context, "the home page"), do: visit_signed_out(context, "/")
  defp open_page(context, "sign in"), do: visit_signed_out(context, "/sign-in")
  defp open_page(context, "discover"), do: visit_signed_out(context, "/discover")

  defp visit_signed_out(context, path) do
    Map.put(context, :conn, context.conn |> visit(path) |> assert_has(".phx-connected"))
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

    context = signed_in_form(context, owner, "/groups/#{group.slug}/locations", nil)
    conn = click_button(context.conn, "Edit")
    Map.merge(context, %{conn: conn, focus_form: "#location-rename-form"})
  end

  defp open_form(context, "new address") do
    {owner, group} = owned_group()
    stub_places_autocomplete(%{"saint" => [:saint_augustine]})
    stub_place_details(:defaults)

    context =
      signed_in_form(context, owner, "/groups/#{group.slug}/locations/new", "#new-location-form")

    conn =
      context.conn
      |> fill_in("Search for an address", with: "saint")
      |> assert_has("[role='option']")
      |> press("#modal-address-autocomplete-input", "ArrowDown")
      |> assert_has("#modal-address-autocomplete[data-has-highlight='true']")
      |> press("#modal-address-autocomplete-input", "Enter")
      |> assert_has("#new-location-form button[type=submit]:not([disabled])")

    Map.put(context, :conn, conn)
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
    context |> visit_signed_out(path) |> Map.put(:focus_form, form)
  end

  defp signed_in_form(context, member, path, form, submit \\ nil) do
    conn = context.conn |> sign_in(member) |> visit(path) |> assert_has(".phx-connected")
    Map.merge(context, %{conn: conn, focus_form: form, focus_submit: submit})
  end

  # Clear or set the field, then press Enter on the form's submit button,
  # the way a keyboard user saves.
  defp save_with(context, label, value) do
    submit = context[:focus_submit] || context.focus_form <> " button[type=submit]"

    conn =
      context.conn
      |> within(context.focus_form, &fill_in(&1, label, with: value))
      |> press(submit, "Enter")

    Map.put(context, :conn, conn)
  end

  defp assert_focused(conn, name) do
    assert_browser(conn, """
    (() => {
      const field = document.activeElement;
      return #{label_matches("field")} === #{Jason.encode!(name)};
    })()
    """)
  end

  # The accessible name the step reads: a control's label, else its
  # aria-label, else its own text.
  defp label_matches(var) do
    """
    ((#{var}.labels && #{var}.labels[0]?.textContent) ||
      #{var}.getAttribute('aria-label') || #{var}.textContent || '').replace(/\\s+/g, ' ').trim()
    """
  end
end
