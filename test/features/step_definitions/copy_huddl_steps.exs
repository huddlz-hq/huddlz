defmodule CopyHuddlSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.CopySuggestion

  # Steps that set up a group and a huddl to copy live with the API's copy
  # feature (copy_huddl_api_steps.exs); they sign the organizer in for both.

  step "I organize a group with an upcoming huddl {string}", %{args: [title]} = context do
    owner = generate(user())
    group = generate(group(actor: owner, owner_id: owner.id, is_public: true))

    source =
      generate(
        huddl(title: title, group_id: group.id, actor: owner, date: Date.add(eastern_today(), 5))
      )

    Map.merge(context, %{
      owner: owner,
      group: group,
      source: source,
      conn: login(context.conn, owner)
    })
  end

  step "I visit that huddl and choose to copy it", context do
    session =
      context.conn
      |> visit(huddl_path(context))
      |> click_link("Copy huddl")

    Map.put(context, :session, session)
  end

  step "I visit that huddl", context do
    Map.put(context, :session, visit(context.conn, huddl_path(context)))
  end

  step "I copy it from the past huddlz on the organizer page", context do
    session =
      context.conn
      |> visit("/organize/#{context.group.slug}/huddlz?filter=past")
      |> within("#organize-huddl-#{context.source.id}", &click_link(&1, "Copy"))

    Map.put(context, :session, session)
  end

  step "I open the new huddl form for the other group copying that huddl", context do
    path = "/groups/#{context.other_group.slug}/huddlz/new?copy=#{context.source.id}"
    Map.put(context, :session, visit(context.conn, path))
  end

  step "I see the new huddl form filled in from {string}", %{args: [title]} = context do
    source = context.source

    context.session
    |> assert_has("*", text: "Copied from “#{title}”")
    |> assert_has("input", label: "Title", value: title)
    |> assert_has("textarea", text: source.description)
    |> assert_has("input", label: "Start time", value: local_start(source))
    |> assert_has("input", label: "Online link", value: source.virtual_link)
    |> assert_has("input", label: "Max attendees", value: to_string(source.max_attendees))

    context
  end

  step "the date suggested is the next matching weekday", context do
    assert_suggested(context, CopySuggestion.date(context.source))
  end

  step "the date suggested is a week after that huddl", context do
    assert_suggested(context, Date.add(local_date(context.source), 7))
  end

  step "I schedule the huddl", context do
    Map.update!(context, :session, &click_button(&1, "Schedule huddl"))
  end

  step "I leave the form without saving", context do
    Map.update!(context, :session, &click_link(&1, "Cancel"))
  end

  step "the group has a new upcoming {string}", %{args: [title]} = context do
    [copy] = copies(context)
    source = context.source

    assert copy.title == title
    assert copy.lifecycle_state == :published
    assert local_date(copy) == CopySuggestion.date(source)
    assert local_start(copy) == local_start(source)

    assert DateTime.diff(copy.ends_at, copy.starts_at) ==
             DateTime.diff(source.ends_at, source.starts_at)

    Map.put(context, :copy, copy)
  end

  step "the group has no new huddl", context do
    assert copies(context) == []
    context
  end

  step "the past huddl is unchanged", context do
    source = context.source
    reloaded = Ash.get!(Huddl, source.id, actor: context.owner, authorize?: false)

    for field <- [:title, :starts_at, :ends_at, :lifecycle_state, :group_location_id] do
      assert Map.get(reloaded, field) == Map.get(source, field), "#{field} changed"
    end

    context
  end

  step "the form shows a copy of the original's cover", context do
    assert_has(context.session, "*", text: "Changing it here leaves the original alone")
    context
  end

  step "I remove the copied cover", context do
    Map.update!(context, :session, &click_button(&1, "Remove"))
  end

  step "the new huddl has its own copy of the cover image", context do
    [copy] = copies(context)

    {:ok, original} =
      Communities.get_current_huddl_cover_image(context.source.id, authorize?: false)

    {:ok, image} = Communities.get_current_huddl_cover_image(copy.id, authorize?: false)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_cover_images/#{copy.id}")
    end)

    assert image.filename == original.filename
    refute image.storage_path == original.storage_path
    context
  end

  step "the new huddl has no cover image", context do
    [copy] = copies(context)

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.get_current_huddl_cover_image(copy.id, authorize?: false)

    context
  end

  step "I am told the original's location was removed and to choose one", context do
    address = context.source.physical_location

    context.session
    |> assert_has("*", text: "#{address} was removed from the address book; choose a location")

    context
  end

  step "the new huddl form is not set to repeat", context do
    refute_has(context.session, "label", text: "Frequency")
    context
  end

  step "I am told the copy is a one-off from a weekly series", context do
    date = Calendar.strftime(local_date(context.source), "%b %-d")

    assert_has(
      context.session,
      "*",
      text: "Copied as a one-off. The #{date} huddl was part of a weekly series."
    )

    context
  end

  step "I cannot copy it", context do
    refute_has(context.session, "a", text: "Copy huddl")
    context
  end

  step "the new huddl form is empty", context do
    context.session
    |> refute_has("*", text: "Copied from")
    |> refute_has("input", label: "Title", value: context.source.title)

    context
  end

  defp huddl_path(context), do: "/groups/#{context.group.slug}/huddlz/#{context.source.id}"

  defp assert_suggested(context, date) do
    context.session
    |> assert_has("input", label: "Date", value: Date.to_iso8601(date))
    |> assert_has("*", text: "Suggested: the next #{Calendar.strftime(date, "%A")}.")

    context
  end

  defp copies(context) do
    %{source: source, group: group, owner: owner} = context

    Huddl
    |> Ash.Query.filter(group_id == ^group.id and id != ^source.id)
    |> Ash.read!(actor: owner, authorize?: false)
    |> Enum.reject(&(&1.huddl_template_id && &1.huddl_template_id == source.huddl_template_id))
  end

  defp local_date(huddl),
    do: huddl.starts_at |> DateTime.shift_zone!(huddl.time_zone) |> DateTime.to_date()

  defp local_start(huddl) do
    huddl.starts_at
    |> DateTime.shift_zone!(huddl.time_zone)
    |> Calendar.strftime("%H:%M:%S")
  end
end
