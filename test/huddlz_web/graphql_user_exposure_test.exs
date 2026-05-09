defmodule HuddlzWeb.GraphqlUserExposureTest do
  # User has no field-level authorization. Every place User shows up in the
  # GraphQL schema is a place sensitive attributes (email, home_location,
  # notification_preferences) could leak across actors via nested loads.
  #
  # This test pins the set of allowed exposures. Each entry must be safe by
  # construction (e.g. action policy enforces `id == ^actor(:id)`, so the
  # returned User is always self).
  #
  # Adding User to a new GraphQL type? Either:
  #   (a) prove it's self-only and add it to @allowed below with a comment, or
  #   (b) add Ash field_policies to lib/huddlz/accounts/user.ex first. See
  #       deps/ash_authentication_phoenix/documentation/tutorials/password-change.md
  #       for the private_fields :include + custom check + context-flag pattern.

  use ExUnit.Case, async: true

  alias HuddlzWeb.GraphqlSchema

  @allowed MapSet.new([
             # Self-only: filter is `id == ^actor(:id)` on the :me action.
             {:query, :me},
             # Mutation result wrappers — each underlying action policy is
             # `id == ^actor(:id)`, so result is always the actor themselves.
             {:change_email_result, :result},
             {:change_password_result, :result},
             {:update_display_name_result, :result},
             {:update_home_location_result, :result},
             {:update_notification_preferences_result, :result}
           ])

  test "no unsanctioned GraphQL exposure of the User type" do
    found =
      for {_name, identifier} <- GraphqlSchema.__absinthe_types__(),
          type = Absinthe.Schema.lookup_type(GraphqlSchema, identifier),
          match?(%Absinthe.Type.Object{}, type),
          type.identifier != :user,
          {field_name, %Absinthe.Type.Field{} = field} <- type.fields,
          unwrap_type(field.type) == :user do
        {type.identifier, field_name}
      end
      |> MapSet.new()

    new_exposures = MapSet.difference(found, @allowed)
    stale_allowlist = MapSet.difference(@allowed, found)

    assert MapSet.size(new_exposures) == 0,
           "New GraphQL exposure of User type detected:\n" <>
             format_pairs(new_exposures) <>
             "\n\nIf this is intentional and provably self-only, add it to @allowed " <>
             "in this file with a comment explaining why. Otherwise add field_policies " <>
             "to lib/huddlz/accounts/user.ex first."

    assert MapSet.size(stale_allowlist) == 0,
           "Allowlist contains stale entries (no longer present in schema):\n" <>
             format_pairs(stale_allowlist) <>
             "\n\nRemove them from @allowed."
  end

  defp format_pairs(pairs) do
    Enum.map_join(pairs, "\n", fn {type, field} -> "  - #{type}.#{field}" end)
  end

  defp unwrap_type(%Absinthe.Type.NonNull{of_type: inner}), do: unwrap_type(inner)
  defp unwrap_type(%Absinthe.Type.List{of_type: inner}), do: unwrap_type(inner)
  defp unwrap_type(identifier) when is_atom(identifier), do: identifier
  defp unwrap_type(_), do: nil
end
