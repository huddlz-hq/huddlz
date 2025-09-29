defmodule HuddlzWeb.HuddlLivePermissionsTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  require Ash.Query

  describe "Huddl RSVP and permissions" do
    setup do
      owner = generate(user())
      member = generate(user())
      regular = generate(user())

      group =
        generate(
          group(
            is_public: true,
            owner_id: owner.id,
            name: "RSVP Group",
            actor: owner
          )
        )

      generate(
        group_member(
          group_id: group.id,
          user_id: member.id,
          role: :member,
          actor: owner
        )
      )

      # Create a virtual huddl with explicit future dates
      huddl =
        generate(
          huddl(
            title: "Virtual Huddl",
            description: "A virtual event",
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/virtual",
            group_id: group.id,
            creator_id: owner.id,
            is_private: false,
            date: Date.add(Date.utc_today(), 7),
            start_time: ~T[14:00:00],
            duration_minutes: 120,
            actor: owner
          )
        )

      %{
        owner: owner,
        member: member,
        regular: regular,
        group: group,
        huddl: huddl
      }
    end

    test "verified member can see huddl details", %{
      conn: conn,
      member: member,
      group: group,
      huddl: huddl
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> assert_has("h1", text: "Virtual Huddl")
      |> assert_has("span", text: "Virtual link available after RSVP")
    end

    test "user can see public huddl in public group", %{
      conn: conn,
      regular: user,
      group: group,
      huddl: huddl
    } do
      conn
      |> login(user)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> assert_has("h1", text: "Virtual Huddl")

      # Just verify they can access the page - the RSVP functionality
      # is tested in the unit tests
    end

    test "anonymous user can see public huddl but cannot RSVP", %{
      conn: conn,
      group: group,
      huddl: huddl
    } do
      conn
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> assert_has("h1", text: "Virtual Huddl")
      |> assert_has("span", text: "Sign in and RSVP to get virtual link")
      |> refute_has("button", text: "RSVP to this huddl")
    end
  end
end
