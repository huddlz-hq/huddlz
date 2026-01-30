defmodule Huddlz.Accounts.UserAddressTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts.UserAddress

  import Huddlz.Generator

  describe "UserAddress resource" do
    test "creates address for user" do
      user = generate(user())

      attrs = %{
        user_id: user.id,
        formatted_address: "123 Main St, San Francisco, CA 94102, USA",
        latitude: Decimal.new("37.7749295"),
        longitude: Decimal.new("-122.4194155"),
        city: "San Francisco",
        state: "CA",
        country: "US"
      }

      assert {:ok, address} =
               UserAddress
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)

      assert address.formatted_address == attrs.formatted_address
      assert address.city == "San Francisco"
      assert address.state == "CA"
      assert address.user_id == user.id
    end

    test "enforces one address per user" do
      user = generate(user())

      attrs = %{
        user_id: user.id,
        formatted_address: "123 Main St",
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194")
      }

      {:ok, _} =
        UserAddress
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create(authorize?: false)

      assert {:error, error} =
               UserAddress
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)

      assert Exception.message(error) =~ "User already has an address"
    end

    test "can update an address" do
      user = generate(user())

      {:ok, address} =
        UserAddress
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          formatted_address: "123 Main St",
          latitude: Decimal.new("37.7749"),
          longitude: Decimal.new("-122.4194")
        })
        |> Ash.create(authorize?: false)

      assert {:ok, updated} =
               address
               |> Ash.Changeset.for_update(:update, %{
                 formatted_address: "456 Oak Ave, New York, NY 10001",
                 city: "New York",
                 state: "NY"
               })
               |> Ash.update(authorize?: false)

      assert updated.formatted_address == "456 Oak Ave, New York, NY 10001"
      assert updated.city == "New York"
    end

    test "can get address for user" do
      user = generate(user())

      {:ok, created_address} =
        UserAddress
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          formatted_address: "123 Main St",
          latitude: Decimal.new("37.7749"),
          longitude: Decimal.new("-122.4194")
        })
        |> Ash.create(authorize?: false)

      assert {:ok, fetched_address} =
               Huddlz.Accounts.get_user_address(user.id, authorize?: false)

      assert fetched_address.id == created_address.id
    end

    test "returns error when user has no address" do
      user = generate(user())

      assert {:error, _} = Huddlz.Accounts.get_user_address(user.id, authorize?: false)
    end

    test "can delete an address" do
      user = generate(user())

      {:ok, address} =
        UserAddress
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          formatted_address: "123 Main St",
          latitude: Decimal.new("37.7749"),
          longitude: Decimal.new("-122.4194")
        })
        |> Ash.create(authorize?: false)

      assert :ok = Huddlz.Accounts.delete_user_address(address, authorize?: false)

      assert {:error, _} = Huddlz.Accounts.get_user_address(user.id, authorize?: false)
    end
  end
end
