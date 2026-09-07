defmodule Huddlz.Repo.Migrations.TrackSitemapContentChanges do
  use Ecto.Migration

  def up do
    alter table(:huddlz) do
      add :sitemap_modified_at, :utc_datetime_usec
    end

    # Preserve the best historical timestamp available. Going forward, reminder
    # bookkeeping and no-op writes do not advance the content clock.
    execute "UPDATE huddlz SET sitemap_modified_at = updated_at"

    execute """
    CREATE FUNCTION track_huddl_sitemap_content() RETURNS trigger AS $$
    BEGIN
      IF TG_OP = 'INSERT' THEN
        NEW.sitemap_modified_at := NEW.updated_at;
      ELSIF (to_jsonb(NEW) - ARRAY['updated_at', 'sitemap_modified_at', 'group_location_id',
                'reminder_24h_sent_at', 'reminder_1h_sent_at'])
         IS DISTINCT FROM
            (to_jsonb(OLD) - ARRAY['updated_at', 'sitemap_modified_at', 'group_location_id',
                'reminder_24h_sent_at', 'reminder_1h_sent_at']) THEN
        NEW.sitemap_modified_at := NEW.updated_at;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER huddl_sitemap_content BEFORE INSERT OR UPDATE ON huddlz
    FOR EACH ROW EXECUTE FUNCTION track_huddl_sitemap_content()
    """
  end

  def down do
    execute "DROP TRIGGER huddl_sitemap_content ON huddlz"
    execute "DROP FUNCTION track_huddl_sitemap_content()"

    alter table(:huddlz) do
      remove :sitemap_modified_at
    end
  end
end
