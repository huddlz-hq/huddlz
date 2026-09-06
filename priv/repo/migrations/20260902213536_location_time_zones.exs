defmodule Huddlz.Repo.Migrations.LocationTimeZones do
  @moduledoc """
  Adds location-derived time zones and backfills legacy Florida data.

  Generated with `mix ash_postgres.generate_migrations`, then edited so the
  new columns are added nullable, backfilled, and only then made required.
  Existing huddl timestamps were entered as Eastern wall-clock values while
  the application treated them as UTC; they are reinterpreted in Eastern time
  with each huddl's duration preserved.
  """

  use Ecto.Migration

  @eastern "America/New_York"

  def up do
    alter table(:group_locations) do
      add :time_zone, :text
    end

    alter table(:groups) do
      add :time_zone, :text
    end

    alter table(:huddl_templates) do
      add :starts_at_local, :naive_datetime
      add :ends_at_local, :naive_datetime
      add :time_zone, :text
    end

    alter table(:huddlz) do
      add :time_zone, :text
    end

    alter table(:users) do
      add :home_time_zone, :text
    end

    execute "UPDATE groups SET time_zone = '#{@eastern}'"
    execute "UPDATE group_locations SET time_zone = '#{@eastern}'"
    execute "UPDATE users SET home_time_zone = '#{@eastern}' WHERE home_location IS NOT NULL"

    execute """
    UPDATE huddlz
    SET starts_at = (starts_at AT TIME ZONE '#{@eastern}') AT TIME ZONE 'UTC',
        ends_at = ((starts_at AT TIME ZONE '#{@eastern}') AT TIME ZONE 'UTC') + (ends_at - starts_at),
        time_zone = '#{@eastern}'
    """

    execute """
    UPDATE huddl_templates AS templates
    SET starts_at_local = (source.starts_at AT TIME ZONE 'UTC') AT TIME ZONE '#{@eastern}',
        ends_at_local = (source.ends_at AT TIME ZONE 'UTC') AT TIME ZONE '#{@eastern}',
        time_zone = '#{@eastern}'
    FROM huddlz AS source
    WHERE source.id = (
      SELECT candidate.id
      FROM huddlz AS candidate
      WHERE candidate.huddl_template_id = templates.id
      ORDER BY candidate.starts_at ASC
      LIMIT 1
    )
    """

    alter table(:group_locations) do
      modify :time_zone, :text, null: false
    end

    alter table(:groups) do
      modify :time_zone, :text, null: false
      modify :location, :text, null: false
      modify :latitude, :float, null: false
      modify :longitude, :float, null: false
    end

    alter table(:huddl_templates) do
      modify :starts_at_local, :naive_datetime, null: false
      modify :ends_at_local, :naive_datetime, null: false
      modify :time_zone, :text, null: false
    end

    alter table(:huddlz) do
      modify :time_zone, :text, null: false
    end
  end

  def down do
    execute """
    UPDATE huddlz
    SET starts_at = (starts_at AT TIME ZONE 'UTC') AT TIME ZONE time_zone,
        ends_at = ((starts_at AT TIME ZONE 'UTC') AT TIME ZONE time_zone) + (ends_at - starts_at)
    """

    alter table(:users) do
      remove :home_time_zone
    end

    alter table(:huddlz) do
      remove :time_zone
    end

    alter table(:huddl_templates) do
      remove :time_zone
      remove :ends_at_local
      remove :starts_at_local
    end

    alter table(:groups) do
      modify :longitude, :float, null: true
      modify :latitude, :float, null: true
      modify :location, :text, null: true
      remove :time_zone
    end

    alter table(:group_locations) do
      remove :time_zone
    end
  end
end
