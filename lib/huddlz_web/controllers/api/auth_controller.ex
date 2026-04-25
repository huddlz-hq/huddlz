defmodule HuddlzWeb.Api.AuthController do
  use HuddlzWeb, :controller

  alias AshAuthentication.TokenResource
  alias Huddlz.Accounts.{ApiKey, Token, User}

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

  def sign_out(conn, _params) do
    with %User{} <- conn.assigns[:current_user],
         [bearer] <- get_req_header(conn, "authorization"),
         "Bearer " <> token <- bearer,
         :ok <- TokenResource.Actions.revoke(Token, token) do
      send_resp(conn, :no_content, "")
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  def password_reset(conn, params) do
    case Map.get(params, "email") do
      email when is_binary(email) and email != "" ->
        User
        |> Ash.ActionInput.for_action(:request_password_reset_token, %{email: email})
        |> Ash.run_action()

      _ ->
        :ok
    end

    send_resp(conn, :no_content, "")
  end

  def create_api_key(conn, params) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        days = parse_expires_in_days(params)
        expires_at = DateTime.utc_now() |> DateTime.add(days * 24 * 3600, :second)

        ApiKey
        |> Ash.Changeset.for_create(
          :create,
          %{expires_at: expires_at},
          actor: user
        )
        |> Ash.create()
        |> case do
          {:ok, record} ->
            conn
            |> put_status(:created)
            |> json(%{
              id: record.id,
              key: record.__metadata__.plaintext_api_key,
              expires_at: record.expires_at
            })

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(error)})
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  def list_api_keys(conn, _params) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        keys =
          ApiKey
          |> Ash.Query.load([:valid])
          |> Ash.read!(actor: user)
          |> Enum.map(&serialize_api_key/1)

        json(conn, %{api_keys: keys})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  defp serialize_api_key(record) do
    %{
      id: record.id,
      expires_at: record.expires_at,
      valid: record.valid
    }
  end

  def delete_api_key(conn, %{"id" => id}) do
    case conn.assigns[:current_user] do
      %User{} = user -> destroy_api_key(conn, user, id)
      _ -> auth_required(conn)
    end
  end

  defp destroy_api_key(conn, user, id) do
    with {:ok, record} <- Ash.get(ApiKey, id, actor: user),
         :ok <- Ash.destroy(record, actor: user) do
      send_resp(conn, :no_content, "")
    else
      _ -> not_found(conn)
    end
  end

  defp auth_required(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Authentication required"})
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Not found"})
  end

  defp parse_expires_in_days(%{"expires_in_days" => value}) when is_integer(value), do: value

  defp parse_expires_in_days(%{"expires_in_days" => value}) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> 30
    end
  end

  defp parse_expires_in_days(_), do: 30

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
