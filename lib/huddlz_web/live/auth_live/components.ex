defmodule HuddlzWeb.AuthLive.Components do
  use HuddlzWeb, :html

  attr :token, :string, default: nil
  attr :return_to, :string, default: nil

  def sign_in_token_form(assigns) do
    ~H"""
    <.form
      for={%{}}
      id="sign-in-token-form"
      action={~p"/auth/user/password/sign_in_with_token"}
      method="post"
      phx-trigger-action={@token != nil}
      class="hidden"
    >
      <input type="hidden" name="token" value={@token} />
      <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
    </.form>
    """
  end
end
