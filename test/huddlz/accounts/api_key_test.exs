defmodule Huddlz.Accounts.ApiKeyTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts.{ApiKey, User}

  describe "ApiKey :create action" do
    test "generates a plaintext key with the huddlz prefix and persists a hash" do
      user = generate(user())

      {:ok, record} =
        ApiKey
        |> Ash.Changeset.for_create(
          :create,
          %{expires_at: in_days(7)},
          actor: user
        )
        |> Ash.create()

      plaintext = record.__metadata__.plaintext_api_key

      assert is_binary(plaintext)
      assert String.starts_with?(plaintext, "huddlz_")
      assert is_binary(record.api_key_hash)
      assert record.user_id == user.id
    end
  end

  describe ":valid calculation" do
    test "is true while expires_at is in the future, false once it passes" do
      user = generate(user())

      future = build_key!(user, in_days(7))
      past = build_key!(user, in_days(-1))

      assert load_valid(future).valid
      refute load_valid(past).valid
    end
  end

  describe "User.sign_in_with_api_key" do
    test "returns the user when given a valid plaintext key" do
      user = generate(user())
      plaintext = build_key!(user, in_days(7)).__metadata__.plaintext_api_key

      assert {:ok, returned} =
               User
               |> Ash.Query.for_read(:sign_in_with_api_key, %{api_key: plaintext})
               |> Ash.read_one()

      assert returned.id == user.id
    end

    test "fails for a malformed key" do
      result =
        User
        |> Ash.Query.for_read(:sign_in_with_api_key, %{api_key: "huddlz_not-a-real-key"})
        |> Ash.read_one()

      refute match?({:ok, %User{}}, result)
    end

    test "fails when the key is expired" do
      user = generate(user())
      plaintext = build_key!(user, in_days(-1)).__metadata__.plaintext_api_key

      result =
        User
        |> Ash.Query.for_read(:sign_in_with_api_key, %{api_key: plaintext})
        |> Ash.read_one()

      refute match?({:ok, %User{}}, result)
    end
  end

  defp build_key!(user, expires_at) do
    ApiKey
    |> Ash.Changeset.for_create(
      :create,
      %{expires_at: expires_at},
      actor: user
    )
    |> Ash.create!()
  end

  defp load_valid(record) do
    record |> Ash.load!([:valid], authorize?: false)
  end

  defp in_days(days) do
    DateTime.utc_now() |> DateTime.add(days * 24 * 3600, :second)
  end
end
