defmodule Huddlz.Repo.Migrations.UpgradeObanV14 do
  use Ecto.Migration

  # Oban 2.21 adds the `suspended` job state (migration version 14)
  def up, do: Oban.Migration.up(version: 14)

  def down, do: Oban.Migration.down(version: 14)
end
