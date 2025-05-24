defmodule Huddlz.Communities.HuddlAccessControlTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Huddlz.Communities.Huddl
  require Ash.Query

  describe "create authorization" do
    setup do
      owner = generate(user(role: :verified))
      organizer = generate(user(role: :verified))
      member = generate(user(role: :verified))
      non_member = generate(user(role: :verified))
      admin = generate(user(role: :admin))

      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      # Add organizer and member to group
      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

      %{
        owner: owner,
        organizer: organizer,
        member: member,
        non_member: non_member,
        admin: admin,
        group: group
      }
    end

    test "owner can create huddl", %{owner: owner, group: group} do
      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Owner's Huddl",
                   description: "Test huddl by owner",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(2, :hour),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   group_id: group.id,
                   creator_id: owner.id
                 },
                 actor: owner
               )
               |> Ash.create()

      assert huddl.title == "Owner's Huddl"
      assert huddl.group_id == group.id
      assert huddl.creator_id == owner.id
    end

    test "organizer can create huddl", %{organizer: organizer, group: group} do
      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Organizer's Huddl",
                   description: "Test huddl by organizer",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(2, :hour),
                   event_type: :virtual,
                   virtual_link: "https://zoom.us/j/123456",
                   group_id: group.id,
                   creator_id: organizer.id
                 },
                 actor: organizer
               )
               |> Ash.create()

      assert huddl.title == "Organizer's Huddl"
    end

    test "regular member cannot create huddl", %{member: member, group: group} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Member's Huddl",
                   description: "Test huddl by member",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(2, :hour),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   group_id: group.id,
                   creator_id: member.id
                 },
                 actor: member
               )
               |> Ash.create()
    end

    test "non-member cannot create huddl", %{non_member: non_member, group: group} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Non-member's Huddl",
                   description: "Test huddl by non-member",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(2, :hour),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   group_id: group.id,
                   creator_id: non_member.id
                 },
                 actor: non_member
               )
               |> Ash.create()
    end

    test "admin can create huddl", %{admin: admin, group: group} do
      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Admin's Huddl",
                   description: "Test huddl by admin",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(2, :hour),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   group_id: group.id,
                   creator_id: admin.id
                 },
                 actor: admin
               )
               |> Ash.create()

      assert huddl.title == "Admin's Huddl"
    end
  end

  describe "force private for private groups" do
    test "private groups create private huddls even if is_private is false" do
      owner = generate(user(role: :verified))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Should be private",
                   description: "Test huddl",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(2, :hour),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   # Explicitly set to false
                   is_private: false,
                   group_id: private_group.id,
                   creator_id: owner.id
                 },
                 actor: owner
               )
               |> Ash.create()

      # Should be forced to true
      assert huddl.is_private == true
    end

    test "public groups respect is_private setting" do
      owner = generate(user(role: :verified))
      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      # Test with is_private = false
      assert {:ok, public_huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Public Huddl",
                   description: "Test huddl",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(2, :hour),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   is_private: false,
                   group_id: public_group.id,
                   creator_id: owner.id
                 },
                 actor: owner
               )
               |> Ash.create()

      assert public_huddl.is_private == false

      # Test with is_private = true
      assert {:ok, private_huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Private Huddl in Public Group",
                   description: "Test huddl",
                   starts_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.add(2, :hour),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   is_private: true,
                   group_id: public_group.id,
                   creator_id: owner.id
                 },
                 actor: owner
               )
               |> Ash.create()

      assert private_huddl.is_private == true
    end
  end

  describe "read authorization and visibility" do
    setup do
      owner = generate(user(role: :verified))
      member = generate(user(role: :verified))
      non_member = generate(user(role: :verified))

      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      # Add member to both groups
      generate(
        group_member(group_id: public_group.id, user_id: member.id, role: :member, actor: owner)
      )

      generate(
        group_member(group_id: private_group.id, user_id: member.id, role: :member, actor: owner)
      )

      # Create huddls
      public_huddl_in_public_group =
        generate(
          huddl(
            is_private: false,
            group_id: public_group.id,
            creator_id: owner.id,
            title: "Public Huddl in Public Group",
            actor: owner
          )
        )

      private_huddl_in_public_group =
        generate(
          huddl(
            is_private: true,
            group_id: public_group.id,
            creator_id: owner.id,
            title: "Private Huddl in Public Group",
            actor: owner
          )
        )

      huddl_in_private_group =
        generate(
          huddl(
            # Will be forced to true
            is_private: true,
            group_id: private_group.id,
            creator_id: owner.id,
            title: "Huddl in Private Group",
            actor: owner
          )
        )

      %{
        owner: owner,
        member: member,
        non_member: non_member,
        public_group: public_group,
        private_group: private_group,
        public_huddl_in_public_group: public_huddl_in_public_group,
        private_huddl_in_public_group: private_huddl_in_public_group,
        huddl_in_private_group: huddl_in_private_group
      }
    end

    test "members can see all huddls in their groups", %{member: member} do
      huddls = Huddl |> Ash.read!(actor: member)
      titles = Enum.map(huddls, & &1.title) |> Enum.sort()

      assert "Huddl in Private Group" in titles
      assert "Private Huddl in Public Group" in titles
      assert "Public Huddl in Public Group" in titles
    end

    test "non-members can only see public huddls in public groups", %{non_member: non_member} do
      huddls = Huddl |> Ash.read!(actor: non_member)
      titles = Enum.map(huddls, & &1.title)

      assert titles == ["Public Huddl in Public Group"]
    end

    test "unauthenticated users can only see public huddls in public groups" do
      huddls = Huddl |> Ash.read!()
      titles = Enum.map(huddls, & &1.title)

      assert titles == ["Public Huddl in Public Group"]
    end
  end

  describe "virtual link visibility" do
    setup do
      owner = generate(user(role: :verified))
      member = generate(user(role: :verified))
      non_member = generate(user(role: :verified))

      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

      virtual_huddl =
        generate(
          huddl(
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/secret123",
            group_id: group.id,
            creator_id: owner.id,
            is_private: false,
            actor: owner
          )
        )

      %{
        owner: owner,
        member: member,
        non_member: non_member,
        group: group,
        virtual_huddl: virtual_huddl
      }
    end

    test "members can see virtual links", %{member: member, virtual_huddl: virtual_huddl} do
      result =
        Huddl
        |> Ash.Query.filter(id == ^virtual_huddl.id)
        |> Ash.Query.load(:visible_virtual_link)
        |> Ash.read_one!(actor: member)

      assert result.visible_virtual_link == "https://zoom.us/j/secret123"
      assert result.virtual_link == "https://zoom.us/j/secret123"
    end

    test "non-members cannot see virtual links", %{
      non_member: non_member,
      virtual_huddl: virtual_huddl
    } do
      result =
        Huddl
        |> Ash.Query.filter(id == ^virtual_huddl.id)
        |> Ash.Query.load(:visible_virtual_link)
        |> Ash.read_one!(actor: non_member)

      assert result.visible_virtual_link == nil
      # The actual virtual_link field is marked sensitive, so it shouldn't be exposed
    end

    test "unauthenticated users cannot see virtual links", %{virtual_huddl: virtual_huddl} do
      result =
        Huddl
        |> Ash.Query.filter(id == ^virtual_huddl.id)
        |> Ash.Query.load(:visible_virtual_link)
        |> Ash.read_one!()

      assert result.visible_virtual_link == nil
    end
  end

  describe "update and destroy authorization" do
    setup do
      owner = generate(user(role: :verified))
      organizer = generate(user(role: :verified))
      member = generate(user(role: :verified))
      admin = generate(user(role: :admin))

      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

      huddl =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            title: "Original Title",
            actor: owner
          )
        )

      %{
        owner: owner,
        organizer: organizer,
        member: member,
        admin: admin,
        group: group,
        huddl: huddl
      }
    end

    test "owner can update huddl", %{owner: owner, huddl: huddl} do
      assert {:ok, updated} =
               huddl
               |> Ash.Changeset.for_update(:update, %{title: "Updated by Owner"}, actor: owner)
               |> Ash.update()

      assert updated.title == "Updated by Owner"
    end

    test "organizer can update huddl", %{organizer: organizer, huddl: huddl} do
      assert {:ok, updated} =
               huddl
               |> Ash.Changeset.for_update(:update, %{title: "Updated by Organizer"},
                 actor: organizer
               )
               |> Ash.update()

      assert updated.title == "Updated by Organizer"
    end

    test "member cannot update huddl", %{member: member, huddl: huddl} do
      assert {:error, %Ash.Error.Forbidden{}} =
               huddl
               |> Ash.Changeset.for_update(:update, %{title: "Updated by Member"}, actor: member)
               |> Ash.update()
    end

    test "owner can destroy huddl", %{owner: owner, huddl: huddl} do
      assert :ok = Ash.destroy(huddl, actor: owner)
    end

    test "organizer can destroy huddl", %{organizer: organizer, huddl: huddl} do
      assert :ok = Ash.destroy(huddl, actor: organizer)
    end

    test "member cannot destroy huddl", %{member: member, huddl: huddl} do
      assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(huddl, actor: member)
    end

    test "admin can update and destroy huddl", %{admin: admin, huddl: huddl} do
      assert {:ok, updated} =
               huddl
               |> Ash.Changeset.for_update(:update, %{title: "Updated by Admin"}, actor: admin)
               |> Ash.update()

      assert updated.title == "Updated by Admin"

      assert :ok = Ash.destroy(updated, actor: admin)
    end
  end
end
