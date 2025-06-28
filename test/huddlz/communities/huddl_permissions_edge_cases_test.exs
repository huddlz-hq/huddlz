defmodule Huddlz.Communities.HuddlPermissionsEdgeCasesTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Huddl

  require Ash.Query

  setup do
    owner = generate(user())
    organizer = generate(user())
    member = generate(user())
    regular = generate(user())
    outsider = generate(user())

    # Groups are automatically created with owner membership
    public_group =
      generate(group(name: "Public Group", is_public: true, owner_id: owner.id, actor: owner))

    private_group =
      generate(group(name: "Private Group", is_public: false, owner_id: owner.id, actor: owner))

    # Add additional members to public group
    generate(
      group_member(
        group_id: public_group.id,
        user_id: organizer.id,
        role: :organizer,
        actor: owner
      )
    )

    generate(
      group_member(group_id: public_group.id, user_id: member.id, role: :member, actor: owner)
    )

    %{
      owner: owner,
      organizer: organizer,
      member: member,
      regular: regular,
      outsider: outsider,
      public_group: public_group,
      private_group: private_group
    }
  end

  describe "create huddl action" do
    test "regular member cannot create huddl", %{member: user, public_group: group} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Member Huddl",
                   description: "Should fail",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   group_id: group.id,
                   creator_id: user.id
                 },
                 actor: user
               )
               |> Ash.create()
    end

    test "organizer can create huddl", %{organizer: user, public_group: group} do
      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Organizer Huddl",
                   description: "Should succeed",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :virtual,
                   virtual_link: "https://zoom.us/j/organizer",
                   group_id: group.id,
                   creator_id: user.id
                 },
                 actor: user
               )
               |> Ash.create()

      assert huddl.title == "Organizer Huddl"
    end

    test "outsider cannot create huddl", %{outsider: user, public_group: group} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Outsider Huddl",
                   description: "Should fail",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :in_person,
                   physical_location: "123 Main St",
                   group_id: group.id,
                   creator_id: user.id
                 },
                 actor: user
               )
               |> Ash.create()
    end

    test "private group only allows owner or organizer to create huddl", %{
      private_group: group,
      owner: owner,
      organizer: organizer,
      member: member,
      outsider: outsider
    } do
      # Owner can create
      assert {:ok, _huddl} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Owner Private Huddl",
                   description: "Owner can create",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :in_person,
                   physical_location: "Secret Place",
                   group_id: group.id,
                   creator_id: owner.id
                 },
                 actor: owner
               )
               |> Ash.create()

      # Organizer cannot create unless added as organizer in private group
      assert {:error, %Ash.Error.Forbidden{}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Organizer Private Huddl",
                   description: "Should fail",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :in_person,
                   physical_location: "Secret Place",
                   group_id: group.id,
                   creator_id: organizer.id
                 },
                 actor: organizer
               )
               |> Ash.create()

      # Member cannot create
      assert {:error, %Ash.Error.Forbidden{}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Member Private Huddl",
                   description: "Should fail",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :in_person,
                   physical_location: "Secret Place",
                   group_id: group.id,
                   creator_id: member.id
                 },
                 actor: member
               )
               |> Ash.create()

      # Outsider cannot create
      assert {:error, %Ash.Error.Forbidden{}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Outsider Private Huddl",
                   description: "Should fail",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :in_person,
                   physical_location: "Secret Place",
                   group_id: group.id,
                   creator_id: outsider.id
                 },
                 actor: outsider
               )
               |> Ash.create()
    end
  end

  describe "update huddl action" do
    test "organizer can update huddl", %{organizer: user, public_group: group, owner: owner} do
      {:ok, huddl} =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Original Title",
            description: "To be updated",
            starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
            ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
            event_type: :in_person,
            physical_location: "123 Main St",
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create()

      assert {:ok, updated} =
               huddl
               |> Ash.Changeset.for_update(:update, %{title: "Updated by Organizer"}, actor: user)
               |> Ash.update()

      assert updated.title == "Updated by Organizer"
    end

    test "member cannot update huddl", %{member: user, public_group: group, owner: owner} do
      {:ok, huddl} =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Original Title",
            description: "To be updated",
            starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
            ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
            event_type: :in_person,
            physical_location: "123 Main St",
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create()

      assert {:error, %Ash.Error.Forbidden{}} =
               huddl
               |> Ash.Changeset.for_update(:update, %{title: "Updated by Member"}, actor: user)
               |> Ash.update()
    end
  end

  describe "huddl validation edge cases" do
    test "hybrid event requires both physical location and virtual link", %{
      owner: user,
      public_group: group
    } do
      # Missing virtual_link
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Huddl
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "Hybrid Event",
                   description: "Missing virtual link",
                   starts_at: DateTime.utc_now() |> DateTime.add(1, :day),
                   ends_at: DateTime.utc_now() |> DateTime.add(2, :day),
                   event_type: :hybrid,
                   physical_location: "123 Main St",
                   group_id: group.id,
                   creator_id: user.id
                 },
                 actor: user
               )
               |> Ash.create()

      # Check that there's an error related to virtual_link
      error_messages = Enum.map_join(errors, " ", & &1.message)

      assert String.contains?(error_messages, "virtual_link") or
               String.contains?(error_messages, "virtual link")
    end
  end
end
