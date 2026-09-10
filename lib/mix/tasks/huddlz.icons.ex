defmodule Mix.Tasks.Huddlz.Icons do
  @shortdoc "Writes the favicon set from the brand mark"

  @moduledoc """
  Writes the favicon set into `priv/static` from `HuddlzWeb.OgImage.mark_svg/1`,
  so the tab icon is drawn from the same mark as everything else:

    * `favicon.svg` — what modern browsers use
    * `favicon.ico` — 16, 32 and 48 px for the rest
    * `icon-192.png`, `icon-512.png` — Android and manifests
    * `apple-touch-icon.png` — 180 px for iOS home screens

  Run it again whenever the mark changes and commit the files.
  """
  use Mix.Task

  alias HuddlzWeb.OgImage

  @static "priv/static"
  @ico_sizes [16, 32, 48]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    write("favicon.svg", OgImage.mark_svg(512))
    write("favicon.ico", ico(@ico_sizes))
    write("icon-192.png", png(192))
    write("icon-512.png", png(512))
    write("apple-touch-icon.png", png(180))
  end

  defp png(size) do
    {:ok, binary} = OgImage.mark_png(size)
    binary
  end

  # An ICO is a small directory in front of the images; PNG entries are
  # fine for every browser still asking for .ico.
  defp ico(sizes) do
    pngs = Enum.map(sizes, &png/1)
    header_size = 6 + 16 * length(sizes)

    {entries, _offset} =
      sizes
      |> Enum.zip(pngs)
      |> Enum.map_reduce(header_size, fn {size, png}, offset ->
        entry =
          <<ico_dim(size), ico_dim(size), 0, 0, 1::16-little, 32::16-little,
            byte_size(png)::32-little, offset::32-little>>

        {entry, offset + byte_size(png)}
      end)

    IO.iodata_to_binary([<<0::16-little, 1::16-little, length(sizes)::16-little>>, entries, pngs])
  end

  defp ico_dim(256), do: 0
  defp ico_dim(size), do: size

  defp write(name, binary) do
    path = Path.join(@static, name)
    File.write!(path, binary)
    Mix.shell().info("wrote #{path} (#{byte_size(binary)} bytes)")
  end
end
