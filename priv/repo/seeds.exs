# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Huddlz.Repo.insert!(%Huddlz.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Load the seed files
Code.require_file("seeds/communities/sample_huddlz.exs", __DIR__)
