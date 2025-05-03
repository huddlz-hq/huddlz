defmodule Huddlz.Repo do
  use Ecto.Repo,
    otp_app: :huddlz,
    adapter: Ecto.Adapters.Postgres
end
