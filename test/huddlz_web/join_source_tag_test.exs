defmodule HuddlzWeb.JoinSourceTagTest do
  use HuddlzWeb.ConnCase, async: true

  alias HuddlzWeb.JoinSourceTag

  describe "a tagged group page address" do
    test "is redirected to the clean address, keeping its other parameters", %{conn: conn} do
      conn = get(conn, "/groups/tuesday-runners?tab=past&from=join_suggestion_email")

      assert redirected_to(conn) == "/groups/tuesday-runners?tab=past"

      assert JoinSourceTag.source_for(get_session(conn), "tuesday-runners") ==
               :join_suggestion_email
    end

    test "drops a tag huddlz does not recognise", %{conn: conn} do
      conn = get(conn, "/groups/tuesday-runners?from=a_billboard")

      assert redirected_to(conn) == "/groups/tuesday-runners"
      refute JoinSourceTag.source_for(get_session(conn), "tuesday-runners")
    end
  end

  describe "source_for/3" do
    setup %{conn: conn} do
      conn = get(conn, "/groups/tuesday-runners?from=rsvp_confirmation_email")
      %{session: get_session(conn)}
    end

    test "counts for page loads within half an hour of arriving", %{session: session} do
      soon = DateTime.add(DateTime.utc_now(), 29, :minute)
      later = DateTime.add(DateTime.utc_now(), 31, :minute)

      assert JoinSourceTag.source_for(session, "tuesday-runners", soon) ==
               :rsvp_confirmation_email

      refute JoinSourceTag.source_for(session, "tuesday-runners", later)
    end

    test "is for the group the link led to, and no other", %{session: session} do
      refute JoinSourceTag.source_for(session, "thursday-walkers")
    end

    test "is nil when nothing was remembered" do
      refute JoinSourceTag.source_for(%{}, "tuesday-runners")
    end
  end
end
