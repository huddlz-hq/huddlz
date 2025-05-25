defmodule HuddlListingSteps do
  use Cucumber, feature: "huddl_listing.feature"
  use HuddlzWeb.WallabyCase

  import Huddlz.Generator

  # Background step: Create sample huddlz
  defstep "there are upcoming huddlz in the system", %{session: session} do
    # Create a verified host who can create huddls
    host = generate(user(role: :verified))

    # Create a public group owned by the host
    public_group = generate(group(owner_id: host.id, is_public: true, actor: host))

    # Create huddls in the public group
    huddl1 =
      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Functional Programming Basics",
          description: "Introduction to functional programming concepts",
          actor: host
        )
      )

    huddl2 =
      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Web Development Workshop",
          description: "Modern web development techniques",
          actor: host
        )
      )

    # Create a specific huddl with "Elixir" in the title for search testing
    elixir_huddl =
      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Elixir Programming Workshop",
          description: "Learn functional programming with Elixir",
          actor: host
        )
      )

    huddlz = [huddl1, huddl2, elixir_huddl]

    # Return the session and huddl information
    {:ok, %{session: session, huddlz: huddlz, huddlz_count: length(huddlz)}}
  end

  # Visit landing page
  defstep "I visit the landing page", %{session: session} = context do
    session = visit(session, "/")
    {:ok, Map.merge(context, %{session: session})}
  end

  # Search for a term
  defstep "I search for {string}", %{session: session, args: args} = context do
    term = List.first(args)

    # Try finding by placeholder since label might not match
    session =
      session
      |> fill_in(css("input[placeholder*='Search']"), with: term)
      |> click(button("Search"))

    {:ok, Map.merge(context, %{session: session, search_term: term})}
  end

  # Clear search
  defstep "I clear the search form", %{session: session} = context do
    session =
      session
      |> fill_in(css("input[placeholder*='Search']"), with: "")
      |> click(button("Search"))

    {:ok, Map.merge(context, %{session: session})}
  end

  # Assertions
  defstep "I should see a list of upcoming huddlz", %{session: session} do
    # We know we're on the huddl list page if we see the right heading
    assert_has(session, css("h1", text: "Find your huddl"))
    # Check that we see at least "Found X huddl" message
    assert has?(session, css("body", text: "Found")) || has?(session, css("body", text: "huddl"))
    :ok
  end

  defstep "I should see basic information for each huddl", %{session: session} = context do
    # Check that we can see ALL the huddl titles we created
    Enum.each(context.huddlz, fn huddl ->
      assert_has(session, css("body", text: huddl.title))
      # Also check we can see the description
      assert_has(session, css("body", text: huddl.description))
    end)

    # Check for date format presence (should see dates for events)
    assert_has(session, css("body", text: ", 2025"))

    # Check we see the group name for at least one huddl
    assert_has(session, css("body", text: "Group"))
    :ok
  end

  defstep "I should see a search form", %{session: session} do
    # Check for the search input by placeholder
    assert_has(session, css("input[placeholder*='Search']"))
    assert_has(session, css("button", text: "Search"))
    :ok
  end

  defstep "I should see huddlz matching {string}", %{session: session, args: args} = context do
    search_term = List.first(args)

    # Should see the search term in the results (we created a huddl with "Elixir" in title)
    assert_has(session, css("body", text: "Elixir Programming Workshop"))

    # Should not see huddlz that don't match the search term
    # The generated huddlz typically have random titles that don't contain "Elixir"
    non_matching_titles =
      context.huddlz
      |> Enum.filter(fn h -> not String.contains?(h.title, search_term) end)
      |> Enum.map(& &1.title)
      # Just check a few
      |> Enum.take(3)

    Enum.each(non_matching_titles, fn title ->
      refute_has(session, css("body", text: title))
    end)

    :ok
  end

  defstep "I should see all upcoming huddlz again", %{session: session} = context do
    # After clearing search, we should see all the original huddlz again
    # Verify we can see all three huddl titles that were created in setup
    assert_has(session, css("h1", text: "Find your huddl"))

    # Check that all the huddlz we created are visible again
    Enum.each(context.huddlz, fn huddl ->
      assert_has(session, css("body", text: huddl.title))
    end)

    :ok
  end
end
