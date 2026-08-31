defmodule HuddlzWeb.ErrorHTML do
  @moduledoc """
  Static, dependency-light recovery pages for HTML requests.

  These pages deliberately do not use the application or LiveView layouts:
  they must remain useful when the normal rendering stack is unavailable.
  """
  use HuddlzWeb, :html

  def render("404.html", assigns) do
    error_page(assigns,
      code: "404",
      title: "This path doesn’t lead to a huddl.",
      message:
        "The page may have moved, or the address may be incomplete. Private and missing pages look the same here.",
      marker: "route not found",
      retry?: false
    )
  end

  def render("500.html", assigns) do
    error_page(assigns,
      code: "500",
      title: "We lost the thread.",
      message:
        "huddlz hit an unexpected problem. Try this page again, or step back to a familiar place.",
      marker: "temporary interruption",
      retry?: true
    )
  end

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)

  defp error_page(assigns, options) do
    current_user = assigns[:current_user]
    {home_path, home_label} = home_destination(current_user)

    assigns =
      Map.merge(assigns, %{
        code: options[:code],
        title: options[:title],
        message: options[:message],
        marker: options[:marker],
        retry?: options[:retry?],
        current_user: current_user,
        home_path: home_path,
        home_label: home_label,
        retry_path: safe_retry_path(assigns[:error_request_path])
      })

    ~H"""
    <!DOCTYPE html>
    <html lang="en" data-theme="dark">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex, nofollow" />
        <title>{@code} · huddlz</title>
        <link rel="icon" href={~p"/favicon.png"} type="image/png" sizes="512x512" />
        <link rel="alternate icon" href={~p"/favicon.ico"} sizes="16x16 32x32 48x48" />
        <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body class="error-page">
        <header class="error-topbar">
          <a id="error-brand" class="error-brand" href={@home_path} aria-label={@home_label}>
            <span class="brand-glyph" aria-hidden="true">h</span>
            <span class="brand-text">huddlz</span>
          </a>
          <span class="error-topbar-label">recovery</span>
        </header>

        <main class="error-main">
          <section class="error-panel" aria-labelledby="error-title">
            <p class="sr-only">Error {@code}</p>
            <div class="error-status" aria-hidden="true">
              <span>{@code |> String.first()}</span>
              <span class="error-signal">
                <i></i>
                <i></i>
                <i></i>
              </span>
              <span>{@code |> String.last()}</span>
            </div>

            <div class="error-copy">
              <p class="error-kicker">
                <span class="error-kicker-dot" aria-hidden="true"></span>
                {@marker}
              </p>
              <h1 id="error-title">{@title}</h1>
              <p>{@message}</p>

              <nav class="error-actions" aria-label="Recovery options">
                <a
                  :if={@retry?}
                  id="error-retry"
                  class={["btn-primary", "error-action"]}
                  href={@retry_path}
                >
                  <.icon name="hero-arrow-path" class="size-4" /> Try this page again
                </a>
                <a
                  id="error-home"
                  class={[@retry? && "btn-secondary", !@retry? && "btn-primary", "error-action"]}
                  href={@home_path}
                >
                  <.icon name="hero-home" class="size-4" />
                  {@home_label}
                </a>
                <a id="error-discover" class="error-text-link" href={~p"/discover"}>
                  Discover huddlz <.icon name="hero-arrow-right" class="size-4" />
                </a>
              </nav>
            </div>
          </section>
        </main>

        <footer class="error-footer">
          <span>huddlz</span>
          <span aria-hidden="true">/</span>
          <span>Find your people.</span>
        </footer>
      </body>
    </html>
    """
  end

  defp home_destination(nil), do: {~p"/", "huddlz home"}
  defp home_destination(_current_user), do: {~p"/calendar", "Back to Calendar"}

  defp safe_retry_path("//" <> _path), do: ~p"/"
  defp safe_retry_path("/\\" <> _path), do: ~p"/"
  defp safe_retry_path("/" <> path) when path != "", do: "/" <> path

  defp safe_retry_path(_path), do: ~p"/"
end
