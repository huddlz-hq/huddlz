defmodule Huddlz.Accounts.User.ChangeEmailTest do
  use Huddlz.DataCase, async: true

  describe "change_email" do
    setup do
      user =
        generate(user_with_password(email: "alice@example.com", password: "OldPassword123!"))

      {:ok, user: user}
    end

    test "succeeds with the correct current password", %{user: user} do
      assert {:ok, updated} =
               user
               |> Ash.Changeset.for_update(
                 :change_email,
                 %{email: "alice2@example.com", current_password: "OldPassword123!"},
                 actor: user
               )
               |> Ash.update()

      assert to_string(updated.email) == "alice2@example.com"
    end

    test "rejects when the current password is wrong", %{user: user} do
      assert {:error, %Ash.Error.Forbidden{errors: errors}} =
               user
               |> Ash.Changeset.for_update(
                 :change_email,
                 %{email: "alice2@example.com", current_password: "WrongPassword"},
                 actor: user
               )
               |> Ash.update()

      assert Enum.any?(errors, fn err ->
               match?(%AshAuthentication.Errors.AuthenticationFailed{}, err)
             end)

      reloaded = Ash.reload!(user, authorize?: false)
      assert to_string(reloaded.email) == "alice@example.com"
    end

    test "rejects malformed email addresses", %{user: user} do
      assert {:error, %Ash.Error.Invalid{}} =
               user
               |> Ash.Changeset.for_update(
                 :change_email,
                 %{email: "not an email", current_password: "OldPassword123!"},
                 actor: user
               )
               |> Ash.update()
    end

    test "rejects an email already in use by another user", %{user: user} do
      _other = generate(user(email: "taken@example.com"))

      assert {:error, %Ash.Error.Invalid{}} =
               user
               |> Ash.Changeset.for_update(
                 :change_email,
                 %{email: "taken@example.com", current_password: "OldPassword123!"},
                 actor: user
               )
               |> Ash.update()
    end

    test "forbids changing another user's email", %{user: user} do
      stranger = generate(user())

      assert {:error, %Ash.Error.Forbidden{}} =
               user
               |> Ash.Changeset.for_update(
                 :change_email,
                 %{email: "evil@example.com", current_password: "OldPassword123!"},
                 actor: stranger
               )
               |> Ash.update()
    end

    test "succeeds via the domain code interface", %{user: user} do
      assert {:ok, updated} =
               Huddlz.Accounts.change_email(
                 user,
                 "alice3@example.com",
                 "OldPassword123!",
                 actor: user
               )

      assert to_string(updated.email) == "alice3@example.com"
    end

    test "leaves confirmed_at alone (no re-confirmation required)", %{user: user} do
      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(
          :change_email,
          %{email: "alice2@example.com", current_password: "OldPassword123!"},
          actor: user
        )
        |> Ash.update()

      assert updated.confirmed_at == user.confirmed_at
    end
  end
end
