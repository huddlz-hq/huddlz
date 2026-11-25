defmodule Huddlz.Accounts.ApiKey.Expiry do
  @moduledoc "Expiry bounds for new account API keys."

  @max_days 365

  def latest, do: in_days(@max_days)

  def from_days(days) when days in 1..@max_days, do: {:ok, in_days(days)}

  def from_days(days) when is_integer(days),
    do: {:error, "must be between 1 and #{@max_days} days"}

  def from_days(value) when is_binary(value) do
    case Integer.parse(value) do
      {days, ""} -> from_days(days)
      _ -> {:error, "must be an integer"}
    end
  end

  def from_days(_value), do: {:error, "must be an integer"}

  defp in_days(days), do: DateTime.add(DateTime.utc_now(), days, :day)
end
