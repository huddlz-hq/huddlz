defmodule HuddlzWeb.WelcomeLiveTest do
  # POC variant E. The Cucumber scenarios cover where each choice lands. They
  # cannot observe the choice log line, which is the evidence this variant
  # exists to produce, so it is pinned here.
  # Not async: proving the choice is logged means raising the global logger
  # level, which other tests must not see.
  use HuddlzWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import Phoenix.LiveViewTest

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: previous_level) end)
    :ok
  end

  test "choosing to find a huddl logs the answer and records it", %{conn: conn} do
    user = generate(user(role: :user))
    conn = login(conn, user)

    log =
      capture_log([level: :info], fn ->
        {:ok, view, _html} = live(conn, ~p"/welcome")

        assert {:error, {:redirect, %{to: "/discover"}}} =
                 view |> element(~s(button[phx-value-choice="find_a_huddl"])) |> render_click()
      end)

    assert log =~ "post_sign_in_intent choice=find_a_huddl"
    assert log =~ "user_id=#{user.id}"

    assert Ash.get!(Huddlz.Accounts.User, user.id, authorize?: false).landing_choice ==
             :find_a_huddl
  end

  test "choosing own huddlz logs the answer and records it", %{conn: conn} do
    user = generate(user(role: :user))
    conn = login(conn, user)

    log =
      capture_log([level: :info], fn ->
        {:ok, view, _html} = live(conn, ~p"/welcome")

        assert {:error, {:redirect, %{to: "/agenda"}}} =
                 view |> element(~s(button[phx-value-choice="my_huddlz"])) |> render_click()
      end)

    assert log =~ "post_sign_in_intent choice=my_huddlz"

    assert Ash.get!(Huddlz.Accounts.User, user.id, authorize?: false).landing_choice ==
             :my_huddlz
  end

  test "someone who already answered is not asked again", %{conn: conn} do
    user = generate(user(role: :user))

    user
    |> Ash.Changeset.for_update(:update_landing_choice, %{landing_choice: :find_a_huddl},
      actor: user
    )
    |> Ash.update!()

    conn = login(conn, user)

    assert {:error, {:redirect, %{to: "/discover"}}} = live(conn, ~p"/welcome")
  end
end
