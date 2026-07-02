defmodule Huddlz.Communities.Huddl.Changes.ClearUnusedLocationFieldsTest do
  use Huddlz.DataCase, async: true

  import Ecto.Query

  alias Huddlz.Communities.Huddl

  setup do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    {:ok, %{owner: owner, group: group}}
  end

  describe "on create" do
    test "clears physical_location on virtual huddlz", %{owner: owner, group: group} do
      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            event_type: :virtual,
            virtual_link: "https://example.com/meet",
            physical_location: "123 Main St"
          )
        )

      assert is_nil(huddl.physical_location)
    end

    test "clears virtual_link on in-person huddlz", %{owner: owner, group: group} do
      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            event_type: :in_person,
            physical_location: "123 Main St",
            virtual_link: "https://example.com/meet"
          )
        )

      assert is_nil(huddl.virtual_link)
    end
  end

  describe "on update" do
    test "a title-only edit preserves a stored physical_location on a virtual huddl",
         %{owner: owner, group: group} do
      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            event_type: :virtual,
            virtual_link: "https://example.com/meet"
          )
        )

      # Legacy row from before creates cleared unused location fields.
      Repo.update_all(
        from(h in Huddl, where: h.id == ^huddl.id),
        set: [physical_location: "Legacy address"]
      )

      assert {:ok, updated} =
               Huddl
               |> Ash.get!(huddl.id, authorize?: false)
               |> Ash.Changeset.for_update(:update, %{title: "New title"}, actor: owner)
               |> Ash.update()

      assert updated.title == "New title"
      assert updated.physical_location == "Legacy address"
    end

    test "switching event_type to virtual clears physical_location",
         %{owner: owner, group: group} do
      huddl =
        generate(
          huddl(
            group_id: group.id,
            actor: owner,
            event_type: :in_person,
            physical_location: "123 Main St"
          )
        )

      assert {:ok, updated} =
               huddl
               |> Ash.Changeset.for_update(
                 :update,
                 %{event_type: :virtual, virtual_link: "https://example.com/meet"},
                 actor: owner
               )
               |> Ash.update()

      assert is_nil(updated.physical_location)
      assert updated.virtual_link == "https://example.com/meet"
    end
  end
end
