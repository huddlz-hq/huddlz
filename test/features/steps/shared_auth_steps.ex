defmodule Huddlz.Test.Features.Steps.SharedAuthSteps do
  @moduledoc """
  Shared authentication step definitions for Cucumber tests.

  This module provides common authentication-related steps that can be
  imported into any Cucumber test file to avoid duplication.

  ## Usage

      defmodule MyFeatureTest do
        use Huddlz.DataCase
        use Cucumber, feature: "my_feature.feature"
        use Huddlz.Test.Features.Steps.SharedAuthSteps
        
        # Your specific step definitions...
      end
  """

  use Cucumber.SharedSteps

  import Huddlz.Test.Helpers.Authentication
  import Huddlz.Test.Generator
  alias Huddlz.Accounts.User

  @doc """
  Creates users with the specified attributes.

  Example usage in feature file:

      Given the following users exist:
        | email                  | role       | display_name |
        | alice@example.com      | owner      | Alice        |
        | bob@example.com        | member     | Bob          |
  """
  defstep "the following users exist:", %{args: [%{rows: rows}]} = context do
    users =
      Enum.reduce(rows, %{}, fn row, acc ->
        attrs = %{
          email: row["email"],
          display_name: row["display_name"]
        }

        # Add role if specified
        attrs =
          if row["role"] do
            Map.put(attrs, :role, row["role"])
          else
            attrs
          end

        # Create user using Ash.Seed
        user = Ash.Seed.seed!(User, attrs)

        # Store user by email for easy lookup
        Map.put(acc, user.email, user)
      end)

    {:ok, Map.put(context, :users, users)}
  end

  @doc """
  Signs in as the specified user.

  Example usage in feature file:

      When I am signed in as "alice@example.com"
  """
  defstep "I am signed in as {string}", %{args: [email]} = context do
    # Find the user by email
    user = Map.get(context.users, email)

    if user do
      # Log in the user using the authentication helper
      conn = login(context.conn, user)

      # Create a PhoenixTest session with the authenticated conn
      session = PhoenixTest.visit(conn, "/")

      # Update context with authentication info
      {:ok,
       context
       |> Map.put(:conn, conn)
       |> Map.put(:session, session)
       |> Map.put(:current_user, user)}
    else
      {:error, "User with email '#{email}' not found in context"}
    end
  end
end
