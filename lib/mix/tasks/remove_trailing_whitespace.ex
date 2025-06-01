defmodule Mix.Tasks.RemoveTrailingWhitespace do
  use Mix.Task

  @shortdoc "Remove trailing whitespace from all project files"

  @moduledoc """
  Removes trailing whitespace from all Elixir, HEEx, and Markdown files.

  ## Usage

      mix remove_trailing_whitespace

  This task will:
  - Find all .ex, .exs, .heex, and .md files
  - Skip deps/, _build/, and cover/ directories
  - Remove trailing whitespace from each file
  - Report how many files were cleaned
  """

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Removing trailing whitespace from project files...")

    extensions = ~w(.ex .exs .heex .md)
    excluded_dirs = ~w(deps _build cover)

    files =
      Path.wildcard("**/*")
      |> Enum.filter(fn path ->
        File.regular?(path) && Path.extname(path) in extensions
      end)
      |> Enum.reject(fn path ->
        Enum.any?(excluded_dirs, &String.starts_with?(path, &1 <> "/"))
      end)

    cleaned_count =
      files
      |> Enum.reduce(0, fn file, count ->
        original_content = File.read!(file)
        cleaned_content = String.replace(original_content, ~r/[ \t]+$/m, "")

        if original_content != cleaned_content do
          File.write!(file, cleaned_content)
          Mix.shell().info("  Cleaned: #{file}")
          count + 1
        else
          count
        end
      end)

    Mix.shell().info("\n✅ Cleaned #{cleaned_count} files")
    Mix.shell().info("   Total files checked: #{length(files)}")
  end
end
