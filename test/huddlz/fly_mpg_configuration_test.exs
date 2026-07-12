defmodule Huddlz.FlyMpgConfigurationTest do
  use ExUnit.Case, async: true

  test "uses transaction-pool-compatible Repo settings" do
    repo_config = Application.fetch_env!(:huddlz, Huddlz.Repo)

    assert repo_config[:prepare] == :unnamed
  end

  test "uses a notifier that does not require Postgres LISTEN/NOTIFY" do
    oban_config = Application.fetch_env!(:huddlz, Oban)

    assert oban_config[:notifier] == Oban.Notifiers.PG
  end
end
