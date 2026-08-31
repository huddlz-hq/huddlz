defmodule Huddlz.TimeZone do
  @moduledoc """
  Validates IANA time-zone names received from trusted browser APIs or clients.
  """

  @reference_datetime ~U[2000-01-01 00:00:00Z]
  @display_fallback "America/New_York"

  alias Huddlz.Accounts

  def valid?(time_zone) when is_binary(time_zone) do
    match?({:ok, _datetime}, DateTime.shift_zone(@reference_datetime, time_zone))
  end

  def valid?(_time_zone), do: false

  def canonical?(time_zone) when is_binary(time_zone) do
    time_zone in Tzdata.canonical_zone_list()
  end

  def canonical?(_time_zone), do: false

  def from_connect_params(%{"timezone" => time_zone}) do
    if valid?(time_zone), do: time_zone
  end

  def from_connect_params(_params), do: nil

  @doc """
  Resolves a signed-in person's effective Display time zone.

  Fixed mode uses the persisted IANA identifier. Automatic mode uses the
  browser, then the saved home Location zone when that field is available,
  and finally the Florida-friendly Eastern fallback.
  """
  def display(user, browser_time_zone)

  def display(%{display_time_zone_mode: :fixed, fixed_display_time_zone: time_zone}, _browser) do
    valid_or_display_fallback(time_zone)
  end

  def display(nil, browser_time_zone), do: valid_or_display_fallback(browser_time_zone)

  def display(user, browser_time_zone) do
    [browser_time_zone, Map.get(user, :home_time_zone), @display_fallback]
    |> Enum.find(&valid?/1)
  end

  def valid_or_display_fallback(time_zone) do
    if valid?(time_zone), do: time_zone, else: @display_fallback
  end

  def preference_selection(%{
        display_time_zone_mode: :fixed,
        fixed_display_time_zone: time_zone
      }),
      do: time_zone

  def preference_selection(_user), do: "automatic"

  def preference_update("automatic", user),
    do: {:ok, :automatic, Map.get(user, :fixed_display_time_zone)}

  def preference_update(time_zone, _user) do
    if canonical?(time_zone), do: {:ok, :fixed, time_zone}, else: {:error, :invalid_time_zone}
  end

  def update_preference(user, selection) do
    with {:ok, mode, fixed_time_zone} <- preference_update(selection, user),
         {:ok, updated_user} <-
           Accounts.update_display_time_zone(user, mode, fixed_time_zone, actor: user) do
      {:ok, retain_loaded_preference(user, updated_user)}
    else
      {:error, :invalid_time_zone} -> {:error, :invalid_time_zone}
      {:error, _reason} -> {:error, :update_failed}
    end
  end

  def preference_error_message(:invalid_time_zone), do: "Choose a valid IANA time zone"
  def preference_error_message(:update_failed), do: "Display time zone could not be updated"

  defp retain_loaded_preference(current_user, updated_user) do
    %{
      current_user
      | display_time_zone_mode: updated_user.display_time_zone_mode,
        fixed_display_time_zone: updated_user.fixed_display_time_zone
    }
  end

  def options do
    [{"Automatic (browser time zone)", "automatic"} | Tzdata.canonical_zone_list()]
  end

  def valid_or_utc(time_zone) do
    if valid?(time_zone), do: time_zone, else: "Etc/UTC"
  end
end
