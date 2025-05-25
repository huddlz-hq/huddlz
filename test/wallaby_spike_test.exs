defmodule WallabySpikeTest do
  use ExUnit.Case
  use Wallaby.Feature

  import Wallaby.Query
  import Huddlz.Generator

  # Configure for Wallaby
  @endpoint HuddlzWeb.Endpoint

  setup tags do
    # Set up database
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Huddlz.Repo)

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Huddlz.Repo, self())
    Wallaby.Feature.set_cookie(tags.session, metadata)

    :ok
  end

  feature "user sees flash message after permission denied", %{session: session} do
    # Create test data
    regular_user = generate(user(role: :regular))

    # Visit sign-in page
    session
    |> visit("/sign-in")
    |> fill_in(text_field("Email"), with: regular_user.email)
    |> click(button("Request magic link"))

    # For this spike, we'll use the token directly instead of clicking email
    # In real tests, we could navigate to the dev mailbox or extract the token
    token = get_latest_magic_link_token(regular_user.email)

    session
    |> visit("/auth/user/magic_link?token=#{token}")

    # Now try to create a group (should be denied)
    session
    |> visit("/groups/new")
    |> assert_has(css(".alert", text: "You need to be a verified user to create groups"))

    # The key test - can we see the flash message!
    IO.puts("\n✅ Wallaby successfully found the flash message!")
  end

  feature "RSVP flow with flash messages", %{session: session} do
    # Create a future huddl
    host = generate(user(role: :verified))
    group = generate(group(owner_id: host.id, actor: host))

    future_time = DateTime.utc_now() |> DateTime.add(7, :day)

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: host.id,
          starts_at: future_time,
          is_private: false,
          actor: host
        )
      )

    # Create a different user to RSVP
    attendee = generate(user(role: :verified))

    # Login as attendee
    session
    |> visit("/sign-in")
    |> fill_in(text_field("Email"), with: attendee.email)
    |> click(button("Request magic link"))

    token = get_latest_magic_link_token(attendee.email)

    session
    |> visit("/auth/user/magic_link?token=#{token}")
    |> visit("/groups/#{group.id}/huddlz/#{huddl.id}")

    # Click RSVP button
    session
    |> click(button("RSVP to this huddl"))
    |> assert_has(css(".alert", text: "Successfully RSVPed to this huddl!"))
    |> assert_has(css("body", text: "You're attending!"))
    |> assert_has(button("Cancel RSVP"))

    # Now cancel
    session
    |> click(button("Cancel RSVP"))
    |> assert_has(css(".alert", text: "RSVP cancelled successfully"))
    |> assert_has(button("RSVP to this huddl"))

    IO.puts("\n✅ Wallaby successfully handled the entire RSVP flow with flash messages!")
  end

  # Helper to get magic link token
  defp get_latest_magic_link_token(email) do
    import Swoosh.TestAssertions

    receive do
      {:email, %{to: [{_, ^email}], assigns: %{url: url}}} ->
        # Extract token from URL
        ~r/token=([^&]+)/ |> Regex.run(url) |> List.last()
    after
      1000 -> nil
    end
  end
end
