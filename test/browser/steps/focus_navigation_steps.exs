defmodule BrowserFocusSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Huddlz.Test.MoxHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  step "I am signed in on the groups page for keyboard navigation", context do
    member = generate(user(role: :user))
    conn = context.conn |> sign_in(member) |> visit("/groups") |> assert_has(".phx-connected")
    Map.put(context, :conn, conn)
  end

  step "I use the skip link", context do
    conn =
      context.conn
      |> press("body", "Tab")
      |> assert_has("a.skip-link:focus-visible")
      |> press(":focus", "Enter")

    Map.put(context, :conn, conn)
  end

  step "keyboard focus is in the main content", context do
    context.conn |> assert_has("main#main-content:focus")
    context
  end

  step "I follow the profile link", context do
    Map.put(context, :conn, press(context.conn, "#sidebar-user", "Enter"))
  end

  step "the new page context receives keyboard focus", context do
    context.conn |> assert_has("main h1:focus") |> assert_has("#page-context", text: "Profile")
    context
  end

  step "I open sign in for keyboard navigation", context do
    Map.put(context, :conn, context.conn |> visit("/sign-in") |> assert_has(".phx-connected"))
  end

  step "I submit the empty sign in form", context do
    Map.put(
      context,
      :conn,
      press(context.conn, "#password-sign-in-form button[type=submit]", "Enter")
    )
  end

  step "the error summary receives focus and links to the invalid email", context do
    context.conn
    |> assert_has(".error-summary:focus")
    |> assert_has(".error-summary a[href='#user_email']")

    context
  end

  step "I follow the email error link", context do
    Map.put(context, :conn, press(context.conn, ".error-summary a[href='#user_email']", "Enter"))
  end

  step "the email field receives focus and describes its error", context do
    context.conn
    |> assert_has("#user_email:focus[aria-invalid=true][aria-describedby]")
    |> assert_browser("""
    (() => {
      const style = getComputedStyle(document.activeElement);
      return style.outlineStyle !== 'none' || style.boxShadow !== 'none';
    })()
    """)

    context
  end

  step "I submit an empty display name", context do
    conn =
      context.conn
      |> fill_in("Display name", with: "")
      |> press("#profile-form button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "the profile error summary receives focus", context do
    context.conn |> assert_has("#profile-form .error-summary:focus")
    context
  end

  step "I correct my display name", context do
    {:ok, _} =
      PlaywrightEx.Frame.fill(context.conn.frame_id,
        selector: "#profile-form input[name=\"form[display_name]\"]",
        value: "Keyboard member",
        timeout: 5000
      )

    context
  end

  step "typing focus stays in the display name field", context do
    context.conn
    |> assert_has("#profile-form input:focus")
    |> assert_browser("document.activeElement.value === 'Keyboard member'")
    |> refute_has("#profile-form .error-summary")

    context
  end

  step "I save my corrected profile", context do
    Map.put(context, :conn, press(context.conn, "#profile-form button[type=submit]", "Enter"))
  end

  step "the account information heading receives focus", context do
    context.conn |> assert_has("#profile-form h2:focus", text: "Account information")
    context
  end

  step "I open the {string} form as a group owner", %{args: [surface]} = context do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: surface != "invitation", actor: owner))

    {path, selector} =
      case surface do
        "group" ->
          {"/groups/#{group.slug}/edit", "#edit-group-form"}

        "huddl" ->
          {"/groups/#{group.slug}/huddlz/new", "#huddl-form"}

        "invitation" ->
          {"/organize/#{group.slug}/members", "#group-invitation-form"}

        "address book" ->
          generate(group_location(group_id: group.id, actor: owner))
          {"/groups/#{group.slug}/locations", "#location-rename-form"}
      end

    conn = context.conn |> sign_in(owner) |> visit(path) |> assert_has(".phx-connected")
    conn = if surface == "address book", do: click_button(conn, "Rename"), else: conn
    Map.merge(context, %{conn: conn, focus_form: selector})
  end

  step "I submit that form with an empty {string}", %{args: [label]} = context do
    conn =
      context.conn
      |> fill_in(label, with: "")
      |> press(context.focus_form <> " button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "that form shows a focused error summary with an invalid field link", context do
    context.conn
    |> assert_has(context.focus_form <> " .error-summary:focus")
    |> assert_browser("""
    (() => {
      const summary = document.activeElement;
      return [...summary.querySelectorAll('a')].every(link => {
        const field = document.getElementById(link.hash.slice(1));
        return field?.getAttribute('aria-invalid') === 'true' && field.getAttribute('aria-describedby');
      });
    })()
    """)

    context
  end

  step "I open the address dialog and dismiss it with Escape", context do
    conn =
      context.conn
      |> click_button("Cancel")
      |> click_link("Add Address")
      |> assert_has("#new-location-modal input:focus")
      |> press(":focus", "Tab")
      |> press(":focus", "Escape")

    Map.put(context, :conn, conn)
  end

  step "focus returns to Add Address", context do
    context.conn |> assert_browser("!document.querySelector('#new-location-modal')")
    context.conn |> assert_has("a:focus", text: "Add Address")
    context
  end

  step "I open group archival and dismiss it with Escape", context do
    conn =
      context.conn
      |> press("#archive-group", "Enter")
      |> assert_has("#archive-group-dialog button:focus")
      |> press(":focus", "Escape")

    Map.put(context, :conn, conn)
  end

  step "focus returns to Archive group", context do
    context.conn |> assert_has("#archive-group:focus")
    context
  end

  step "I confirm group archival", context do
    conn =
      context.conn
      |> press("#archive-group", "Enter")
      |> assert_has("#archive-group-dialog button:focus")
      |> click_button("Yes, archive group")

    Map.put(context, :conn, conn)
  end

  step "the archived group's page receives focus and is announced", context do
    context.conn
    |> assert_has("main h1:focus")
    |> assert_browser("""
    document.querySelector('#page-context').textContent.trim() ===
      document.querySelector('main h1').textContent.trim()
    """)

    context
  end

  step "I open member management with a member to promote", context do
    owner = generate(user(role: :user))
    member = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, actor: owner))
    generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/organize/#{group.slug}/members")
      |> assert_has(".phx-connected")

    Map.put(context, :conn, conn)
  end

  step "I open promotion and dismiss it with Escape", context do
    conn =
      context.conn
      |> press("button[id^=promote-member-]", "Enter")
      |> assert_has("#member-action-dialog button:focus")
      |> press(":focus", "Escape")

    Map.put(context, :conn, conn)
  end

  step "focus returns to Promote", context do
    context.conn |> assert_has("button[id^=promote-member-]:focus")
    context
  end

  step "I confirm the member promotion", context do
    conn =
      context.conn
      |> press("button[id^=promote-member-]", "Enter")
      |> assert_has("#member-action-dialog button:focus")
      |> press("#member-action-confirm", "Enter")

    Map.put(context, :conn, conn)
  end

  step "focus returns to the member page content", context do
    context.conn |> assert_has("#main-content:focus") |> assert_has("button[id^=demote-member-]")
    context
  end

  step "I save a new address-book name", context do
    conn =
      context.conn
      |> fill_in("Location name", with: "Community room")
      |> press("#location-rename-form button[type=submit]", "Enter")
      |> assert_has(".row-title", text: "Community room")

    Map.put(context, :conn, conn)
  end

  step "I open a new address dialog from {string}", %{args: [surface]} = context do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, actor: owner))

    {path, link} =
      case surface do
        "address book" ->
          {"/groups/#{group.slug}/locations", "Add Address"}

        "huddl creation" ->
          {"/groups/#{group.slug}/huddlz/new", "Add new address"}

        "huddl editing" ->
          huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
          {"/groups/#{group.slug}/huddlz/#{huddl.id}/edit", "Add new address"}
      end

    conn =
      context.conn
      |> sign_in(owner)
      |> visit(path)
      |> assert_has(".phx-connected")
      |> click_link(link)
      |> assert_has("#new-location-modal input:focus")

    Map.merge(context, %{conn: conn, location_surface: surface})
  end

  step "I try to save a new address with a name longer than 200 characters", context do
    stub_places_autocomplete(%{"saint" => [:saint_augustine]})
    stub_place_details(:defaults)

    conn =
      context.conn
      |> fill_in("Search for an address", with: "saint")
      |> assert_has("#modal-address-autocomplete [role=option]")
      |> press("#modal-address-autocomplete-input", "ArrowDown")
      |> assert_has("#modal-address-autocomplete[data-has-highlight=true]")
      |> press("#modal-address-autocomplete-input", "Enter")
      |> assert_has("#new-location-form button[type=submit]:not([disabled])")
      |> fill_in("Location name (optional)", with: String.duplicate("a", 201))
      |> press("#new-location-form button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "the address dialog focuses a summary linking to the invalid name", context do
    context.conn
    |> assert_has("#new-location-modal .error-summary:focus")
    |> assert_has("#new-location-modal .error-summary a[href='#location-name-input']")
    |> assert_has("#location-name-input[aria-invalid=true][aria-describedby]")

    context
  end

  step "I follow the location name error and correct it", context do
    conn =
      context.conn
      |> press(".error-summary a[href='#location-name-input']", "Enter")
      |> assert_has("#location-name-input:focus")
      |> assert_browser("""
      document.getElementById(document.activeElement.getAttribute('aria-describedby'))
        .textContent.includes('200')
      """)
      |> fill_in("Location name (optional)", with: "Community room")
      |> press("#new-location-form button[type=submit]", "Enter")

    Map.put(context, :conn, conn)
  end

  step "I can save the address and return to the page", context do
    conn = refute_has(context.conn, "#new-location-modal")

    case context.location_surface do
      "address book" ->
        conn
        |> assert_has(".row-title", text: "Community room")
        |> assert_has("#add-address:focus")

      _huddl ->
        conn
        |> assert_has("[data-testid=saved-location-display]", text: "Community room")
        |> assert_has("#main-content:focus")
    end

    context
  end
end
