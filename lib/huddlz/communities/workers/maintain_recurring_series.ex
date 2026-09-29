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
    case RecurrenceHelper.series_source(template) do
      # Nothing left to copy from, so nothing to generate and nothing to
      # guard.
      {:error, :no_source} -> :ok
      {:ok, source} -> fill_unless_archived(template, job, source)
    end
  rescue
    exception ->
      notify_organizer_after_final_failure(job, template)
      reraise exception, __STACKTRACE__
  end

  defp fill_unless_archived(template, job, source) do
    if archived_group?(source) do
      :ok
    else
      generate(template, job)
    end
  end

  defp generate(template, job) do
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

  # The owning group can be archived after the series was created. This is
  # the single path through which occurrences are created, so the guard lives
  # here rather than in HuddlTemplate's :due_for_maintenance filter, which
  # would have to traverse `huddlz` — and its default read action applies
  # FilterByVisibility, silently excluding every private group's series when
  # this runs with no actor.
  #
  # The huddl to check is resolved through `RecurrenceHelper.series_source/1`
  # — the same resolution `fill_window/2` uses, fallback included — rather
  # than duplicated here. A template whose `source_huddl_id` has been
  # nilified by a hard delete still falls back to the series' latest
  # occurrence there, and this guard must see the same huddl `fill_window/2`
  # is about to generate from, or an archived group's series could keep
  # growing through exactly that gap. Reaching the group through the source
  # huddl's :get_for_recurrence read keeps this visibility-free.
  defp archived_group?(%Huddl{id: source_id}) do
    Huddl
    |> Ash.Query.for_read(:get_for_recurrence, %{id: source_id})
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

  # Resolved the same way `fill_window/2` resolves the huddl it generates
  # from: through `RecurrenceHelper.series_source/1`, so a hard-deleted
  # source still falls back to the series' latest occurrence instead of
  # losing its failure notifications.
  defp source_for_notification(template) do
    case RecurrenceHelper.series_source(template) do
      {:ok, %Huddl{} = huddl} -> Ash.load(huddl, [:creator, :group], authorize?: false)
      {:error, :no_source} -> :error
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
