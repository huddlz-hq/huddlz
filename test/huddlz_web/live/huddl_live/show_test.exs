defmodule HuddlzWeb.HuddlLive.ShowTest do
  use HuddlzWeb.ConnCase

  import Huddlz.Test.Helpers.Authentication

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl

  describe "Show huddl details" do
    setup do
      owner = create_verified_user()
      member = create_verified_user()
      non_member = create_verified_user()

      # Create a public group
      group =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "Test Group",
            description: "A test group for huddl show",
            is_public: true,
            owner_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Add member to group
      GroupMember
      |> Ash.Changeset.for_create(
        :add_member,
        %{
          group_id: group.id,
          user_id: member.id,
          role: "member"
        },
        actor: owner
      )
      |> Ash.create!()

      # Create a virtual huddl
      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Virtual Meeting",
            description: "Join us for an online discussion",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/123456789",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      %{
        owner: owner,
        member: member,
        non_member: non_member,
        group: group,
        huddl: huddl
      }
    end

    test "displays huddl details", %{conn: conn, group: group, huddl: huddl} do
      conn
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      |> assert_has("h1", text: huddl.title)
      |> assert_has("p", text: huddl.description)
      |> assert_has("span", text: "Virtual")
      |> assert_has("p", text: "Be the first to RSVP!")
    end

    test "shows RSVP button for authenticated users", %{
      conn: conn,
      member: member,
      group: group,
      huddl: huddl
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      |> assert_has("button", text: "RSVP to this huddl")
      |> refute_has("div.text-success", text: "You're attending!")
      # Click RSVP button
      |> click_button("RSVP to this huddl")
      # Check UI updates after RSVP
      |> assert_has("div.text-success", text: "You're attending!")
      |> refute_has("button", text: "RSVP to this huddl")
      # Should show 1 person attending
      |> assert_has("p", text: "1 person attending")
    end

    test "shows virtual link after RSVP", %{
      conn: conn,
      member: member,
      group: group,
      huddl: huddl
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      # Before RSVP, virtual link is not visible
      |> assert_has("span", text: "Virtual link available after RSVP")
      |> refute_has("a", text: "Join virtually")
      # RSVP
      |> click_button("RSVP to this huddl")
      # After RSVP, virtual link is visible
      |> assert_has("a", text: "Join virtually")
    end

    test "prevents duplicate RSVPs", %{conn: conn, member: member, group: group, huddl: huddl} do
      # First RSVP
      updated_huddl =
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
        |> Ash.update!()

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{updated_huddl.id}")
      # Should already show as attending
      |> assert_has("div.text-success", text: "You're attending!")
      |> refute_has("button", text: "RSVP to this huddl")
      |> assert_has("p", text: "1 person attending")
    end

    test "shows correct attendee count with multiple RSVPs", %{
      conn: conn,
      member: member,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      # Owner RSVPs
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      |> assert_has("p", text: "1 person attending")
      # Member RSVPs
      |> click_button("RSVP to this huddl")
      |> assert_has("p", text: "2 people attending")
    end

    test "non-authenticated users see sign-in prompt for virtual link", %{
      conn: conn,
      group: group,
      huddl: huddl
    } do
      conn
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      |> assert_has("span", text: "Sign in and RSVP to get virtual link")
      |> refute_has("button", text: "RSVP to this huddl")
    end

    test "handles different event types correctly", %{conn: conn, owner: owner, group: group} do
      # Create in-person huddl
      in_person_huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "In-Person Meetup",
            description: "Meet us at the coffee shop",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :in_person,
            physical_location: "123 Main St, City",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.id}/huddlz/#{in_person_huddl.id}")
      |> assert_has("dd", text: "123 Main St, City")
      |> refute_has("dt", text: "Virtual Access")

      # Create hybrid huddl
      hybrid_huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Hybrid Event",
            description: "Join us in person or online",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :hybrid,
            physical_location: "Conference Room A",
            virtual_link: "https://meet.example.com/hybrid",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.id}/huddlz/#{hybrid_huddl.id}")
      |> assert_has("dd", text: "Conference Room A")
      |> assert_has("dt", text: "Virtual Access")
      |> assert_has("span", text: "Virtual link available after RSVP")
      # RSVP to see virtual link
      |> click_button("RSVP to this huddl")
      |> assert_has("a", text: "Join virtually")
    end

    test "cannot access private huddl without membership", %{
      conn: conn,
      non_member: non_member,
      owner: owner
    } do
      # Create private group
      private_group =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "Private Group",
            description: "Members only",
            is_public: false,
            owner_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Create private huddl
      private_huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Private Event",
            description: "Members only event",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :in_person,
            physical_location: "Secret Location",
            is_private: true,
            group_id: private_group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Non-member should be redirected
      session = 
        conn
        |> login(non_member)
        |> visit(~p"/groups/#{private_group.id}/huddlz/#{private_huddl.id}")

      # Should redirect to the groups list when huddl is not found (due to authorization)
      assert_path(session, ~p"/groups")
    end

    test "shows Cancel RSVP button when user has RSVPed", %{
      conn: conn,
      member: member,
      group: group,
      huddl: huddl
    } do
      # First RSVP to the huddl
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      # Should show Cancel RSVP button instead of RSVP button
      |> assert_has("button", text: "Cancel RSVP")
      |> refute_has("button", text: "RSVP to this huddl")
      # Should still show attending status
      |> assert_has("div.text-success", text: "You're attending!")
    end

    test "Cancel RSVP button only shows for upcoming huddls", %{
      conn: conn,
      member: member,
      owner: owner,
      group: group
    } do
      # Create a past huddl
      past_huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Past Event",
            description: "This already happened",
            starts_at: DateTime.add(DateTime.utc_now(), -2, :day),
            ends_at: DateTime.add(DateTime.utc_now(), -1, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/past",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # RSVP to the past huddl (directly in database since it's past)
      past_huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{past_huddl.id}")
      # Should not show Cancel RSVP button for past events
      |> refute_has("button", text: "Cancel RSVP")
      |> refute_has("button", text: "RSVP to this huddl")
      # But should still show attending status
      |> assert_has("p", text: "1 person attending")
    end

    test "handles cancel_rsvp event successfully", %{
      conn: conn,
      member: member,
      group: group,
      huddl: huddl
    } do
      # First RSVP to the huddl
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      # Click Cancel RSVP button
      |> click_button("Cancel RSVP")
      # Check UI updates after cancel
      |> assert_has("button", text: "RSVP to this huddl")
      |> refute_has("div.text-success", text: "You're attending!")
      |> refute_has("button", text: "Cancel RSVP")
      # Should show 0 people attending
      |> assert_has("p", text: "Be the first to RSVP!")
    end

    test "cancel_rsvp updates attendee count correctly", %{
      conn: conn,
      member: member,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      # Both users RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      |> assert_has("p", text: "2 people attending")
      # Member cancels their RSVP
      |> click_button("Cancel RSVP")
      # Should show 1 person attending (owner still RSVPed)
      |> assert_has("p", text: "1 person attending")
    end

    test "can RSVP again after cancelling", %{
      conn: conn,
      member: member,
      group: group,
      huddl: huddl
    } do
      # RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.id}/huddlz/#{huddl.id}")
      # Cancel RSVP
      |> click_button("Cancel RSVP")
      # RSVP again
      |> click_button("RSVP to this huddl")
      # Check UI updates after second RSVP
      |> assert_has("div.text-success", text: "You're attending!")
      |> assert_has("p", text: "1 person attending")
    end
  end

  defp create_verified_user do
    User
    |> Ash.Changeset.for_create(:create, %{
      email: "user#{System.unique_integer()}@example.com",
      display_name: "Test User",
      role: :verified
    })
    |> Ash.create!(authorize?: false)
  end

end
