defmodule HuddlzWeb.DevDesignController do
  @moduledoc """
  Development-only design lab for high-fidelity prototypes.

  Routes to this controller are mounted only when `:dev_routes` is enabled.
  """

  use HuddlzWeb, :controller

  @clickthrough_styles_path Path.expand("docs/design/clickthrough/styles.css", File.cwd!())
  @image_dir Path.expand("docs/design/images", File.cwd!())

  @surface_templates %{
    "landing" => :clickthrough_landing,
    "sign-in" => :clickthrough_sign_in,
    "register" => :clickthrough_register,
    "reset-request" => :clickthrough_reset_request,
    "reset-confirm" => :clickthrough_reset_confirm,
    "email-confirm" => :clickthrough_email_confirm,
    "explore" => :clickthrough_explore,
    "my-huddlz" => :clickthrough_my_huddlz,
    "my-groups" => :clickthrough_my_groups,
    "calendar" => :clickthrough_calendar,
    "notifications" => :clickthrough_notifications,
    "group" => :clickthrough_group,
    "huddl" => :clickthrough_huddl,
    "profile" => :clickthrough_profile,
    "settings" => :clickthrough_settings,
    "organize-overview" => :clickthrough_organize_overview,
    "organize-huddlz" => :clickthrough_organize_huddlz,
    "organize-members" => :clickthrough_organize_members,
    "group-new" => :clickthrough_group_new,
    "group-edit" => :clickthrough_group_edit,
    "huddl-new" => :clickthrough_huddl_new,
    "huddl-edit" => :clickthrough_huddl_edit,
    "help" => :clickthrough_help
  }

  def index(conn, _params) do
    html(conn, """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Huddlz Design Lab</title>
        <style>
          :root {
            color-scheme: dark;
            --bg: #020404;
            --panel: #050808;
            --line: #142022;
            --line-strong: #243639;
            --text: #f4fbfb;
            --soft: #b7c1c3;
            --muted: #7d888b;
            --cyan: #18cbd4;
            --radius: 7px;
            --font: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            --mono: "SFMono-Regular", Consolas, "Liberation Mono", monospace;
          }

          * { box-sizing: border-box; }

          body {
            margin: 0;
            min-height: 100vh;
            background:
              radial-gradient(circle at 80% 8%, rgba(24, 203, 212, 0.10), transparent 360px),
              var(--bg);
            color: var(--text);
            font-family: var(--font);
          }

          main {
            max-width: 1040px;
            margin: 0 auto;
            padding: 56px 28px;
          }

          .brand {
            color: #eaffff;
            font-family: var(--mono);
            font-size: 28px;
            letter-spacing: 0;
            text-shadow: 0 0 12px rgba(24, 203, 212, 0.32);
          }

          h1 {
            margin: 70px 0 16px;
            max-width: 760px;
            font-size: clamp(42px, 6vw, 72px);
            line-height: 1;
            letter-spacing: 0;
          }

          p {
            max-width: 720px;
            color: var(--soft);
            font-size: 18px;
            line-height: 1.5;
          }

          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 18px;
            margin-top: 42px;
          }

          .card {
            min-height: 220px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            border: 1px solid var(--line);
            border-radius: var(--radius);
            background: var(--panel);
            padding: 22px;
            text-decoration: none;
          }

          .card:hover,
          .card:focus-visible {
            outline: 0;
            border-color: var(--cyan);
          }

          .eyebrow {
            color: var(--cyan);
            font-size: 12px;
            font-weight: 900;
            text-transform: uppercase;
          }

          .card h2 {
            margin: 14px 0 10px;
            color: var(--text);
            font-size: 24px;
          }

          .card p {
            margin: 0;
            color: var(--muted);
            font-size: 14px;
          }

          .open {
            margin-top: 28px;
            color: var(--text);
            font-weight: 900;
          }
        </style>
      </head>
      <body>
        <main>
          <div class="brand">huddlz</div>
          <h1>Design lab</h1>
          <p>Development-only prototypes for exploring Huddlz product flows in high-fidelity HTML and CSS before moving them into LiveView.</p>

          <section class="grid" aria-label="Design prototypes">
            <a class="card" href="/dev/design/clickthrough">
              <div>
                <div class="eyebrow">Clickthrough</div>
                <h2>App walkthrough</h2>
                <p>Click through every signed-in and signed-out surface — explore, my huddlz, my groups, calendar, organize, group/huddl detail, profile, settings, notifications, auth, and CRUD forms.</p>
              </div>
              <div class="open">Open clickthrough</div>
            </a>
          </section>
        </main>
      </body>
    </html>
    """)
  end

  def clickthrough(conn, params) do
    surface = params["surface"] || "landing"

    case Map.fetch(@surface_templates, surface) do
      {:ok, template} ->
        conn
        |> put_view(HuddlzWeb.DevDesignHTML)
        |> put_root_layout(false)
        |> put_layout({HuddlzWeb.DevDesignHTML, :clickthrough_layout})
        |> assign(:active, surface)
        |> assign(:query, params["q"] || "")
        |> assign(:signed_in, params["signed_in"] != "0")
        |> render(template)

      :error ->
        send_resp(conn, 404, "Unknown surface")
    end
  end

  def clickthrough_styles(conn, _params) do
    conn
    |> put_resp_content_type("text/css")
    |> send_file(200, @clickthrough_styles_path)
  end

  def image(conn, %{"filename" => filename}) do
    path = Path.join(@image_dir, Path.basename(filename))

    if File.exists?(path) do
      conn
      |> put_resp_content_type("image/svg+xml")
      |> send_file(200, path)
    else
      send_resp(conn, 404, "Not found")
    end
  end
end
