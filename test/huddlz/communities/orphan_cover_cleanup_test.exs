defmodule Huddlz.Communities.OrphanCoverCleanupTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Storage.Local

  for kind <- [:group, :huddl] do
    @kind kind
    test "queued #{kind} cleanup preserves a cover assigned after the worker first reads it" do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, actor: owner))
      {image, assign_cover} = pending_cover(@kind, group, owner)
      Ash.Seed.update!(image, %{inserted_at: DateTime.add(DateTime.utc_now(), -25, :hour)})

      for path <- [image.storage_path, image.thumbnail_path] do
        assert {:ok, ^path} = Local.put("test/fixtures/test_image.jpg", path, "image/jpeg")
        on_exit(fn -> Local.delete(path) end)
      end

      job = image |> AshOban.build_trigger(:cleanup_orphaned_images) |> Oban.insert!()

      worker_module =
        AshOban.Info.oban_trigger(image.__struct__, :cleanup_orphaned_images).worker_module_name

      worker =
        Task.async(fn ->
          receive do
            :perform -> Oban.Testing.perform_job(worker_module, job.args, repo: Repo)
          end
        end)

      # Stop after the initial eligibility read, before the worker opens the destroy transaction.
      handler = make_ref()
      event = [:ash, Ash.Domain.Info.short_name(Communities), :read, :stop]
      :ok = :telemetry.attach(handler, event, &__MODULE__.after_read/4, {worker.pid, self()})
      on_exit(fn -> :telemetry.detach(handler) end)
      send(worker.pid, :perform)
      assert_receive :orphan_read, 5_000
      :telemetry.detach(handler)
      assert {:ok, _} = assign_cover.()
      send(worker.pid, :resume)
      assert {:cancel, :trigger_no_longer_applies} = Task.await(worker)

      assert Ash.reload!(image, actor: owner).id == image.id
      assert Local.exists?(image.storage_path)
      assert Local.exists?(image.thumbnail_path)
    end
  end

  def after_read(_, _, %{action: :orphaned_pending}, {worker, test}) when worker == self() do
    send(test, :orphan_read)

    receive do
      :resume -> :ok
    after
      5_000 -> raise "Timed out waiting for cover assignment"
    end
  end

  def after_read(_, _, _, _), do: :ok

  defp pending_cover(:group, group, owner) do
    image =
      Communities.create_pending_group_image!(Map.put(attrs(), :group_id, group.id), actor: owner)

    {image, fn -> Communities.assign_group_image_to_group(image, group.id, actor: owner) end}
  end

  defp pending_cover(:huddl, group, owner) do
    huddl = generate(huddl(group_id: group.id, creator_id: owner.id))
    image = Communities.create_pending_huddl_cover_image!(group.id, attrs(), actor: owner)

    {image,
     fn -> Communities.assign_huddl_cover_image_to_huddl(image, huddl.id, actor: owner) end}
  end

  defp attrs do
    path = "/uploads/orphan-tests/#{Ash.UUID.generate()}"

    %{
      filename: "cover.jpg",
      content_type: "image/jpeg",
      size_bytes: 1000,
      storage_path: path <> ".jpg",
      thumbnail_path: path <> "_thumb.jpg"
    }
  end
end
