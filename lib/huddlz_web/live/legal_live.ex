defmodule HuddlzWeb.LegalLive do
  @moduledoc """
  Public, versioned legal documents rendered from the approved Markdown source.
  """

  use HuddlzWeb, :live_view

  alias Huddlz.Legal

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(_params, _uri, socket) do
    document = Legal.document(document_key(socket.assigns.live_action))

    {:noreply,
     socket
     |> assign(:document, document)
     |> assign(:page_title, document.title)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="help"
    >
      <article id="legal-document" class="legal-document">
        <header class="legal-document-head">
          <.link navigate={~p"/help"} class="legal-back-link">← Help</.link>
          <h1>{@document.title}</h1>
          <p>Version {@document.version}</p>
        </header>

        <nav class="legal-document-nav" aria-label="Legal documents">
          <.link
            navigate={~p"/terms"}
            aria-current={if @live_action == :terms, do: "page"}
          >
            Terms of Service
          </.link>
          <.link
            navigate={~p"/code-of-conduct"}
            aria-current={if @live_action == :conduct, do: "page"}
          >
            Code of Conduct
          </.link>
          <.link
            navigate={~p"/privacy"}
            aria-current={if @live_action == :privacy, do: "page"}
          >
            Privacy Policy
          </.link>
        </nav>

        <div class="legal-document-body">
          <%= for {block, index} <- Enum.with_index(@document.blocks) do %>
            <.legal_block block={block} index={index} />
          <% end %>
        </div>
      </article>
    </Layouts.app>
    """
  end

  attr :block, :any, required: true
  attr :index, :integer, required: true

  defp legal_block(%{block: {:heading, 2, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <h2 id={"legal-section-#{@index}"}>{@text}</h2>
    """
  end

  defp legal_block(%{block: {:heading, 3, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <h3 id={"legal-subsection-#{@index}"}>{@text}</h3>
    """
  end

  defp legal_block(%{block: {:paragraph, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <p>{@text}</p>
    """
  end

  defp legal_block(%{block: {:unordered_list, items}} = assigns) do
    assigns = assign(assigns, :items, items)

    ~H"""
    <ul>
      <li :for={item <- @items}>{item}</li>
    </ul>
    """
  end

  defp legal_block(%{block: {:ordered_list, items}} = assigns) do
    assigns = assign(assigns, :items, items)

    ~H"""
    <ol>
      <li :for={item <- @items}>{item}</li>
    </ol>
    """
  end

  defp document_key(:terms), do: :terms
  defp document_key(:conduct), do: :conduct
  defp document_key(:privacy), do: :privacy
end
