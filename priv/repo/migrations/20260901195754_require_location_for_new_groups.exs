defmodule Huddlz.Repo.Migrations.RequireLocationForNewGroups do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE groups
    ADD CONSTRAINT groups_location_required_for_new_records
    CHECK (location IS NOT NULL AND btrim(location) <> '') NOT VALID
    """
  end

  def down do
    execute """
    ALTER TABLE groups
    DROP CONSTRAINT groups_location_required_for_new_records
    """
  end
end
