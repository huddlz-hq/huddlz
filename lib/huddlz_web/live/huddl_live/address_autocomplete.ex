defmodule HuddlzWeb.HuddlLive.AddressAutocomplete do
  @moduledoc """
  Shared address autocomplete logic for huddl create/edit forms.
  Injects assigns, event handlers, and helpers via `use`.
  """

  defmacro __using__(_opts) do
    quote do
      defp assign_address_autocomplete(socket) do
        Phoenix.Component.assign(socket,
          address_suggestions: [],
          show_address_suggestions: false,
          address_loading: false,
          address_error: nil,
          address_session_token: Ecto.UUID.generate()
        )
      end

      def handle_event("select_location", %{"display-text" => text}, socket) do
        current_params = socket.assigns.form.source.params || %{}
        updated_params = Map.put(current_params, "physical_location", text)
        form = AshPhoenix.Form.validate(socket.assigns.form, updated_params)

        {:noreply,
         Phoenix.Component.assign(socket,
           form: to_form(form),
           address_suggestions: [],
           show_address_suggestions: false,
           address_session_token: Ecto.UUID.generate()
         )}
      end

      def handle_event("dismiss_suggestions", _params, socket) do
        {:noreply, Phoenix.Component.assign(socket, show_address_suggestions: false)}
      end

      defp maybe_autocomplete_address(socket, text)
           when is_binary(text) and byte_size(text) >= 2 do
        session_token = socket.assigns.address_session_token

        socket
        |> Phoenix.Component.assign(address_loading: true)
        |> start_async(:autocomplete_address, fn ->
          Huddlz.Places.autocomplete(text, session_token, types: [])
        end)
      end

      defp maybe_autocomplete_address(socket, _text) do
        Phoenix.Component.assign(socket,
          address_suggestions: [],
          show_address_suggestions: false,
          address_loading: false,
          address_error: nil
        )
      end

      @impl true
      def handle_async(:autocomplete_address, {:ok, {:ok, suggestions}}, socket) do
        {:noreply,
         Phoenix.Component.assign(socket,
           address_suggestions: suggestions,
           show_address_suggestions: suggestions != [],
           address_loading: false,
           address_error: nil
         )}
      end

      def handle_async(:autocomplete_address, {:ok, {:error, reason}}, socket) do
        {:noreply,
         Phoenix.Component.assign(socket,
           address_suggestions: [],
           show_address_suggestions: false,
           address_loading: false,
           address_error: Huddlz.Places.error_message(reason)
         )}
      end

      def handle_async(:autocomplete_address, {:exit, _reason}, socket) do
        {:noreply, Phoenix.Component.assign(socket, address_loading: false)}
      end
    end
  end
end
