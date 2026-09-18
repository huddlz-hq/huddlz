defmodule HuddlzWeb.AuthLive.Components do
  use HuddlzWeb, :html

  attr :token, :string, default: nil
  attr :return_to, :string, default: nil

  def sign_in_token_form(assigns) do
    assigns =
      assign(
        assigns,
        :form,
        to_form(%{"token" => assigns.token, "return_to" => assigns.return_to},
          id: "sign-in-token-form"
        )
      )

    ~H"""
    <.form
      for={@form}
      id="sign-in-token-form"
      action={~p"/auth/user/password/sign_in_with_token"}
      method="post"
      phx-trigger-action={@token != nil}
      class="hidden"
    >
      <.input type="hidden" field={@form[:token]} />
      <.input :if={@return_to} type="hidden" field={@form[:return_to]} />
    </.form>
    """
  end
end
