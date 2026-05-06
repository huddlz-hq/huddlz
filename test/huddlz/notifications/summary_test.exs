defmodule Huddlz.Notifications.SummaryTest do
  use ExUnit.Case, async: true

  alias Huddlz.Notifications.Summary
  alias Huddlz.Notifications.Triggers

  describe "summarize/2" do
    test "every registered trigger returns a non-nil title" do
      for trigger <- Map.keys(Triggers.all()) do
        result = Summary.summarize(trigger, %{})
        assert is_binary(result.title), "trigger #{trigger} produced a nil/non-binary title"
        assert result.title != "", "trigger #{trigger} produced an empty title"
      end
    end

    test "RSVP confirmation uses tense-agnostic phrasing" do
      result = Summary.summarize(:rsvp_confirmation, %{"huddl_title" => "Boat Drinks"})
      assert result.title == "RSVP confirmed: Boat Drinks"
    end

    test "Reminder titles avoid time-relative wording" do
      r24 = Summary.summarize(:huddl_reminder_24h, %{"huddl_title" => "Boat Drinks"})
      r1 = Summary.summarize(:huddl_reminder_1h, %{"huddl_title" => "Boat Drinks"})

      assert r24.title == "Reminder: Boat Drinks (24h)"
      assert r1.title == "Reminder: Boat Drinks (1h)"
    end

    test "description uses absolute date when starts_at_iso is present" do
      result =
        Summary.summarize(:huddl_new, %{
          "huddl_title" => "Friday Coffee",
          "group_name" => "Founder Coffee",
          "starts_at_iso" => "2026-05-10T09:00:00Z"
        })

      assert result.description == "Starts May 10, 2026"
    end

    test "description is nil when no date is present" do
      result = Summary.summarize(:rsvp_confirmation, %{"huddl_title" => "Boat Drinks"})
      assert is_nil(result.description)
    end

    test "source_url builds a huddl path when group_slug + huddl_id are present" do
      result =
        Summary.summarize(:rsvp_confirmation, %{
          "huddl_id" => "abc",
          "group_slug" => "phoenix-elixir-meetup"
        })

      assert result.source_url == "/groups/phoenix-elixir-meetup/huddlz/abc"
    end

    test "source_url falls back to a group page when only group_slug is present" do
      result = Summary.summarize(:group_member_joined, %{"group_slug" => "founder-coffee"})
      assert result.source_url == "/groups/founder-coffee"
    end

    test "source_url is /profile for account-level triggers" do
      assert Summary.summarize(:password_changed, %{}).source_url == "/profile"
      assert Summary.summarize(:email_changed, %{}).source_url == "/profile"
      assert Summary.summarize(:account_role_changed, %{}).source_url == "/profile"
    end

    test "source_url is nil when no payload keys match" do
      assert Summary.summarize(:huddl_new, %{}).source_url == nil
    end
  end
end
