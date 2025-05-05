defmodule HuddlzWeb.AuthController do
  use HuddlzWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    # Set display name for new users if they don't have one
    user =
      if is_nil(user.display_name) do
        # Generate a random display name for new users
        display_name = generate_random_display_name()

        # Update the user with the random display name
        {:ok, updated_user} =
          Huddlz.Accounts.User
          |> Ash.Changeset.for_update(:update, user.id, %{display_name: display_name})
          |> Ash.update()

        updated_user
      else
        user
      end

    message =
      case activity do
        {:confirm_new_user, :confirm} ->
          "Your email address has now been confirmed"

        {:password, :reset} ->
          "Your password has successfully been reset"

        {:magic_link, :sign_in} ->
          if is_nil(user.display_name),
            do: "Your account has been created",
            else: "You are now signed in"

        _ ->
          "You are now signed in"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session()
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end

  # Helper function to generate a random display name
  defp generate_random_display_name do
    adjectives = [
      "Happy",
      "Clever",
      "Gentle",
      "Brave",
      "Wise",
      "Cool",
      "Brilliant",
      "Swift",
      "Calm",
      "Daring"
    ]

    nouns = [
      "Dolphin",
      "Tiger",
      "Eagle",
      "Panda",
      "Wolf",
      "Falcon",
      "Bear",
      "Fox",
      "Lion",
      "Hawk"
    ]

    random_number = :rand.uniform(999)

    "#{Enum.random(adjectives)}#{Enum.random(nouns)}#{random_number}"
  end
end
