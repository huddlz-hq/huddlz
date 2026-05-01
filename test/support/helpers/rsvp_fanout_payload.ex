defmodule Huddlz.Test.Helpers.RsvpFanoutPayload do
  @moduledoc """
  Shared payload builder for the RSVP fanout sender tests
  (`RsvpReceivedTest`, `RsvpCancelledTest`). Both senders consume the
  same shape of payload built by `NotifyRsvpReceived` /
  `NotifyRsvpCancelled`; centralizing the fixture here keeps the two
  test files focused on the behavioral differences (subject string,
  fallback text).
  """

  @defaults %{
    "huddl_id" => "00000000-0000-0000-0000-000000000001",
    "huddl_title" => "Saturday Soccer",
    "group_name" => "Pickup Sports",
    "group_slug" => "pickup-sports",
    "rsvper_display_name" => "Trinity"
  }

  @doc "Returns a complete payload, with `overrides` merged on top."
  @spec payload(map()) :: map()
  def payload(overrides \\ %{}), do: Map.merge(@defaults, overrides)
end
