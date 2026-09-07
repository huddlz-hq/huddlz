defmodule Huddlz.Repo.Migrations.AddSitemapDocuments do
  use Ecto.Migration

  def change do
    create table(:sitemap_documents, primary_key: false) do
      add :name, :text, primary_key: true
      add :body, :text, null: false
      add :active, :boolean, null: false, default: false
      add :retained_at, :utc_datetime_usec, null: false
    end

    create index(:sitemap_documents, [:retained_at])
  end
end
