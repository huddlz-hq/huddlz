defmodule HuddlzWeb.Live.ErrorHelpers do
  @moduledoc """
  Centralized error handling helpers for LiveViews.

  Provides consistent error handling patterns including flash messages
  and redirects for common error scenarios like :not_found and :not_authorized.
  """
  import Phoenix.LiveView

  @doc """
  Handles common error scenarios with appropriate flash messages and redirects.

  ## Error Types

  - `:not_found` - Resource was not found, redirects to fallback path
  - `:not_authorized` - User lacks permission, redirects to resource path if available

  ## Options

  - `:resource_name` - Human-readable name of the resource (e.g., "Group", "Huddl")
  - `:fallback_path` - Path to redirect to (required for :not_found)
  - `:resource_path` - Path to the resource (used for :not_authorized)

  ## Examples

      # In a with else clause:
      {:error, :not_found} ->
        {:noreply, handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}

      {:error, :not_authorized} ->
        {:noreply, handle_error(socket, :not_authorized,
          resource_name: "group",
          action: "edit",
          resource_path: ~p"/groups/\#{slug}")}
  """
  def handle_error(socket, :not_found, opts) do
    resource_name = Keyword.get(opts, :resource_name, "Resource")
    fallback_path = Keyword.fetch!(opts, :fallback_path)

    socket
    |> put_flash(:error, "#{resource_name} not found")
    |> redirect(to: fallback_path)
  end

  def handle_error(socket, :not_authorized, opts) do
    redirect_path = Keyword.get(opts, :resource_path) || Keyword.fetch!(opts, :fallback_path)
    error_message = build_not_authorized_message(opts)

    socket
    |> put_flash(:error, error_message)
    |> redirect(to: redirect_path)
  end

  defp build_not_authorized_message(opts) do
    case Keyword.get(opts, :message) do
      nil ->
        resource_name = Keyword.get(opts, :resource_name, "resource")
        action = Keyword.get(opts, :action, "access")
        "You don't have permission to #{action} this #{resource_name}"

      message ->
        message
    end
  end

  @doc """
  Wraps a result tuple to convert various error formats to standard atoms.

  Useful for normalizing Ash query results to standard error atoms.

  ## Examples

      case Huddlz.Communities.get_by_slug(slug, actor: user) do
        {:ok, nil} -> {:error, :not_found}
        {:ok, resource} -> {:ok, resource}
        {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
        {:error, %Ash.Error.Forbidden{}} -> {:error, :not_authorized}
        {:error, _} -> {:error, :not_found}
      end

      # Can be simplified to:
      normalize_result(Huddlz.Communities.get_by_slug(slug, actor: user))
  """
  def normalize_result({:ok, nil}), do: {:error, :not_found}
  def normalize_result({:ok, resource}), do: {:ok, resource}
  def normalize_result({:error, %Ash.Error.Query.NotFound{}}), do: {:error, :not_found}
  def normalize_result({:error, %Ash.Error.Forbidden{}}), do: {:error, :not_authorized}
  def normalize_result({:error, _}), do: {:error, :not_found}

  @doc """
  Checks authorization using Ash.can? and returns a standard result tuple.

  ## Examples

      authorize({group, :update_details}, user)
      # => :ok or {:error, :not_authorized}

      authorize({Huddl, :create, %{group_id: group.id}}, user)
      # => :ok or {:error, :not_authorized}
  """
  def authorize(action_tuple, actor) do
    if Ash.can?(action_tuple, actor), do: :ok, else: {:error, :not_authorized}
  end
end
