defmodule Huddlz.Repo.Migrations.TrackSitemapArtworkChanges do
  use Ecto.Migration

  def up do
    alter table(:groups) do
      add :sitemap_modified_at, :utc_datetime_usec
    end

    execute """
    CREATE FUNCTION track_sitemap_artwork() RETURNS trigger AS $$
    DECLARE parent_id uuid;
    BEGIN
      IF TG_OP = 'DELETE' AND OLD.deleted_at IS NOT NULL THEN
        RETURN NULL;
      END IF;
      FOR parent_id IN
        SELECT DISTINCT id FROM unnest(ARRAY[
          (to_jsonb(OLD)->>TG_ARGV[1])::uuid,
          (to_jsonb(NEW)->>TG_ARGV[1])::uuid
        ]) AS ids(id) WHERE id IS NOT NULL
      LOOP
        EXECUTE format('UPDATE %I SET sitemap_modified_at = clock_timestamp() WHERE id = $1', TG_ARGV[0])
        USING parent_id;
      END LOOP;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER group_sitemap_artwork AFTER INSERT OR UPDATE OR DELETE ON group_images
    FOR EACH ROW EXECUTE FUNCTION track_sitemap_artwork('groups', 'group_id')
    """

    execute """
    CREATE TRIGGER huddl_sitemap_artwork AFTER INSERT OR UPDATE OR DELETE ON huddl_cover_images
    FOR EACH ROW EXECUTE FUNCTION track_sitemap_artwork('huddlz', 'huddl_id')
    """

    execute """
    UPDATE groups g SET sitemap_modified_at = (
      SELECT max(greatest(i.inserted_at, i.deleted_at)) FROM group_images i WHERE i.group_id = g.id
    )
    """

    execute """
    UPDATE huddlz h SET sitemap_modified_at = greatest(h.sitemap_modified_at, (
      SELECT max(greatest(i.inserted_at, i.deleted_at)) FROM huddl_cover_images i WHERE i.huddl_id = h.id
    ))
    """
  end

  def down do
    execute "DROP TRIGGER group_sitemap_artwork ON group_images"
    execute "DROP TRIGGER huddl_sitemap_artwork ON huddl_cover_images"
    execute "DROP FUNCTION track_sitemap_artwork()"

    alter table(:groups) do
      remove :sitemap_modified_at
    end
  end
end
