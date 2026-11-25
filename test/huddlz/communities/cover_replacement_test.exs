defmodule Huddlz.Communities.CoverReplacementTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Communities

  setup do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, actor: owner))
    %{owner: owner, group: group}
  end

  test "retrying a group replacement retires all prior covers only once", %{
    owner: owner,
    group: group
  } do
    old = Communities.create_group_image!(Map.put(attrs(), :group_id, group.id), actor: owner)
    other = Communities.create_group_image!(Map.put(attrs(), :group_id, group.id), actor: owner)

    image =
      Communities.create_pending_group_image!(Map.put(attrs(), :group_id, group.id), actor: owner)

    for _ <- 1..2 do
      assert {:ok, _} = replace(group, :update_details, image, owner)
      assert [%{id: id}] = Communities.list_group_images!(group.id, actor: owner)
      assert id == image.id
    end

    assert {:error, _} = Communities.soft_delete_group_image(image, actor: owner)
    assert is_nil(Ash.reload!(image, actor: owner).deleted_at)
    assert length(all_enqueued(worker: Huddlz.Workers.GroupImageCleanup)) == 2
    assert Ash.reload!(old, actor: owner).deleted_at
    assert Ash.reload!(other, actor: owner).deleted_at
  end

  test "a pending group image can only be assigned by its uploader and to its intended group",
       %{owner: owner, group: group} do
    other_group = generate(group(owner_id: owner.id, actor: owner))
    other_user = generate(user())

    wrong_group =
      Communities.create_pending_group_image!(Map.put(attrs(), :group_id, other_group.id),
        actor: owner
      )

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.create_pending_group_image(Map.put(attrs(), :group_id, group.id),
               actor: other_user
             )

    wrong_actor = Communities.create_pending_group_image!(attrs(), actor: other_user)

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.soft_delete_group_image(wrong_actor, actor: owner)

    for image <- [wrong_group, wrong_actor] do
      assert {:error, _} = replace(group, :update_details, image, owner)
      assert {:error, _} = Communities.assign_group_image_to_group(image, group.id, actor: owner)
      assert is_nil(Ash.reload!(image, actor: owner).group_id)
    end

    assert {:ok, _} = Communities.soft_delete_group_image(wrong_actor, actor: other_user)
    assert {:error, _} = Communities.soft_delete_group_image(wrong_actor, actor: other_user)
    assert length(all_enqueued(worker: Huddlz.Workers.GroupImageCleanup)) == 1
  end

  test "huddl assignment checks the original group and uploader",
       %{owner: owner, group: group} do
    other_group = generate(group(owner_id: owner.id, actor: owner))
    member = generate(user())
    generate(group_member(group_id: group.id, user_id: member.id, actor: owner))
    huddl = generate(huddl(group_id: group.id, creator_id: owner.id))

    wrong_group =
      Communities.create_pending_huddl_cover_image!(other_group.id, attrs(), actor: owner)

    wrong_actor = Communities.create_pending_huddl_cover_image!(group.id, attrs(), actor: member)

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.soft_delete_huddl_cover_image(wrong_actor, actor: owner)

    for image <- [wrong_group, wrong_actor] do
      assert {:error, _} = replace(huddl, :update, image, owner)

      assert {:error, _} =
               Communities.assign_huddl_cover_image_to_huddl(image, huddl.id, actor: owner)

      assert is_nil(Ash.reload!(image, actor: owner).huddl_id)
    end

    assert {:ok, _} = Communities.soft_delete_huddl_cover_image(wrong_actor, actor: member)
    assert {:error, _} = Communities.soft_delete_huddl_cover_image(wrong_actor, actor: member)
    assert length(all_enqueued(worker: Huddlz.Workers.HuddlImageCleanup)) == 1
  end

  test "a failed huddl save rolls back assignment, retirement and queued cleanup",
       %{owner: owner, group: group} do
    huddl = generate(huddl(group_id: group.id, creator_id: owner.id))

    old =
      Communities.create_huddl_cover_image!(Map.put(attrs(), :huddl_id, huddl.id), actor: owner)

    image = Communities.create_pending_huddl_cover_image!(group.id, attrs(), actor: owner)

    result =
      huddl
      |> Ash.Changeset.for_update(:update, %{description: "Changed with the cover"},
        actor: owner,
        private_arguments: %{pending_image_id: image.id}
      )
      |> Ash.Changeset.after_action(fn _changeset, _huddl -> {:error, "later change failed"} end)
      |> Ash.update()

    assert {:error, error} = result
    assert Exception.message(error) =~ "later change failed"
    assert Ash.reload!(huddl, actor: owner).description == huddl.description
    assert is_nil(Ash.reload!(image, actor: owner).huddl_id)
    assert is_nil(Ash.reload!(old, actor: owner).deleted_at)
    refute_enqueued(worker: Huddlz.Workers.HuddlImageCleanup)
  end

  defp replace(parent, action, image, actor) do
    Ash.update(parent, %{},
      action: action,
      actor: actor,
      private_arguments: %{pending_image_id: image.id}
    )
  end

  defp attrs do
    path = Ash.UUID.generate()

    %{
      filename: "cover.jpg",
      content_type: "image/jpeg",
      size_bytes: 1000,
      storage_path: path <> ".jpg",
      thumbnail_path: path <> "_thumb.jpg"
    }
  end
end
