defmodule CopyHuddlApiSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.{GroupLocation, Huddl, HuddlAttendee, HuddlCoverImage, HuddlPhoto}
  alias Huddlz.Storage
  alias Huddlz.Storage.HuddlPhotos

  @description "Bring a laptop with Elixir installed. We'll build a small resource from scratch."
  @virtual_link "https://meet.example.com/pdx-elixir"

  step "I organize a group with a past huddl {string}", %{args: [title]} = context do
    {owner, group} = organized_group()
    location_id = address_book_location_id(group.id)
    location = Ash.get!(GroupLocation, location_id, authorize?: false)
    starts_at = local_datetime(Date.add(eastern_today(), -10), ~T[18:30:00], group.time_zone)

    source =
      generate(
        past_huddl(
          title: title,
          description: @description,
          event_type: :hybrid,
          group_location_id: location.id,
          physical_location: location.address,
          time_zone: location.time_zone,
          virtual_link: @virtual_link,
          max_attendees: 30,
          is_private: false,
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 120, :minute),
          lifecycle_state: :completed,
          group_id: group.id,
          creator_id: owner.id
        )
      )

    organizer_context(context, owner, group, source)
  end

  step "I organize a group with an online huddl {string}", %{args: [title]} = context do
    {owner, group} = organized_group()

    source =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          actor: owner,
          event_type: :virtual,
          virtual_link: @virtual_link
        )
      )

    organizer_context(context, owner, group, source)
  end

  step "I organize a group with a weekly series {string}", %{args: [title]} = context do
    {owner, group} = organized_group()
    today = eastern_today()

    source =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          actor: owner,
          date: Date.add(today, 7),
          is_recurring: true,
          frequency: "weekly",
          repeat_until: Date.add(today, 28)
        )
      )

    assert source.huddl_template_id
    organizer_context(context, owner, group, source)
  end

  step "I organize a group with a cancelled huddl {string}", %{args: [title]} = context do
    {owner, group} = organized_group()
    source = generate(huddl(title: title, group_id: group.id, actor: owner))
    source = Communities.cancel_huddl!(source, nil, actor: owner)
    assert source.lifecycle_state == :cancelled
    organizer_context(context, owner, group, source)
  end

  step "I organize a private group with a draft huddl {string}", %{args: [title]} = context do
    owner = generate(user())
    group = generate(group(actor: owner, owner_id: owner.id, is_public: false))

    source =
      generate(
        huddl(
          title: title,
          description: @description,
          group_id: group.id,
          actor: owner,
          lifecycle_state: :draft,
          max_attendees: 12
        )
      )

    assert source.lifecycle_state == :draft
    assert source.is_private
    organizer_context(context, owner, group, source)
  end

  step "a group I belong to as a member has a past huddl {string}", %{args: [title]} = context do
    {owner, group} = organized_group()
    member = generate(user())
    generate(group_member(group_id: group.id, user_id: member.id, role: "member", actor: owner))

    source =
      generate(
        past_huddl(
          title: title,
          group_id: group.id,
          group_location_id: address_book_location_id(group.id),
          time_zone: group.time_zone,
          creator_id: owner.id,
          lifecycle_state: :completed
        )
      )

    context
    |> organizer_context(owner, group, source)
    |> Map.merge(%{member: member, conn: signed_in_conn(context.conn, member)})
  end

  step "people RSVPd to that huddl, shared a photo and a turnout was recorded", context do
    %{source: source, owner: owner} = context

    for _person <- 1..2 do
      Ash.Seed.seed!(HuddlAttendee, %{huddl_id: source.id, user_id: generate(user()).id})
    end

    {:ok, metadata} =
      HuddlPhotos.store("test/fixtures/test_image.jpg", "friends.jpg", "image/jpeg", source.id)

    Communities.create_huddl_photo!(
      Map.merge(metadata, %{
        filename: "friends.jpg",
        content_type: "image/jpeg",
        huddl_id: source.id
      }),
      actor: owner
    )

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_photos/#{source.id}")
    end)

    Communities.record_turnout!(source, %{in_room: 20, on_call: 4}, actor: owner)
    context
  end

  step "that huddl has a cover image", context do
    source = context.source
    file = "test/fixtures/test_image.jpg"
    storage_path = "/uploads/huddl_cover_images/#{source.id}/banner.jpg"
    thumbnail_path = "/uploads/huddl_cover_images/#{source.id}/banner_thumb.jpg"

    assert {:ok, ^storage_path} = Storage.put(file, storage_path, "image/jpeg")
    assert {:ok, ^thumbnail_path} = Storage.put(file, thumbnail_path, "image/jpeg")

    HuddlCoverImage
    |> Ash.Changeset.for_create(:create, %{
      filename: "banner.jpg",
      content_type: "image/jpeg",
      size_bytes: File.stat!(file).size,
      storage_path: storage_path,
      thumbnail_path: thumbnail_path,
      huddl_id: source.id
    })
    |> Ash.create!(authorize?: false)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_cover_images/#{source.id}")
    end)

    context
  end

  step "its location was removed from the address book", context do
    context.source.group_location_id
    |> then(&Ash.get!(GroupLocation, &1, authorize?: false))
    |> Ash.destroy!(authorize?: false)

    Map.put(context, :source, reload(context.source, context.owner))
  end

  step "I organize another group", context do
    other = generate(group(actor: context.owner, owner_id: context.owner.id))
    Map.put(context, :other_group, other)
  end

  step "I copy it through {string} on a future date", %{args: [api]} = context do
    copy(context, api, %{"date" => Date.to_iso8601(future_date())})
  end

  step "I copy it through {string} on a future date titled {string}",
       %{args: [api, title]} = context do
    copy(context, api, %{"date" => Date.to_iso8601(future_date()), "title" => title})
  end

  step "I copy it through {string} on a future date without its cover",
       %{args: [api]} = context do
    copy(context, api, %{"date" => Date.to_iso8601(future_date()), "copy_cover" => false})
  end

  step "I copy it through {string} on a future date as an in-person huddl",
       %{args: [api]} = context do
    copy(context, api, %{"date" => Date.to_iso8601(future_date()), "event_type" => "in_person"})
  end

  step "I copy it through {string} without a date", %{args: [api]} = context do
    copy(context, api, %{})
  end

  step "I copy it through {string} on a past date", %{args: [api]} = context do
    copy(context, api, %{"date" => Date.to_iso8601(Date.add(eastern_today(), -3))})
  end

  step "I copy it through {string} on a future date at {string}",
       %{args: [api, name]} = context do
    location =
      Ash.Seed.seed!(GroupLocation, %{
        name: name,
        address: "721 NW 9th Ave, Portland, OR",
        latitude: 45.527,
        longitude: -122.681,
        time_zone: context.group.time_zone,
        group_id: context.group.id
      })

    context
    |> Map.put(:chosen_location, location)
    |> copy(api, %{
      "date" => Date.to_iso8601(future_date()),
      "group_location_id" => location.id
    })
  end

  step "I copy it through {string} starting at a future time", %{args: [api]} = context do
    starts_at = local_datetime(future_date(), ~T[19:00:00], context.source.time_zone)

    context
    |> Map.put(:copy_starts_at, starts_at)
    |> copy(api, %{"starts_at" => DateTime.to_iso8601(starts_at)})
  end

  step "I copy it through {string} starting and ending at past times", %{args: [api]} = context do
    starts_at = DateTime.add(DateTime.utc_now(), -3, :day)

    copy(context, api, %{
      "starts_at" => DateTime.to_iso8601(starts_at),
      "ends_at" => DateTime.to_iso8601(DateTime.add(starts_at, 2, :hour))
    })
  end

  step "I copy it into the other group through {string}", %{args: [api]} = context do
    copy(context, api, %{
      "date" => Date.to_iso8601(future_date()),
      "group_id" => context.other_group.id
    })
  end

  step "the copy has the original's title, description, format, location, online link, capacity and visibility",
       context do
    %{source: source, copy: copy} = copied(context)

    for field <- [
          :title,
          :description,
          :event_type,
          :group_location_id,
          :physical_location,
          :place_id,
          :time_zone,
          :virtual_link,
          :max_attendees,
          :is_private,
          :group_id
        ] do
      assert Map.get(copy, field) == Map.get(source, field), "#{field} was not copied"
    end

    refute copy.id == source.id
    context
  end

  step "the copy starts at the original's local time on the new date and lasts as long",
       context do
    %{source: source, copy: copy} = copied(context)
    local = DateTime.shift_zone!(copy.starts_at, copy.time_zone)

    assert DateTime.to_date(local) == future_date()
    assert DateTime.to_time(local) == ~T[18:30:00]

    assert DateTime.diff(copy.ends_at, copy.starts_at) ==
             DateTime.diff(source.ends_at, source.starts_at)

    context
  end

  step "the copy starts at that time and lasts as long as the original", context do
    %{source: source, copy: copy} = copied(context)

    assert DateTime.compare(copy.starts_at, context.copy_starts_at) == :eq

    assert DateTime.diff(copy.ends_at, copy.starts_at) ==
             DateTime.diff(source.ends_at, source.starts_at)

    context
  end

  step "the copy is titled {string}", %{args: [title]} = context do
    assert copied(context).copy.title == title
    context
  end

  step "the copy has the original's description", context do
    assert copied(context).copy.description == @description
    context
  end

  step "I am the only person going to the copy", context do
    %{copy: copy} = copied(context)

    going =
      HuddlAttendee
      |> Ash.Query.filter(huddl_id == ^copy.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)

    assert going == [context.owner.id]
    context
  end

  step "the copy has no photos and no turnout", context do
    %{copy: copy} = copied(context)

    refute HuddlPhoto
           |> Ash.Query.filter(huddl_id == ^copy.id)
           |> Ash.exists?(authorize?: false)

    assert is_nil(copy.turnout_in_room)
    assert is_nil(copy.turnout_recorded_at)
    context
  end

  step "the copy has its own copy of the cover image", context do
    %{source: source, copy: copy} = copied(context)
    {:ok, original} = Communities.get_current_huddl_cover_image(source.id, authorize?: false)
    {:ok, image} = Communities.get_current_huddl_cover_image(copy.id, authorize?: false)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_cover_images/#{copy.id}")
    end)

    assert image.filename == original.filename
    refute image.storage_path == original.storage_path
    assert Storage.exists?(image.storage_path)
    assert Storage.exists?(image.thumbnail_path)
    Map.put(context, :copy_image, image)
  end

  step "the copy has no cover image", context do
    %{copy: copy} = copied(context)

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.get_current_huddl_cover_image(copy.id, authorize?: false)

    context
  end

  step "I remove the copy's cover image", context do
    context.copy_image
    |> Ash.Changeset.for_destroy(:hard_delete, %{})
    |> Ash.destroy!(authorize?: false)

    refute Storage.exists?(context.copy_image.storage_path)
    context
  end

  step "the original still has its cover image", context do
    {:ok, image} = Communities.get_current_huddl_cover_image(context.source.id, authorize?: false)
    assert Storage.exists?(image.storage_path)
    assert Storage.exists?(image.thumbnail_path)
    context
  end

  step "the copy is not part of any series", context do
    assert is_nil(copied(context).copy.huddl_template_id)
    context
  end

  step "the copy is scheduled", context do
    %{copy: copy} = copied(context)
    assert copy.lifecycle_state == :published
    assert is_nil(copy.cancelled_at)
    context
  end

  step "the copy meets at {string}", %{args: [_name]} = context do
    %{copy: copy} = copied(context)
    assert copy.group_location_id == context.chosen_location.id
    assert copy.physical_location == context.chosen_location.address
    context
  end

  step "the copy is refused because {string} {string}", %{args: [field, message]} = context do
    errors = refusal_errors(context)

    assert Enum.any?(errors, fn error ->
             error.field == field and error.message =~ message
           end),
           "expected #{field} #{message}, got #{inspect(errors)}"

    refute_copied(context)
  end

  step "the copy is forbidden", context do
    case context.copy_api do
      "JSON:API" -> assert json_response(context.copy_response, 403)
      "GraphQL" -> assert refusal_errors(context) != []
    end

    refute_copied(context)
  end

  step "the copy's history records that it was copied from the original", context do
    %{source: source, copy: copy} = copied(context)

    version =
      Huddl.Version
      |> Ash.Query.filter(version_source_id == ^copy.id and version_action_name == :create)
      |> Ash.read_one!(authorize?: false)

    assert version.copied_from_id == source.id
    assert DateTime.compare(version.copied_source_ends_at, source.ends_at) == :eq
    context
  end

  defp organized_group do
    owner = generate(user())
    group = generate(group(actor: owner, owner_id: owner.id, is_public: true))
    {owner, group}
  end

  defp organizer_context(context, owner, group, source) do
    Map.merge(context, %{
      owner: owner,
      group: group,
      source: source,
      conn: signed_in_conn(context.conn, owner)
    })
  end

  # Signed in for both the API (bearer token) and the web pages (session),
  # so the copy UI's scenarios share these steps.
  defp signed_in_conn(conn, user), do: conn |> login(user) |> authenticated_conn(user)

  defp future_date, do: Date.add(eastern_today(), 12)

  defp local_datetime(date, time, time_zone) do
    date |> DateTime.new!(time, time_zone) |> DateTime.shift_zone!("Etc/UTC")
  end

  # Reads run as the organizer: the visibility filter hides drafts and
  # private huddlz from reads without an actor, even unauthorized ones.
  defp reload(huddl, actor), do: Ash.get!(Huddl, huddl.id, actor: actor, authorize?: false)

  defp copy(context, api, attributes) do
    attributes = Map.put(attributes, "copied_from_id", context.source.id)
    response = request_copy(context.conn, api, attributes)
    Map.merge(context, %{copy_response: response, copy_api: api})
  end

  defp request_copy(conn, "JSON:API", attributes) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
    |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
    |> Phoenix.ConnTest.dispatch(HuddlzWeb.Endpoint, :post, "/api/json/huddlz", %{
      "data" => %{"type" => "huddl", "attributes" => attributes}
    })
  end

  defp request_copy(conn, "GraphQL", attributes) do
    input = Map.new(attributes, fn {key, value} -> {camelize(key), value} end)

    gql_post(
      conn,
      """
      mutation CopyHuddl($input: CreateHuddlInput!) {
        createHuddl(input: $input) {
          result { id }
          errors { message fields }
        }
      }
      """,
      %{"input" => input}
    )
  end

  defp camelize(key) do
    [first | rest] = String.split(key, "_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end

  defp copied(context) do
    id =
      case context.copy_api do
        "JSON:API" ->
          json_response(context.copy_response, 201)["data"]["id"]

        "GraphQL" ->
          response = json_response(context.copy_response, 200)

          assert response["data"]["createHuddl"]["errors"] == [],
                 inspect(response["data"]["createHuddl"]["errors"])

          response["data"]["createHuddl"]["result"]["id"]
      end

    %{
      source: reload(context.source, context.owner),
      copy: Ash.get!(Huddl, id, actor: context.owner, authorize?: false)
    }
  end

  defp refusal_errors(%{copy_api: "JSON:API", copy_response: response}) do
    body = Jason.decode!(response.resp_body)
    assert response.status in [400, 403, 422], inspect(body)

    Enum.map(body["errors"], fn error ->
      pointer = get_in(error, ["source", "pointer"]) || ""
      %{field: pointer |> String.split("/") |> List.last(), message: error["detail"] || ""}
    end)
  end

  defp refusal_errors(%{copy_api: "GraphQL", copy_response: response}) do
    body = json_response(response, 200)

    (get_in(body, ["data", "createHuddl", "errors"]) || body["errors"] || [])
    |> Enum.map(fn error ->
      %{field: Enum.join(error["fields"] || [], ","), message: error["message"] || ""}
    end)
  end

  defp refute_copied(context) do
    %{source: source, group: group} = context

    count =
      Huddl
      |> Ash.Query.filter(group_id == ^group.id and id != ^source.id)
      |> Ash.count!(authorize?: false)

    assert count == 0
    context
  end
end
