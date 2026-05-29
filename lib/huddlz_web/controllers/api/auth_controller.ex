defmodule HuddlzWeb.Api.AuthController do
  use HuddlzWeb, :controller

  alias AshAuthentication.TokenResource
  alias AshRateLimiter.LimitExceeded
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
        case rate_limit_error(error) do
          nil ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(error)})

          limit_exceeded ->
            too_many_requests(conn, limit_exceeded)
        end
    end
  end

  def sign_in(conn, params) do
    User
    |> Ash.Query.for_read(:sign_in_with_password, params)
    |> Ash.read_one()
    |> case do
      {:ok, %User{} = user} ->
        json(conn, %{token: Ash.Resource.get_metadata(user, :token), user: serialize_self(user)})

      {:error, error} ->
        case rate_limit_error(error) do
          nil -> invalid_credentials(conn)
          limit_exceeded -> too_many_requests(conn, limit_exceeded)
        end

      _ ->
        invalid_credentials(conn)
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
    result =
      case Map.get(params, "email") do
        email when is_binary(email) and email != "" ->
          User
          |> Ash.ActionInput.for_action(:request_password_reset_token, %{email: email})
          |> Ash.run_action()

        _ ->
          :ok
      end

    # Always 204 so the response can't be used to probe which emails exist — except
    # when rate limited, where a 429 is purely a function of request volume.
    case result do
      {:error, error} ->
        case rate_limit_error(error) do
          nil -> send_resp(conn, :no_content, "")
          limit_exceeded -> too_many_requests(conn, limit_exceeded)
        end

      _ ->
        send_resp(conn, :no_content, "")
    end
  end

  @api_key_min_days 1
  @api_key_max_days 365
  @api_key_default_days 30

  def create_api_key(conn, params) do
    with %User{} = user <- conn.assigns[:current_user] || :unauthorized,
         {:ok, days} <- parse_expires_in_days(params) do
      expires_at = DateTime.utc_now() |> DateTime.add(days * 24 * 3600, :second)

      ApiKey
      |> Ash.Changeset.for_create(:create, %{expires_at: expires_at}, actor: user)
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
    else
      :unauthorized ->
        auth_required(conn)

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{field: "expires_in_days", message: message}]})
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

  defp invalid_credentials(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Invalid email or password"})
  end

  # Walk the Ash error tree for a rate-limit error, which arrives wrapped in the
  # usual Forbidden/Invalid classes.
  defp rate_limit_error(%LimitExceeded{} = error), do: error

  defp rate_limit_error(%{errors: errors}) when is_list(errors),
    do: Enum.find_value(errors, &rate_limit_error/1)

  defp rate_limit_error(errors) when is_list(errors),
    do: Enum.find_value(errors, &rate_limit_error/1)

  defp rate_limit_error(_), do: nil

  # The limiter doesn't surface the exact wait, so advertise the full window (an
  # upper bound) as Retry-After.
  defp too_many_requests(conn, %LimitExceeded{per: per}) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(max(1, div(per, 1000))))
    |> put_status(:too_many_requests)
    |> json(%{error: "Too many requests. Please try again later."})
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Not found"})
  end

  defp parse_expires_in_days(%{"expires_in_days" => value}) when is_integer(value),
    do: validate_days(value)

  defp parse_expires_in_days(%{"expires_in_days" => value}) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> validate_days(n)
      _ -> {:error, "must be an integer"}
    end
  end

  defp parse_expires_in_days(%{"expires_in_days" => _}),
    do: {:error, "must be an integer"}

  defp parse_expires_in_days(_), do: {:ok, @api_key_default_days}

  defp validate_days(n) when n in @api_key_min_days..@api_key_max_days, do: {:ok, n}

  defp validate_days(_),
    do: {:error, "must be between #{@api_key_min_days} and #{@api_key_max_days} days"}

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
