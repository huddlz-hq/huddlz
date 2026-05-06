# Production-essential seeds, run in every environment that boots the app.
#
#     mix run priv/repo/seeds.exs
#
# This file is for things the application *needs* to function — default
# roles, lookup tables, baseline configuration records — anything that
# would belong in a database migration if Ash didn't provide a cleaner
# place to express it.
#
# Dev-only sample data (fixed users like `alice@example.com`, sample
# groups, sample huddlz) lives in `priv/repo/dev_seeds.exs` and is run
# by the `mix setup` / `mix ecto.setup` aliases. Keep them separate so
# this file stays safe to run in test/staging/prod.
#
# Currently empty — there are no production-essential records to seed.
