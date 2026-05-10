defmodule HuddlzWeb.V3Test do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  use HuddlzWeb.V3

  describe "v3_pill/1" do
    test "renders default pill with no extra variant class" do
      assigns = %{}

      html = rendered_to_string(~H"<.v3_pill>Going</.v3_pill>")

      assert html =~ "Going"
      assert html =~ ~s(class="pill)
      refute html =~ "cyan"
      refute html =~ "warn"
    end

    test "renders cyan/warn/muted variants" do
      assigns = %{}

      cyan = rendered_to_string(~H"<.v3_pill variant={:cyan}>Hosting</.v3_pill>")
      warn = rendered_to_string(~H"<.v3_pill variant={:warn}>Waitlist</.v3_pill>")
      muted = rendered_to_string(~H"<.v3_pill variant={:muted}>Past</.v3_pill>")

      assert cyan =~ "pill cyan"
      assert warn =~ "pill warn"
      assert muted =~ "pill muted"
    end
  end

  describe "v3_chip/1" do
    test "renders a button chip by default with active state" do
      assigns = %{}

      active = rendered_to_string(~H"<.v3_chip active>Upcoming · 6</.v3_chip>")
      inactive = rendered_to_string(~H"<.v3_chip>Past</.v3_chip>")

      assert active =~ "<button"
      assert active =~ "chip is-active"
      assert active =~ "Upcoming · 6"

      assert inactive =~ "<button"
      assert inactive =~ ~s(class="chip)
      refute inactive =~ "is-active"
    end

    test "renders a link when href is given" do
      assigns = %{}
      html = rendered_to_string(~H|<.v3_chip href="/discover">Discover</.v3_chip>|)

      assert html =~ "<a"
      assert html =~ ~s(href="/discover")
      assert html =~ "chip"
    end
  end

  describe "v3_button/1" do
    test "renders btn-primary variant" do
      assigns = %{}
      html = rendered_to_string(~H"<.v3_button variant={:primary}>Save</.v3_button>")

      assert html =~ "btn-primary"
      assert html =~ "Save"
    end

    test "renders secondary by default and as a link with href" do
      assigns = %{}

      btn = rendered_to_string(~H"<.v3_button>Cancel</.v3_button>")
      link = rendered_to_string(~H|<.v3_button href="/discover">Browse</.v3_button>|)

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

      submit = rendered_to_string(~H|<.v3_button type="submit">Save</.v3_button>|)
      default = rendered_to_string(~H"<.v3_button>Cancel</.v3_button>")

      assert submit =~ ~s(type="submit")
      refute submit =~ ~s(type="button")
      assert default =~ ~s(type="button")
    end
  end

  describe "v3_panel/1" do
    test "renders panel with optional head and sub" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.v3_panel>
          <:head>
            <h2>Members</h2>
          </:head>
          <:sub>Roster summary</:sub>
          Body content
        </.v3_panel>
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
      html = rendered_to_string(~H"<.v3_panel>Just body</.v3_panel>")

      assert html =~ "Just body"
      refute html =~ "panel-head"
      refute html =~ "panel-sub"
    end
  end

  describe "v3_card/1" do
    test "renders an anchor card with body, optional cover and foot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.v3_card href="/groups/foo" gradient={3}>
          <:cover>
            <.v3_date_stamp month="MAY" day={22} />
            <.v3_card_tag variant={:hybrid}>Hybrid</.v3_card_tag>
          </:cover>
          <:body>
            <span class="card-group">Phoenix Elixir</span>
            <div class="card-title">Ash workshop</div>
          </:body>
          <:foot>
            <.v3_pill variant={:cyan}>Hosting</.v3_pill>
          </:foot>
        </.v3_card>
        """)

      assert html =~ "<a"
      assert html =~ ~s(href="/groups/foo")
      assert html =~ ~s(class="card)
      assert html =~ "card-cover gradient-3"
      assert html =~ "date-stamp"
      assert html =~ ~s(class="card-tag hybrid")
      assert html =~ "Hybrid"
      assert html =~ "Ash workshop"
      assert html =~ "card-foot"
      assert html =~ "pill cyan"
    end
  end

  describe "v3_list_row/1" do
    test "renders a row with passed content and class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.v3_list_row class="notif-row unread">
          <div class="row-title">New invite</div>
        </.v3_list_row>
        """)

      assert html =~ ~s(class="row notif-row unread")
      assert html =~ "New invite"
    end
  end

  describe "v3_input/1" do
    test "renders form-row with label, input, help" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.v3_input
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

  describe "v3_textarea/1" do
    test "renders form-textarea" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.v3_textarea name="description" value="" label="Description" />
        """)

      assert html =~ "<textarea"
      assert html =~ ~s(class="form-textarea)
      assert html =~ ~s(name="description")
    end
  end

  describe "v3_select/1" do
    test "renders form-select with options and prompt" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.v3_select
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
