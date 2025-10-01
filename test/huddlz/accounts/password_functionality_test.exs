defmodule Huddlz.Accounts.PasswordFunctionalityTest do
  use Huddlz.DataCase

  alias Huddlz.Accounts.User
  import Huddlz.Generator

  describe "register_with_password" do
    test "successfully registers a new user with password" do
      assert {:ok, user} =
               User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: "test@example.com",
                 password: "SuperSecret123!",
                 password_confirmation: "SuperSecret123!",
                 display_name: "Test User"
               })
               |> Ash.create()

      assert to_string(user.email) == "test@example.com"
      assert user.hashed_password != nil
      assert user.hashed_password != "SuperSecret123!"
    end

    test "fails with mismatched passwords" do
      assert {:error, changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: "test@example.com",
                 password: "SuperSecret123!",
                 password_confirmation: "DifferentPassword",
                 display_name: "Test User"
               })
               |> Ash.create()

      assert changeset.errors != []
    end

    test "fails with short password" do
      assert {:error, changeset} =
               User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: "test@example.com",
                 password: "short",
                 password_confirmation: "short",
                 display_name: "Test User"
               })
               |> Ash.create()

      assert changeset.errors != []
    end
  end

  describe "sign_in_with_password" do
    setup do
      user = generate(user_with_password(email: "test@example.com", password: "SuperSecret123!"))
      {:ok, user: user}
    end

    test "successfully signs in with correct password", %{user: _user} do
      assert {:ok, [result]} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: "test@example.com",
                 password: "SuperSecret123!"
               })
               |> Ash.read()

      assert result.__metadata__.token != nil
    end

    test "fails with incorrect password", %{user: _user} do
      assert {:error, _} =
               User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: "test@example.com",
                 password: "WrongPassword"
               })
               |> Ash.read()
    end
  end

  describe "set_password" do
    setup do
      # Create user without password using generator
      user = generate(user(email: "magicuser@example.com"))
      {:ok, user: user}
    end

    test "allows user to set initial password", %{user: user} do
      assert user.hashed_password == nil

      assert {:ok, updated_user} =
               user
               |> Ash.Changeset.for_update(
                 :set_password,
                 %{
                   password: "NewPassword123!",
                   password_confirmation: "NewPassword123!"
                 },
                 actor: user
               )
               |> Ash.update()

      assert updated_user.hashed_password != nil
    end
  end

  describe "change_password" do
    setup do
      user = generate(user_with_password(email: "test@example.com", password: "OldPassword123!"))
      {:ok, user: user}
    end

    test "successfully changes password with correct current password", %{user: user} do
      assert {:ok, updated_user} =
               user
               |> Ash.Changeset.for_update(
                 :change_password,
                 %{
                   current_password: "OldPassword123!",
                   password: "NewPassword123!",
                   password_confirmation: "NewPassword123!"
                 },
                 actor: user
               )
               |> Ash.update()

      assert updated_user.hashed_password != user.hashed_password
    end

    test "fails with incorrect current password", %{user: user} do
      assert {:error, changeset} =
               user
               |> Ash.Changeset.for_update(
                 :change_password,
                 %{
                   current_password: "WrongCurrentPassword",
                   password: "NewPassword123!",
                   password_confirmation: "NewPassword123!"
                 },
                 actor: user
               )
               |> Ash.update()

      assert changeset.errors != []
    end
  end

  describe "password reset flow" do
    setup do
      user = generate(user_with_password(email: "test@example.com", password: "OldPassword123!"))
      {:ok, user: user}
    end

    test "request password reset returns ok", %{user: _user} do
      assert :ok =
               User
               |> Ash.ActionInput.for_action(:request_password_reset_token, %{
                 email: "test@example.com"
               })
               |> Ash.run_action()
    end
  end
end
