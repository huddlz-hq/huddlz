defmodule HuddlzWeb.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  use HuddlzWeb.Components

  describe "pill/1" do
    test "renders default pill with no extra variant class" do
      assigns = %{}

      html = rendered_to_string(~H"<.pill>Going</.pill>")

      assert html =~ "Going"
      assert html =~ ~s(class="pill)
      refute html =~ "cyan"
      refute html =~ "warn"
    end

    test "renders cyan/warn/muted variants" do
      assigns = %{}

      cyan = rendered_to_string(~H"<.pill variant={:cyan}>Hosting</.pill>")
      warn = rendered_to_string(~H"<.pill variant={:warn}>Waitlist</.pill>")
      muted = rendered_to_string(~H"<.pill variant={:muted}>Past</.pill>")

      assert cyan =~ "pill cyan"
      assert warn =~ "pill warn"
      assert muted =~ "pill muted"
    end
  end

  describe "chip/1" do
    test "renders a button chip by default with active state" do
      assigns = %{}

      active = rendered_to_string(~H"<.chip active>Upcoming · 6</.chip>")
      inactive = rendered_to_string(~H"<.chip>Past</.chip>")

      assert active =~ "<button"
      assert active =~ "chip is-active"
      assert active =~ "Upcoming · 6"

      assert inactive =~ "<button"
      assert inactive =~ ~s(class="chip)
      refute inactive =~ "is-active"
    end

    test "renders an optional count after the label" do
      assigns = %{}

      counted = rendered_to_string(~H"<.chip count={3}>Upcoming</.chip>")
      plain = rendered_to_string(~H"<.chip>Upcoming</.chip>")

      assert counted =~ ~s(<span class="chip-count"> 3</span>)
      refute plain =~ "chip-count"
    end

    test "renders a link when href is given" do
      assigns = %{}
      active = rendered_to_string(~H|<.chip href="/discover" active>Discover</.chip>|)
      inactive = rendered_to_string(~H|<.chip href="/discover">Discover</.chip>|)

      active_document = LazyHTML.from_fragment(active)
      inactive_document = LazyHTML.from_fragment(inactive)

      assert [_] =
               Enum.to_list(
                 LazyHTML.query(
                   active_document,
                   "a.chip.is-active[href='/discover'][aria-current='page']"
                 )
               )

      assert [_] = Enum.to_list(LazyHTML.query(inactive_document, "a.chip[href='/discover']"))
      assert Enum.empty?(LazyHTML.query(inactive_document, "a[aria-current]"))
    end
  end

  describe "button/1" do
    test "renders btn-primary variant" do
      assigns = %{}
      html = rendered_to_string(~H"<.button variant={:primary}>Save</.button>")

      assert html =~ "btn-primary"
      assert html =~ "Save"
    end

    test "renders secondary by default and as a link with href" do
      assigns = %{}

      btn = rendered_to_string(~H"<.button>Cancel</.button>")
      link = rendered_to_string(~H|<.button href="/discover">Browse</.button>|)

      assert btn =~ "<button"
      assert btn =~ "btn-secondary"

      assert link =~ "<a"
      assert link =~ ~s(href="/discover")
      assert link =~ "btn-secondary"
    end

    test "honors type=\"submit\" from the caller" do
      # Regression: `type` used to be declared in the `:rest` global include,
      # so an explicit `type="submit"` from the caller was silently overridden
      # by the component's default `type="button"`. Profile forms looked
      # rendered but didn't actually submit.
      assigns = %{}

      submit = rendered_to_string(~H|<.button type="submit">Save</.button>|)
      default = rendered_to_string(~H"<.button>Cancel</.button>")

      assert submit =~ ~s(type="submit")
      refute submit =~ ~s(type="button")
      assert default =~ ~s(type="button")
    end
  end

  describe "toggle/1" do
    test "renders a labeled native checkbox with switch state" do
      form = to_form(%{"enabled" => "true"}, as: :settings)
      assigns = %{field: form[:enabled]}

      html =
        rendered_to_string(~H"""
        <.toggle field={@field} label="Email notifications" />
        """)

      assert html =~ ~s(type="checkbox")
      assert html =~ ~s(role="switch")
      assert html =~ ~s(aria-checked="true")
      assert html =~ ~s(checked)
      assert html =~ "Email notifications"
      refute html =~ ~s(display: none)
    end
  end

  describe "panel/1" do
    test "renders panel with optional head and sub" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.panel>
          <:head>
            <h2>Members</h2>
          </:head>
          <:sub>Roster summary</:sub>
          Body content
        </.panel>
        """)

      assert html =~ ~s(class="panel)
      assert html =~ "panel-head"
      assert html =~ "<h2>Members</h2>"
      assert html =~ ~s(class="panel-sub")
      assert html =~ "Roster summary"
      assert html =~ "Body content"
    end

    test "renders panel without head when not given" do
      assigns = %{}
      html = rendered_to_string(~H"<.panel>Just body</.panel>")

      assert html =~ "Just body"
      refute html =~ "panel-head"
      refute html =~ "panel-sub"
    end
  end

  describe "card/1" do
    test "renders an anchor card with body, optional cover and foot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.card href="/groups/foo">
          <:cover>
            <.date_stamp month="MAY" day={22} />
            <.card_tag variant={:hybrid}>Hybrid</.card_tag>
          </:cover>
          <:body>
            <span class="card-group">Phoenix Elixir</span>
            <div class="card-title">Ash workshop</div>
          </:body>
          <:foot>
            <.pill variant={:cyan}>Hosting</.pill>
          </:foot>
        </.card>
        """)

      assert html =~ "<a"
      assert html =~ ~s(href="/groups/foo")
      assert html =~ ~s(class="card)
      assert html =~ ~s(class="card-cover")
      assert html =~ "date-stamp"
      assert html =~ ~s(class="card-tag hybrid")
      assert html =~ "Hybrid"
      assert html =~ "Ash workshop"
      assert html =~ "card-foot"
      assert html =~ "pill cyan"
    end
  end

  describe "cover_fallback/1" do
    test "renders the group's initials inside the neutral cover tile" do
      assigns = %{}

      html = rendered_to_string(~H|<.cover_fallback name="Phoenix Elixir Meetup" />|)

      assert html =~ ~s(class="card-cover-fallback")
      assert html =~ ~s(aria-hidden="true")
      assert html =~ "<span>PE</span>"
    end
  end

  describe "empty_state/1" do
    test "renders icon, title, guidance and action" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_state icon="hero-magnifying-glass" title="Nothing matches those filters">
          Try a wider distance or clear the type and date filters.
          <:action><.button>Clear filters</.button></:action>
        </.empty_state>
        """)

      assert html =~ ~s(class="empty-state )
      assert html =~ ~s(class="empty-state-icon")
      assert html =~ "hero-magnifying-glass"
      assert html =~ "<h3>Nothing matches those filters</h3>"
      assert html =~ "Try a wider distance"
      assert html =~ ~s(class="empty-state-action")
      assert html =~ "Clear filters"
    end

    test "omits the icon, paragraph and action when not given" do
      assigns = %{}

      html = rendered_to_string(~H|<.empty_state title="No notifications yet" />|)

      assert html =~ "<h3>No notifications yet</h3>"
      refute html =~ "empty-state-icon"
      refute html =~ "<p"
      refute html =~ "empty-state-action"
    end
  end

  describe "list_row/1" do
    test "renders a row with passed content and class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.list_row class="notif-row unread">
          <div class="row-title">New invite</div>
        </.list_row>
        """)

      assert html =~ ~s(class="row notif-row unread")
      assert html =~ "New invite"
    end
  end

  describe "input/1" do
    test "renders form-row with label, input, help" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.input
          name="title"
          value=""
          label="Title"
          help="What you'd call this huddl on a flyer"
        />
        """)

      assert html =~ ~s(class="form-row")
      assert html =~ ~s(class="form-label")
      assert html =~ "Title</label>"
      assert html =~ ~s(class="form-input)
      assert html =~ ~s(name="title")
      assert html =~ ~s(class="form-help")
    end
  end

  describe "textarea/1" do
    test "renders form-textarea" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.textarea name="description" value="" label="Description" />
        """)

      assert html =~ "<textarea"
      assert html =~ ~s(class="form-textarea)
      assert html =~ ~s(name="description")
    end
  end

  describe "select/1" do
    test "renders form-select with options and prompt" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.select
          name="frequency"
          value=""
          label="Frequency"
          prompt="Choose..."
          options={[{"Weekly", "weekly"}, {"Monthly", "monthly"}]}
        />
        """)

      assert html =~ "<select"
      assert html =~ ~s(class="form-select)
      assert html =~ ~s(value="">Choose...</option>)
      assert html =~ ~s(value="weekly">Weekly</option>)
      assert html =~ ~s(value="monthly">Monthly</option>)
    end
  end
end
