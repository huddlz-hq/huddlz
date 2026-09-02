defmodule Huddlz.Repo.Migrations.BackfillLocationTimeZones do
  @moduledoc """
  Backfills legacy Florida data between Ash-generated schema migrations.

  Existing huddl timestamps were entered as Eastern wall-clock values while
  the application treated them as UTC. Reinterpret those values in Eastern
  time while preserving each huddl's duration.
  """

  use Ecto.Migration

  @eastern "America/New_York"

  def up do
    execute """
    UPDATE groups
    SET location = 'Saint Augustine, FL',
        latitude = COALESCE(latitude, 29.9012),
        longitude = COALESCE(longitude, -81.3124)
    WHERE location IS NULL OR btrim(location) = ''
    """

    execute "UPDATE groups SET time_zone = '#{@eastern}' WHERE time_zone IS NULL"
    execute "UPDATE group_locations SET time_zone = '#{@eastern}' WHERE time_zone IS NULL"

    execute """
    WITH original AS (
      SELECT id, starts_at, ends_at
      FROM huddlz
    )
    UPDATE huddlz AS h
    SET starts_at = (original.starts_at AT TIME ZONE '#{@eastern}') AT TIME ZONE 'UTC',
        ends_at = ((original.starts_at AT TIME ZONE '#{@eastern}') AT TIME ZONE 'UTC') +
          (original.ends_at - original.starts_at),
        time_zone = '#{@eastern}'
    FROM original
    WHERE h.id = original.id
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

    execute """
    UPDATE users
    SET home_time_zone = '#{@eastern}'
    WHERE home_location IS NOT NULL
    """
  end

  def down do
    execute """
    WITH shifted AS (
      SELECT id, starts_at, ends_at, time_zone
      FROM huddlz
    )
    UPDATE huddlz AS h
    SET starts_at = (shifted.starts_at AT TIME ZONE 'UTC') AT TIME ZONE shifted.time_zone,
        ends_at = ((shifted.starts_at AT TIME ZONE 'UTC') AT TIME ZONE shifted.time_zone) +
          (shifted.ends_at - shifted.starts_at)
    FROM shifted
    WHERE h.id = shifted.id
    """
  end
end
