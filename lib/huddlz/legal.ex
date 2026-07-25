defmodule Huddlz.Legal.Markdown do
  @moduledoc false

  @type block ::
          {:heading, pos_integer(), String.t()}
          | {:paragraph, String.t()}
          | {:unordered_list, [String.t()]}
          | {:ordered_list, [String.t()]}

  @spec parse(String.t()) :: %{title: String.t(), version: String.t(), blocks: [block()]}
  def parse(markdown) do
    {title, version, blocks, pending} =
      markdown
      |> String.split("\n")
      |> Enum.reduce({nil, nil, [], nil}, &parse_line/2)

    blocks = flush_pending(blocks, pending)

    %{
      title: title || "Legal document",
      version: version || raise("Legal document is missing a version"),
      blocks: blocks
    }
  end

  defp parse_line("# " <> title, {_title, version, blocks, pending}),
    do: {String.trim(title), version, flush_pending(blocks, pending), nil}

  defp parse_line("## " <> heading, {title, version, blocks, pending}) do
    blocks = flush_pending(blocks, pending)
    {title, version, blocks ++ [{:heading, 2, String.trim(heading)}], nil}
  end

  defp parse_line("### " <> heading, {title, version, blocks, pending}) do
    blocks = flush_pending(blocks, pending)
    {title, version, blocks ++ [{:heading, 3, String.trim(heading)}], nil}
  end

  defp parse_line("- " <> item, {title, version, blocks, {:unordered_list, items}}),
    do: {title, version, blocks, {:unordered_list, items ++ [clean_inline(item)]}}

  defp parse_line("- " <> item, {title, version, blocks, pending}) do
    blocks = flush_pending(blocks, pending)
    {title, version, blocks, {:unordered_list, [clean_inline(item)]}}
  end

  defp parse_line(line, {title, version, blocks, pending}) do
    case String.trim(line) do
      "" ->
        {title, version, flush_pending(blocks, pending), nil}

      "**Version:**" <> value ->
        version = value |> String.trim() |> String.trim_trailing("  ")
        {title, version, flush_pending(blocks, pending), nil}

      content ->
        parse_content(content, {title, version, blocks, pending})
    end
  end

  defp parse_content(content, state) do
    if Regex.match?(~r/^\d+\.\s+/, content) do
      parse_ordered_item(content, state)
    else
      parse_continuation(content, state)
    end
  end

  defp parse_ordered_item(content, {title, version, blocks, {:ordered_list, items}}) do
    item = Regex.replace(~r/^\d+\.\s+/, content, "") |> clean_inline()
    {title, version, blocks, {:ordered_list, items ++ [item]}}
  end

  defp parse_ordered_item(content, {title, version, blocks, pending}) do
    item = Regex.replace(~r/^\d+\.\s+/, content, "") |> clean_inline()
    {title, version, flush_pending(blocks, pending), {:ordered_list, [item]}}
  end

  defp parse_continuation(content, {title, version, blocks, pending}) do
    paragraph_line = clean_inline(content)

    next_pending =
      case pending do
        {:unordered_list, items} ->
          {:unordered_list, append_to_last_item(items, paragraph_line)}

        {:ordered_list, items} ->
          {:ordered_list, append_to_last_item(items, paragraph_line)}

        {:paragraph, lines} ->
          {:paragraph, lines ++ [paragraph_line]}

        _ ->
          {:paragraph, [paragraph_line]}
      end

    {title, version, blocks, next_pending}
  end

  defp flush_pending(blocks, nil), do: blocks

  defp flush_pending(blocks, {:paragraph, lines}),
    do: blocks ++ [{:paragraph, Enum.join(lines, " ")}]

  defp flush_pending(blocks, {:unordered_list, items}),
    do: blocks ++ [{:unordered_list, items}]

  defp flush_pending(blocks, {:ordered_list, items}),
    do: blocks ++ [{:ordered_list, items}]

  defp append_to_last_item(items, continuation) do
    List.update_at(items, -1, &(&1 <> " " <> continuation))
  end

  defp clean_inline(text) do
    text
    |> String.trim()
    |> String.trim_trailing("  ")
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")
    |> String.replace("**", "")
    |> String.replace("`", "")
  end
end

defmodule Huddlz.Legal do
  @moduledoc """
  Versioned legal documents and the acceptance copy used during registration.

  Markdown files under `docs/legal` are the source of truth. They are
  parsed and embedded at compile time so releases do not depend on the source
  tree being present at runtime.
  """

  alias Huddlz.Legal.Markdown

  @terms_path Path.expand("../../docs/legal/terms-of-service.md", __DIR__)
  @conduct_path Path.expand("../../docs/legal/code-of-conduct.md", __DIR__)
  @privacy_path Path.expand("../../docs/legal/privacy-policy.md", __DIR__)

  @external_resource @terms_path
  @external_resource @conduct_path
  @external_resource @privacy_path

  @documents %{
    terms: @terms_path |> File.read!() |> Markdown.parse(),
    conduct: @conduct_path |> File.read!() |> Markdown.parse(),
    privacy: @privacy_path |> File.read!() |> Markdown.parse()
  }

  @current_version @documents.terms.version
  @acceptance_text "I agree to the Terms of Service and Code of Conduct and acknowledge the Privacy Policy."

  if Enum.any?(@documents, fn {_key, document} -> document.version != @current_version end) do
    raise "All legal documents must use the same version"
  end

  @spec current_version() :: String.t()
  def current_version, do: @current_version

  @spec acceptance_text() :: String.t()
  def acceptance_text, do: @acceptance_text

  @spec document(:terms | :conduct | :privacy) :: map()
  def document(key), do: Map.fetch!(@documents, key)
end
