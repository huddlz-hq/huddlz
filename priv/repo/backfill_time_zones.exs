# One-time data backfill: assigns a best-effort `time_zone` to every
# Group/Huddl row still at the resource default ("Etc/UTC"), geo-deriving
# from existing coordinates where possible. See `Huddlz.BackfillTimeZones`
# for the full behavior. Run once, after this feature deploys:
#
#     mix run priv/repo/backfill_time_zones.exs
#
# Not wired into `mix setup`/`mix ecto.setup` — a fresh database has no
# legacy ungeocoded rows to fix. Safe to re-run.

Huddlz.BackfillTimeZones.run()
