defmodule Huddlz.TimeZoneTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Huddlz.Accounts
  alias Huddlz.TimeZone

  describe "Calendar time-zone preference" do
    test "an invalid browser identifier falls back without being persisted" do
      user = generate(user(role: :user))

      assert TimeZone.display(user, "invalid/browser-zone") == "America/New_York"
      assert TimeZone.display(nil, "invalid/browser-zone") == "America/New_York"

      reloaded = Ash.reload!(user)
      assert reloaded.display_time_zone_mode == :automatic
      assert is_nil(reloaded.fixed_display_time_zone)
    end

    test "Fixed mode rejects an invalid IANA identifier through Accounts" do
      user = generate(user(role: :user))

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.update_display_time_zone(
                 user,
                 :fixed,
                 "invalid/fixed-zone",
                 actor: user
               )

      reloaded = Ash.reload!(user)
      assert reloaded.display_time_zone_mode == :automatic
      assert is_nil(reloaded.fixed_display_time_zone)
    end

    test "the account rejects aliases and raw offsets in either mode" do
      user = generate(user(role: :user))

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.update_display_time_zone(user, :automatic, "EST", actor: user)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.update_display_time_zone(user, :fixed, "+05:00", actor: user)

      reloaded = Ash.reload!(user)
      assert reloaded.display_time_zone_mode == :automatic
      assert is_nil(reloaded.fixed_display_time_zone)
    end

    test "Automatic mode retains the prior Fixed identifier" do
      user = generate(user(role: :user))

      fixed =
        Accounts.update_display_time_zone!(user, :fixed, "America/Denver", actor: user)

      automatic =
        Accounts.update_display_time_zone!(
          fixed,
          :automatic,
          fixed.fixed_display_time_zone,
          actor: fixed
        )

      assert automatic.display_time_zone_mode == :automatic
      assert automatic.fixed_display_time_zone == "America/Denver"
      assert TimeZone.display(automatic, "America/Los_Angeles") == "America/Los_Angeles"
    end
  end
end
