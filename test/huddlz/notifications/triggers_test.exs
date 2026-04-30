defmodule Huddlz.Notifications.TriggersTest do
  use ExUnit.Case, async: true

  alias Huddlz.Notifications.Triggers

  describe "all/0" do
    test "every entry has the required fields" do
      for {atom, entry} <- Triggers.all() do
        assert is_atom(atom)
        assert entry.category in [:transactional, :activity, :digest]
        assert is_atom(entry.sender)
        assert is_boolean(entry.default)
        assert is_binary(entry.label) and entry.label != ""
      end
    end

    test "covers the spec triggers" do
      keys = Triggers.all() |> Map.keys() |> MapSet.new()

      expected =
        MapSet.new([
          :password_changed,
          :email_changed,
          :account_role_changed,
          :group_member_joined,
          :group_member_added,
          :group_member_removed,
          :group_role_changed,
          :group_archived,
          :group_ownership_transferred,
          :huddl_new,
          :huddl_updated,
          :huddl_cancelled,
          :huddl_series_updated,
          :huddl_reminder_24h,
          :huddl_reminder_1h,
          :rsvp_received,
          :rsvp_cancelled,
          :rsvp_confirmation,
          :weekly_digest,
          :reactivation_nudge
        ])

      missing = MapSet.difference(expected, keys)
      assert MapSet.size(missing) == 0, "registry is missing: #{inspect(missing)}"
    end

    test "digest triggers default off, others default on" do
      for {_atom, entry} <- Triggers.all() do
        case entry.category do
          :digest -> assert entry.default == false
          _ -> assert entry.default == true
        end
      end
    end
  end

  describe "fetch/1" do
    test "returns {:ok, entry} for a known trigger" do
      assert {:ok, %{category: :transactional}} = Triggers.fetch(:password_changed)
    end

    test "returns :error for an unknown trigger" do
      assert :error == Triggers.fetch(:does_not_exist)
    end
  end

  describe "fetch!/1" do
    test "raises for an unknown trigger" do
      assert_raise KeyError, fn -> Triggers.fetch!(:does_not_exist) end
    end
  end

  describe "by_category/1" do
    test "filters to transactional entries only" do
      result = Triggers.by_category(:transactional)
      assert Map.has_key?(result, :password_changed)
      refute Map.has_key?(result, :rsvp_received)
      assert Enum.all?(result, fn {_, e} -> e.category == :transactional end)
    end

    test "returns activity-only entries" do
      result = Triggers.by_category(:activity)
      assert Enum.all?(result, fn {_, e} -> e.category == :activity end)
    end

    test "returns digest-only entries" do
      result = Triggers.by_category(:digest)
      assert Enum.all?(result, fn {_, e} -> e.category == :digest end)
      assert Map.has_key?(result, :weekly_digest)
    end
  end

  describe "preference_key/1" do
    test "returns the string form of an atom" do
      assert Triggers.preference_key(:password_changed) == "password_changed"
      assert Triggers.preference_key(:huddl_reminder_24h) == "huddl_reminder_24h"
    end
  end
end
