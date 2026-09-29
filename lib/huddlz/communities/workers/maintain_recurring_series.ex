defmodule Huddlz.Communities.Workers.MaintainRecurringSeries do
  @moduledoc """
  Keeps one recurring series' rolling window of occurrences filled.

  Enqueued when a recurring huddl is created, and once a day per active series
  by `SweepRecurringSeries`. Keyed on the template rather than a huddl, because
  the template is the series.

  Idempotent: generation matches on calendar date, so a retry, or a cron run
  overlapping a create, produces nothing twice. The Oban uniqueness window
  keeps the duplicate from being enqueued in the first place.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 300, keys: [:huddl_template_id]]

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Notifications

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"huddl_template_id" => template_id}} = job) do
    case Ash.get(HuddlTemplate, template_id, authorize?: false) do
      {:ok, %HuddlTemplate{} = template} -> fill(template, job)
      # The series was deleted before the job ran. Nothing to maintain.
      {:error, _reason} -> :ok
    end
  end

  defp fill(template, job) do
    if archived_group?(template) do
      :ok
    else
      case RecurrenceHelper.fill_window(template) do
        :ok ->
          :ok

        # The series has no huddl left to copy details from. Not a failure.
        {:error, :no_source} ->
          :ok

        {:error, reason} ->
          notify_organizer_after_final_failure(%{job | attempt: job.max_attempts}, template)
          {:cancel, reason}
      end
    end
  rescue
    exception ->
      notify_organizer_after_final_failure(job, template)
      reraise exception, __STACKTRACE__
  end

  # The owning group can be archived after the series was created. This is
  # the single path through which occurrences are created, so the guard lives
  # here rather than in HuddlTemplate's :due_for_maintenance filter, which
  # would have to traverse `huddlz` — and its default read action applies
  # FilterByVisibility, silently excluding every private group's series when
  # this runs with no actor. Reaching the group through the source huddl's
  # :get_for_recurrence read keeps this visibility-free instead.
  defp archived_group?(%HuddlTemplate{source_huddl_id: nil}), do: false

  defp archived_group?(%HuddlTemplate{source_huddl_id: source_huddl_id}) do
    Huddl
    |> Ash.Query.for_read(:get_for_recurrence, %{id: source_huddl_id})
    |> Ash.Query.load(:group)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Huddl{group: %{archived_at: archived_at}}} -> not is_nil(archived_at)
      _other -> false
    end
  end

  defp notify_organizer_after_final_failure(
         %Oban.Job{attempt: attempt, max_attempts: max_attempts},
         template
       )
       when attempt >= max_attempts do
    with {:ok, %Huddl{} = huddl} <- source_for_notification(template),
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
          "Failed to notify organizer about recurring huddl generation failure for series " <>
            "#{template.id}: #{inspect(reason)}"
        )
    end
  rescue
    notification_exception ->
      Logger.error(
        "Failed to notify organizer about recurring huddl generation failure for series " <>
          "#{template.id}: #{Exception.message(notification_exception)}"
      )
  end

  defp notify_organizer_after_final_failure(_job, _template), do: :ok

  defp source_for_notification(%HuddlTemplate{source_huddl_id: nil}), do: :error

  defp source_for_notification(%HuddlTemplate{source_huddl_id: source_huddl_id}) do
    Huddl
    |> Ash.Query.for_read(:get_for_recurrence, %{id: source_huddl_id})
    |> Ash.Query.load([:creator, :group])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Huddl{} = huddl} -> {:ok, huddl}
      _other -> :error
    end
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
