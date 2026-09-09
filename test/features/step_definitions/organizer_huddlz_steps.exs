defmodule OrganizerHuddlzSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  step "the huddl {string} exists in group {string} with room for {int} and {int} RSVPs",
       %{args: [title, group_name, capacity, rsvps]} = context do
    group = lookup_group(group_name)
    host = Ash.get!(Huddlz.Accounts.User, group.owner_id, authorize?: false)

    huddl =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          max_attendees: capacity,
          date: Date.add(eastern_today(), 3),
          actor: host
        )
      )

    # The host's own RSVP is counted, so top up with other people.
    for _ <- 1..(rsvps - 1)//1 do
      attendee = generate(user(role: :user))

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()
    end

    Map.update(context, :huddls, [huddl], &[huddl | &1])
  end

  step "the draft huddl {string} exists in group {string}",
       %{args: [title, group_name]} = context do
    group = lookup_group(group_name)
    host = Ash.get!(Huddlz.Accounts.User, group.owner_id, authorize?: false)

    huddl =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          lifecycle_state: :draft,
          date: Date.add(eastern_today(), 4),
          actor: host
        )
      )

    Map.update(context, :huddls, [huddl], &[huddl | &1])
  end

  step "a weekly series {string} exists in group {string} for the next {int} weeks",
       %{args: [title, group_name, weeks]} = context do
    group = lookup_group(group_name)
    host = Ash.get!(Huddlz.Accounts.User, group.owner_id, authorize?: false)

    source =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          date: Date.add(eastern_today(), 2),
          is_recurring: true,
          frequency: "weekly",
          # The end date is stored at midnight UTC, so the last date only
          # generates when the cutoff sits the day after it.
          repeat_until: Date.add(eastern_today(), 2 + 7 * (weeks - 1) + 1),
          actor: host
        )
      )

    Oban.drain_queue(queue: :default)
    Map.put(context, :series_source, source)
  end

  step "the organizer row for {string} shows when it is and {string}",
       %{args: [title, rsvps], session: session} = context do
    huddl = lookup_huddl(title)
    local = DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)

    session
    |> assert_has("#organize-huddl-#{huddl.id} .org-huddl-meta",
      text: Calendar.strftime(local, "%a %b %-d · %-I:%M %p")
    )
    |> assert_has("#organize-huddl-#{huddl.id} .org-huddl-rsvps", text: rsvps)
    |> assert_has("#organize-huddl-#{huddl.id} .org-huddl-rsvps .bar")

    context
  end

  step "the organizer row for {string} links to the huddl and offers {string}",
       %{args: [title, action], session: session} = context do
    huddl = lookup_huddl(title)
    base = "/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"

    session
    |> assert_has("#organize-huddl-#{huddl.id} a[href='#{base}']", text: title)
    |> assert_has("#organize-huddl-#{huddl.id} a[href='#{base}/edit']", text: action)

    context
  end

  step "the filter chips read {string}, {string}, {string} and {string}",
       %{args: labels, session: session} = context do
    Enum.reduce(labels, session, fn label, session ->
      [name, count] = String.split(label, " ", parts: 2)
      assert_has(session, "#organize-huddlz-filters .chip", text: name, count: 1)
      assert_has(session, "#organize-huddlz-filters .chip .chip-count", text: count)
    end)

    context
  end

  step "the series {string} is one entry reading {string} with {int} dates",
       %{args: [title, cadence, count], session: session, series_source: source} = context do
    session
    |> assert_has("#organize-series-#{source.huddl_template_id} .org-huddl-title", text: title)
    |> assert_has("#organize-series-#{source.huddl_template_id} .org-series-cadence",
      text: cadence
    )
    |> assert_has("#organize-series-#{source.huddl_template_id} .org-series-cadence",
      text: "#{count} dates"
    )
    |> assert_has("#organize-series-#{source.huddl_template_id} .org-instance", count: count)
    |> assert_has(".org-huddl-title", text: title, count: 1)

    context
  end

  step "the first date of {string} is marked as next",
       %{args: [_title], session: session, series_source: source} = context do
    session
    |> assert_has("#organize-huddl-#{source.id}.org-instance[data-next] .org-instance-next",
      text: "Next"
    )
    |> assert_has(".org-instance[data-next]", count: 1)

    context
  end

  step "only {int} dates of {string} show until I ask for the rest",
       %{args: [shown, _title], session: session, series_source: source} = context do
    selector = "#organize-series-#{source.huddl_template_id}"
    total = session |> instance_count(selector)
    hidden = total - shown

    session
    |> assert_has("#{selector}[data-collapsed='true']")
    |> assert_has("#{selector} .org-instance:not(.org-instance-extra)", count: shown)
    |> assert_has("#{selector} .org-instance.org-instance-extra", count: hidden)
    |> assert_has("#{selector} button .when-collapsed", text: "Show #{hidden} more dates")

    context
  end

  step "{string} for {string} opens the edit page on the whole series",
       %{args: [action, _title], session: session, series_source: source} = context do
    session =
      session
      |> click_link("#organize-series-#{source.huddl_template_id} a", action)
      |> assert_has("h1", text: "Editing")
      |> assert_has(".edit-scope-row .chip.is-active", text: "Whole series")

    Map.merge(context, %{conn: session, session: session})
  end

  defp instance_count(session, selector) do
    session.view
    |> Phoenix.LiveViewTest.render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#{selector} .org-instance")
    |> Enum.count()
  end

  defp lookup_group(name) do
    Huddlz.Communities.Group
    |> Ash.Query.filter(name == ^name)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_huddl(title) do
    Huddlz.Communities.Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end
end
