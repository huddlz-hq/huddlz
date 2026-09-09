defmodule HuddlzWeb.Live.LocationAutocompleteTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias HuddlzWeb.Live.LocationAutocomplete

  @suggestion %{
    place_id: "place-1",
    display_text: "Austin, TX, USA",
    main_text: "Austin",
    secondary_text: "TX, USA"
  }

  describe "while a place search is in flight" do
    for variant <- [:filter_pill, :form] do
      @variant variant

      test "the #{variant} variant shows placeholder rows before the first answer", %{conn: _conn} do
        document = render_autocomplete(variant: @variant, loading: true, suggestions: [])

        assert [status] =
                 Floki.find(
                   document,
                   ~s|#location-searching[role="status"][aria-busy="true"][aria-label="Searching places"]|
                 )

        assert length(Floki.find(status, ".filter-location-option.is-skeleton[aria-hidden]")) == 3
        assert Floki.find(document, "[role='option']") == []
        assert Floki.find(document, ".filter-location-listbox.empty") == []
      end

      test "the #{variant} variant keeps an earlier list on screen, marked stale", %{conn: _conn} do
        document =
          render_autocomplete(
            variant: @variant,
            loading: true,
            suggestions: [@suggestion],
            show_suggestions: true
          )

        assert [_option] =
                 Floki.find(document, ".filter-location-listbox.is-stale [role='option']")

        assert Floki.find(document, "#location-searching") == []
      end

      test "the #{variant} variant drops both once the answer lands", %{conn: _conn} do
        document =
          render_autocomplete(
            variant: @variant,
            loading: false,
            suggestions: [@suggestion],
            show_suggestions: true
          )

        assert [_option] = Floki.find(document, "[role='option']")
        assert Floki.find(document, ".is-stale, #location-searching") == []
      end
    end
  end

  defp render_autocomplete(assigns) do
    LocationAutocomplete
    |> render_component(Keyword.merge([id: "location", field_name: "location"], assigns))
    |> Floki.parse_fragment!()
  end
end
