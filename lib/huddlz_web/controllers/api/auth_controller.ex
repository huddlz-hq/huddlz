defmodule HuddlzWeb.Api.AuthController do
  use HuddlzWeb, :controller

  alias Huddlz.Accounts.User

  def register(conn, params) do
    User
    |> Ash.Changeset.for_create(:register_with_password, params)
    |> Ash.create()
    |> case do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{token: Ash.Resource.get_metadata(user, :token), user: serialize_self(user)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(error)})
    end
  end

  def sign_in(conn, params) do
    User
    |> Ash.Query.for_read(:sign_in_with_password, params)
    |> Ash.read_one()
    |> case do
      {:ok, %User{} = user} ->
        json(conn, %{token: Ash.Resource.get_metadata(user, :token), user: serialize_self(user)})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def me(conn, _params) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        json(conn, %{user: serialize_self(user)})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  defp serialize_self(user) do
    %{
      id: user.id,
      email: to_string(user.email),
      display_name: user.display_name
    }
  end

  defp format_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.map(errors, &format_one_error/1)
  end

  defp format_errors(error) do
    [%{message: Exception.message(error)}]
  end

  defp format_one_error(error) do
    %{
      field: error |> Map.get(:field) |> stringify_field(),
      message: Exception.message(error)
    }
  end

  defp stringify_field(nil), do: nil
  defp stringify_field(field) when is_atom(field), do: Atom.to_string(field)
  defp stringify_field(field), do: to_string(field)
end
