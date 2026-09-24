defmodule HuddlzWeb.ProfileLive.ApiKeysTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Accounts.ApiKey
  alias Huddlz.Test.Helpers.Authentication

  test "a key made before creation dates were recorded shows no created date", %{conn: conn} do
    user = generate(user())

    key =
      ApiKey
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Old script", expires_at: DateTime.add(DateTime.utc_now(), 30 * 86_400)},
        actor: user
      )
      |> Ash.create!()

    Ash.Seed.update!(key, %{inserted_at: nil})

    conn
    |> Authentication.login(user)
    |> visit("/profile/api-keys")
    |> assert_has("#api-key-#{key.id}", text: "Old script")
    |> assert_has("#api-key-#{key.id}", text: "Expires")
    |> refute_has("#api-key-#{key.id}", text: "Created")
  end
end
