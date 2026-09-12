defmodule Huddlz.Accounts.EmailChangeConcurrencyTest do
  use ExUnit.Case, async: false
  import Huddlz.Generator
  alias Ecto.Adapters.SQL.Sandbox
  alias Huddlz.Accounts
  alias Huddlz.Accounts.EmailChange
  alias Huddlz.Repo

  test "simultaneous inbox approvals complete the change exactly once" do
    Sandbox.unboxed_run(Repo, fn ->
      user = generate(user_with_password(password: "Password123!"))
      replacement = "concurrent-#{user.id}@example.com"
      cleanup([user], [replacement])
      {:ok, _} = Accounts.change_email(user, replacement, "Password123!", actor: user)
      Oban.drain_queue(queue: :notifications)
      tokens = [token(to_string(user.email)), token(replacement)]

      results = race(Enum.map(tokens, fn token -> fn -> EmailChange.approve(token) end end))
      assert Enum.count(results, &match?({:ok, _}, &1)) == 2
      assert Enum.count(results, &match?({:ok, %{pending_email_change: nil}}, &1)) == 1
      assert to_string(Accounts.get_user!(user.id).email) == replacement
      for token <- tokens, do: assert({:error, _} = EmailChange.approve(token))
    end)
  end

  test "competing completions cannot assign the same address to two accounts" do
    Sandbox.unboxed_run(Repo, fn ->
      users = Enum.map(1..2, fn _ -> generate(user_with_password(password: "Password123!")) end)
      replacement = "contested-#{Ash.UUID.generate()}@example.com"
      cleanup(users, [replacement])

      for user <- users do
        {:ok, _} = Accounts.change_email(user, replacement, "Password123!", actor: user)
      end

      Oban.drain_queue(queue: :notifications)
      for user <- users, do: assert({:ok, _} = EmailChange.approve(token(to_string(user.email))))
      tokens = [token(replacement), token(replacement)]
      results = race(Enum.map(tokens, fn token -> fn -> EmailChange.approve(token) end end))
      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, _}, &1)) == 1
      reloaded = Enum.map(users, &Accounts.get_user!(&1.id))
      assert Enum.count(reloaded, &(to_string(&1.email) == replacement)) == 1

      for user <- reloaded, to_string(user.email) != replacement do
        original = Enum.find(users, &(&1.id == user.id))
        assert user.email == original.email
      end
    end)
  end

  test "simultaneous resends consume one account allowance" do
    Sandbox.unboxed_run(Repo, fn ->
      user = generate(user_with_password(password: "Password123!"))
      replacement = "resend-race-#{user.id}@example.com"
      cleanup([user], [replacement])
      {:ok, pending} = Accounts.change_email(user, replacement, "Password123!", actor: user)

      resend = fn ->
        pending
        |> Ash.Changeset.for_update(
          :resend_email_change,
          %{request_id: pending.pending_email_change["id"]},
          actor: pending
        )
        |> Ash.update()
      end

      results = race([resend, resend])
      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, _}, &1)) == 1
    end)
  end

  defp token(recipient) do
    assert_receive {:email,
                    %Swoosh.Email{
                      subject: "Approve your huddlz email change",
                      to: [{"", ^recipient}]
                    } = email}

    [url] =
      email.html_body
      |> Floki.parse_document!()
      |> Floki.find("a")
      |> Enum.filter(&(Floki.text(&1) == "Review email change"))
      |> Floki.attribute("href")

    url |> URI.parse() |> Map.fetch!(:path) |> String.split("/") |> List.last()
  end

  defp race(functions) do
    parent = self()

    tasks =
      Enum.map(functions, fn fun ->
        Task.async(fn -> run_when_ready(parent, fun) end)
      end)

    connections =
      Enum.map(tasks, fn task ->
        pid = task.pid
        assert_receive {:ready, ^pid, connection_id}, 5_000
        connection_id
      end)

    assert length(Enum.uniq(connections)) == length(tasks)
    Enum.each(tasks, &send(&1.pid, :go))
    Task.await_many(tasks, 10_000)
  end

  defp run_when_ready(parent, fun) do
    Sandbox.unboxed_run(Repo, fn ->
      %{rows: [[connection_id]]} = Repo.query!("SELECT pg_backend_pid()")
      send(parent, {:ready, self(), connection_id})

      receive do
        :go -> fun.()
      after
        5_000 -> flunk("Start signal was not received")
      end
    end)
  end

  defp cleanup(users, replacements) do
    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        ids = Enum.map(users, & &1.id)
        emails = Enum.map(users, &to_string(&1.email)) ++ replacements

        Repo.query!(
          "DELETE FROM oban_jobs WHERE args->>'user_id' = ANY($1) OR args->>'to' = ANY($2)",
          [ids, emails]
        )

        Repo.query!("DELETE FROM tokens WHERE subject = ANY($1)", [
          Enum.map(ids, &("user?id=" <> &1))
        ])

        Repo.query!("DELETE FROM users WHERE id = ANY($1::uuid[])", [
          Enum.map(ids, &Ecto.UUID.dump!/1)
        ])
      end)
    end)
  end
end
