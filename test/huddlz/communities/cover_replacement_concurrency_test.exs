defmodule Huddlz.Communities.CoverReplacementConcurrencyTest do
  use ExUnit.Case, async: false

  import Huddlz.Generator
  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupImage, GroupMember}
  alias Huddlz.Repo

  test "competing replacements leave one cover, and retrying the superseded save cannot restore it" do
    Sandbox.unboxed_run(Repo, fn ->
      owner = generate(user())
      group = generate(group(owner_id: owner.id, actor: owner))
      images = for _ <- 1..2, do: pending_image(group, owner)
      ids = Enum.map(images, & &1.id)

      on_exit(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          Repo.query!("DELETE FROM oban_jobs WHERE args->'primary_key'->>'id' = ANY($1)", [ids])

          Repo.query!("DELETE FROM group_images WHERE id = ANY($1::uuid[])", [
            Enum.map(ids, &Ecto.UUID.dump!/1)
          ])

          Repo.query!("DELETE FROM groups WHERE id = $1", [Ecto.UUID.dump!(group.id)])

          for version <- [Group.Version, GroupImage.Version, GroupMember.Version] do
            Repo.delete_all(from v in version, where: v.actor_id == ^owner.id)
          end

          Repo.query!("DELETE FROM users WHERE id = $1", [Ecto.UUID.dump!(owner.id)])
        end)
      end)

      test_pid = self()

      saves =
        Enum.map(images, fn image ->
          Task.async(fn ->
            Sandbox.unboxed_run(Repo, fn ->
              send(test_pid, {:ready, self()})

              receive do
                :save -> save(group, image, owner)
              after
                5_000 -> flunk("Concurrent save did not start")
              end
            end)
          end)
        end)

      for task <- saves do
        pid = task.pid
        assert_receive {:ready, ^pid}, 5_000
      end

      Enum.each(saves, &send(&1.pid, :save))
      assert Enum.all?(Task.await_many(saves, 10_000), &match?({:ok, _}, &1))
      assert [current] = Communities.list_group_images!(group.id, actor: owner)
      assert current.id in ids

      superseded = Enum.find(images, &(&1.id != current.id))
      assert {:error, _} = save(group, superseded, owner)
      assert {:ok, _} = save(group, current, owner)
      assert [%{id: id}] = Communities.list_group_images!(group.id, actor: owner)
      assert id == current.id
    end)
  end

  defp pending_image(group, actor) do
    path = Ash.UUID.generate()

    Communities.create_pending_group_image!(
      %{
        filename: "cover.jpg",
        content_type: "image/jpeg",
        size_bytes: 1000,
        storage_path: path,
        thumbnail_path: path <> "_thumb",
        group_id: group.id
      },
      actor: actor
    )
  end

  defp save(group, image, actor) do
    Ash.update(group, %{},
      action: :update_details,
      actor: actor,
      private_arguments: %{pending_image_id: image.id}
    )
  end
end
