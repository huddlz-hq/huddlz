defmodule Huddlz.Communities.Workers.RegenerateRecurringSeries do
  @moduledoc """
  Generates the future instances of a recurring huddl series off the request
  path. Enqueued when a recurring huddl is created. Idempotent: a retry clears
  and rebuilds the future instances rather than duplicating them, so a partial
  failure mid-generation is safe to retry.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Notifications

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"huddl_id" => huddl_id}} = job) do
    huddl =
      Huddl
      |> Ash.Query.for_read(:get_for_recurrence, %{id: huddl_id})
      |> Ash.Query.load(:huddl_template)
      |> Ash.read_one!(authorize?: false)

    result =
      case huddl do
        %Huddl{huddl_template: %HuddlTemplate{} = template} ->
          RecurrenceHelper.regenerate_series(huddl, template)

        _ ->
          # The huddl was deleted before the job ran, or it isn't part of a
          # series — nothing to generate.
          :ok
      end

    case result do
      :ok ->
        :ok

      {:error, reason} ->
        notify_organizer_after_final_failure(%{job | attempt: job.max_attempts}, huddl_id)
        {:cancel, reason}
    end
  rescue
    exception ->
      notify_organizer_after_final_failure(job, huddl_id)
      reraise exception, __STACKTRACE__
  end

  defp notify_organizer_after_final_failure(
         %Oban.Job{attempt: attempt, max_attempts: max_attempts},
         huddl_id
       )
       when attempt >= max_attempts do
    with {:ok, %Huddl{} = huddl} <- get_huddl_for_failure_notification(huddl_id),
         {:ok, _job} <-
           Notifications.deliver(
             huddl.creator,
             :recurring_huddl_generation_failed,
             failure_payload(huddl)
           ) do
      :ok
    else
      reason ->
        Logger.error(
          "Failed to notify organizer about recurring huddl generation failure for " <>
            "#{huddl_id}: #{inspect(reason)}"
        )
    end
  rescue
    notification_exception ->
      Logger.error(
        "Failed to notify organizer about recurring huddl generation failure for " <>
          "#{huddl_id}: #{Exception.message(notification_exception)}"
      )
  end

  defp notify_organizer_after_final_failure(_job, _huddl_id), do: :ok

  defp get_huddl_for_failure_notification(huddl_id) do
    Huddl
    |> Ash.Query.for_read(:get_for_recurrence, %{id: huddl_id})
    |> Ash.Query.load([:creator, :group])
    |> Ash.read_one(authorize?: false)
  end

  defp failure_payload(huddl) do
    %{
      "huddl_id" => huddl.id,
      "huddl_title" => huddl.title,
      "group_name" => huddl.group.name,
      "group_slug" => huddl.group.slug
    }
  end
end
