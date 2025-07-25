defmodule SharedAuthSteps do
  @moduledoc """
  Shared Cucumber step definitions for authentication and user management.

  This module provides reusable steps for:
  - Creating test users with different roles (user, admin)
  - Signing in users for authenticated scenarios

  See test/features/step_definitions/README.md for usage examples.
  """
  use Cucumber.StepDefinition

  import Huddlz.Test.Helpers.Authentication
  import CucumberDatabaseHelper

  # Common step for creating users from data table
  step "the following users exist:", context do
    # Ensure sandbox is available for this step
    ensure_sandbox()

    users =
      context.datatable.maps
      |> Enum.map(fn user_data ->
        role =
          case user_data["role"] do
            "admin" -> :admin
            _ -> :user
          end

        # Create user using Repo directly to work with sandbox
        uuid = Ecto.UUID.generate()
        {:ok, uuid_binary} = Ecto.UUID.dump(uuid)

        attrs = %{
          id: uuid_binary,
          email: user_data["email"],
          display_name: user_data["display_name"] || "Test User",
          role: to_string(role)
        }

        {1, _} =
          Huddlz.Repo.insert_all(
            "users",
            [attrs]
          )

        # Query the user back to get a proper struct
        Huddlz.Repo.get_by!(Huddlz.Accounts.User, email: user_data["email"])
      end)

    Map.put(context, :users, users)
  end

  # Common step for signing in as a user
  step "I am signed in as {string}", %{args: [email]} = context do
    user =
      Enum.find(context.users, fn u ->
        to_string(u.email) == email
      end)

    # Initialize connection if not present
    conn =
      case context[:conn] do
        %Plug.Conn{} = conn -> conn
        _ -> Phoenix.ConnTest.build_conn()
      end

    # Sign in the user using the authentication helper
    conn = login(conn, user)

    # Create a PhoenixTest session
    session = conn |> PhoenixTest.visit("/")

    context
    |> Map.put(:conn, session)
    |> Map.put(:session, session)
    |> Map.put(:current_user, user)
  end
end
