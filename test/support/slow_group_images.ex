defmodule Huddlz.Test.SlowGroupImages do
  @moduledoc """
  `Huddlz.Storage.GroupImages` with a pause before preparing a pending
  cover, so a browser scenario can observe the in-progress state of the
  cover slot. Selected through `:image_storage_overrides`; see
  `HuddlzWeb.Live.Helpers.ImageUploadPipeline`.
  """

  alias Huddlz.Storage.GroupImages

  @pause_ms 1_500

  def store_pending(source_path, original_filename, content_type) do
    Process.sleep(@pause_ms)
    GroupImages.store_pending(source_path, original_filename, content_type)
  end

  defdelegate url(path), to: GroupImages
end
