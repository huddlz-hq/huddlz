defmodule HuddlzWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use HuddlzWeb, :controller
      use HuddlzWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths,
    do:
      ~w(assets fonts images uploads favicon.ico favicon.svg apple-touch-icon.png icon-192.png icon-512.png)

  @doc """
  The name prefixes the endpoint serves as well as `static_paths/0`.

  Digested assets carry a content hash in their file name, so `~p"/favicon.svg"`
  renders as `/favicon-<hash>.svg` once the assets are built for production. A
  directory keeps its own name and so still matches `static_paths/0`, but a file
  at the root no longer does, and the endpoint would refuse to serve it. Match
  those on their name up to the extension instead.
  """
  def static_prefixes,
    do: for(path <- static_paths(), Path.extname(path) != "", uniq: true, do: Path.rootname(path))

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: HuddlzWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      # LiveView-specific helpers for error handling
      import HuddlzWeb.Live.ErrorHelpers

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: HuddlzWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Design components (`<.flash>`, `<.icon>`, `<.avatar>`, `<.button>`, etc.)
      use HuddlzWeb.Components

      # Common modules used in templates
      alias HuddlzWeb.Layouts
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: HuddlzWeb.Endpoint,
        router: HuddlzWeb.Router,
        statics: HuddlzWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
