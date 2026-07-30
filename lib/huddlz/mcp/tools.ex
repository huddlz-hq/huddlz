defmodule Huddlz.MCP.Tools do
  @moduledoc """
  Narrow MCP tool contracts backed by actor-scoped Ash domain actions.

  The first release intentionally excludes ownership transfer, member
  administration, image uploads, recurring-series mutation, and credential
  management. Those operations need richer confirmation or binary input than a
  safe text-tool contract can provide.
  """

  alias Ash.Page.Offset
  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupMember, Huddl}

  @default_limit 20
  @max_limit 50

  @read_annotations %{
    "readOnlyHint" => true,
    "destructiveHint" => false,
    "idempotentHint" => true,
    "openWorldHint" => false
  }

  @write_annotations %{
    "readOnlyHint" => false,
    "destructiveHint" => false,
    "idempotentHint" => false,
    "openWorldHint" => false
  }

  @destructive_annotations %{
    "readOnlyHint" => false,
    "destructiveHint" => true,
    "idempotentHint" => false,
    "openWorldHint" => false
  }

  @doc "MCP tool definitions advertised by `tools/list`."
  def definitions do
    [
      tool(
        "search_groups",
        "Search visible groups. Anonymous callers see only public groups.",
        pagination_schema(%{
          "search" => string("Optional name or description search")
        }),
        @read_annotations
      ),
      tool(
        "get_group",
        "Get one visible group by slug.",
        object_schema(%{"slug" => string("Group slug")}, ["slug"]),
        @read_annotations
      ),
      tool(
        "search_huddlz",
        "Search visible huddlz with stable offset pagination.",
        pagination_schema(%{
          "query" => string("Optional title or description search"),
          "date_filter" =>
            enum_string(
              ["upcoming", "this_week", "this_month", "past", "all"],
              "Date window; defaults to upcoming"
            ),
          "event_type" => enum_string(["in_person", "virtual", "hybrid"], "Optional huddl format")
        }),
        @read_annotations
      ),
      tool(
        "get_huddl",
        "Get one visible huddl by ID. Virtual access is returned only when authorized.",
        object_schema(%{"huddl_id" => uuid("Huddl ID")}, ["huddl_id"]),
        @read_annotations
      ),
      tool(
        "list_my_groups",
        "List groups the authenticated person owns or has joined.",
        pagination_schema(%{
          "relationship" => enum_string(["all", "hosting", "joined"], "Defaults to all")
        }),
        @read_annotations
      ),
      tool(
        "list_my_huddlz",
        "List huddlz the authenticated person hosts, attends, or is waitlisted for.",
        pagination_schema(%{
          "relationship" =>
            enum_string(
              ["hosting", "attending", "waitlisted"],
              "Required relationship to the huddl"
            ),
          "date_filter" => enum_string(["upcoming", "past", "all"], "Defaults to upcoming")
        })
        |> require_fields(["relationship"]),
        @read_annotations
      ),
      confirmed_tool(
        "join_group",
        "Join a public group as the authenticated person.",
        %{"slug" => string("Group slug")},
        ["slug"],
        @write_annotations
      ),
      confirmed_tool(
        "leave_group",
        "Leave a group as the authenticated person. Group owners cannot leave.",
        %{"slug" => string("Group slug")},
        ["slug"],
        @destructive_annotations
      ),
      confirmed_tool(
        "rsvp_huddl",
        "RSVP the authenticated person to a visible huddl.",
        %{"huddl_id" => uuid("Huddl ID")},
        ["huddl_id"],
        @write_annotations
      ),
      confirmed_tool(
        "join_huddl_waitlist",
        "Join a full huddl's waitlist as the authenticated person.",
        %{"huddl_id" => uuid("Huddl ID")},
        ["huddl_id"],
        @write_annotations
      ),
      confirmed_tool(
        "cancel_huddl_rsvp",
        "Cancel the authenticated person's RSVP or waitlist place.",
        %{"huddl_id" => uuid("Huddl ID")},
        ["huddl_id"],
        @destructive_annotations
      ),
      confirmed_tool(
        "create_group",
        "Create a group owned by the authenticated person.",
        %{
          "name" => string("Group name"),
          "description" => string("Group description"),
          "location" => string("Group location"),
          "is_public" => boolean("Whether anyone can discover and join the group"),
          "slug" => string("Optional URL slug; generated when omitted")
        },
        ["name", "description", "location", "is_public"],
        @write_annotations
      ),
      confirmed_tool(
        "update_group",
        "Update a group owned by the authenticated person.",
        %{
          "slug" => string("Current group slug"),
          "name" => string("New group name"),
          "description" => string("New group description"),
          "location" => string("New group location"),
          "is_public" => boolean("New visibility"),
          "new_slug" => string("New URL slug")
        },
        ["slug"],
        @write_annotations
      ),
      confirmed_tool(
        "delete_group",
        "Permanently delete a group owned by the authenticated person.",
        %{"slug" => string("Group slug")},
        ["slug"],
        @destructive_annotations
      ),
      confirmed_tool(
        "create_huddl",
        "Create one non-recurring huddl in a group the authenticated person organizes.",
        huddl_input_schema(%{"group_slug" => string("Organizer group slug")}),
        [
          "group_slug",
          "title",
          "date",
          "start_time",
          "duration_minutes",
          "event_type",
          "is_private"
        ],
        @write_annotations
      ),
      confirmed_tool(
        "update_huddl",
        "Update one huddl the authenticated person organizes.",
        huddl_input_schema(%{
          "huddl_id" => uuid("Huddl ID"),
          "edit_type" =>
            enum_string(["instance", "all"], "Recurring edit scope; defaults to instance")
        }),
        ["huddl_id"],
        @write_annotations
      ),
      confirmed_tool(
        "cancel_huddl",
        "Permanently cancel and delete a huddl the authenticated person organizes.",
        %{"huddl_id" => uuid("Huddl ID")},
        ["huddl_id"],
        @destructive_annotations
      )
    ]
  end

  @doc "Executes one MCP tool as `actor`."
  def call("search_groups", args, actor) do
    with {:ok, page} <- page_options(args),
         {:ok, %Offset{} = result} <-
           Communities.search_groups(Map.get(args, "search"),
             actor: actor,
             page: page,
             load: [:member_count]
           ) do
      {:ok, page_result(result, &serialize_group/1)}
    else
      error -> normalize_error(error)
    end
  end

  def call("get_group", %{"slug" => slug}, actor) when is_binary(slug) do
    case Communities.get_by_slug(slug, actor: actor, load: [:member_count]) do
      {:ok, %Group{} = group} -> {:ok, %{group: serialize_group(group)}}
      {:ok, nil} -> {:error, :not_found, "Group not found"}
      error -> normalize_error(error)
    end
  end

  def call("search_huddlz", args, actor) do
    with {:ok, page} <- page_options(args),
         {:ok, date_filter} <-
           enum_arg(args, "date_filter", [:upcoming, :this_week, :this_month, :past, :all],
             default: :upcoming
           ),
         {:ok, event_type} <-
           enum_arg(args, "event_type", [:in_person, :virtual, :hybrid], default: nil),
         {:ok, %Offset{} = result} <-
           Communities.search_huddlz(
             Map.get(args, "query"),
             date_filter,
             event_type,
             nil,
             nil,
             nil,
             nil,
             :soonest,
             actor: actor,
             page: page,
             load: huddl_loads(actor)
           ) do
      {:ok, page_result(result, &serialize_huddl/1)}
    else
      error -> normalize_error(error)
    end
  end

  def call("get_huddl", %{"huddl_id" => id}, actor) when is_binary(id) do
    case Communities.get_huddl(id, actor: actor, load: huddl_loads(actor)) do
      {:ok, %Huddl{} = huddl} -> {:ok, %{huddl: serialize_huddl(huddl)}}
      {:ok, nil} -> {:error, :not_found, "Huddl not found"}
      error -> normalize_error(error)
    end
  end

  def call("list_my_groups", args, actor) do
    with {:ok, actor} <- require_actor(actor),
         {:ok, relationship} <-
           enum_arg(args, "relationship", [:all, :hosting, :joined], default: :all),
         {:ok, page} <- page_options(args),
         {:ok, %Offset{} = result} <-
           Communities.my_groups(relationship,
             actor: actor,
             page: page,
             load: [:member_count]
           ) do
      {:ok, page_result(result, &serialize_group/1)}
    else
      error -> normalize_error(error)
    end
  end

  def call("list_my_huddlz", args, actor) do
    with {:ok, actor} <- require_actor(actor),
         {:ok, relationship} <-
           enum_arg(args, "relationship", [:hosting, :attending, :waitlisted]),
         {:ok, date_filter} <-
           enum_arg(args, "date_filter", [:upcoming, :past, :all], default: :upcoming),
         {:ok, page} <- page_options(args),
         {:ok, %Offset{} = result} <-
           Communities.search_huddlz(
             nil,
             date_filter,
             nil,
             nil,
             nil,
             nil,
             relationship,
             if(date_filter == :past, do: :newest, else: :soonest),
             actor: actor,
             page: page,
             load: huddl_loads(actor)
           ) do
      {:ok, page_result(result, &serialize_huddl/1)}
    else
      error -> normalize_error(error)
    end
  end

  def call("join_group", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, group} <- fetch_group(args["slug"], actor),
         {:ok, membership} <-
           Communities.join_group_from_attrs(%{group_id: group.id}, actor: actor) do
      {:ok, %{membership: serialize_membership(membership), group: serialize_group(group)}}
    else
      error -> normalize_error(error)
    end
  end

  def call("leave_group", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, group} <- fetch_group(args["slug"], actor),
         {:ok, %GroupMember{} = membership} <-
           Communities.get_membership_in_group(group.id, actor: actor),
         :ok <- Communities.leave_group(membership, actor: actor) do
      {:ok, %{left_group: group.slug}}
    else
      {:ok, nil} -> {:error, :not_found, "Membership not found"}
      error -> normalize_error(error)
    end
  end

  def call("rsvp_huddl", args, actor),
    do: mutate_huddl(args, actor, &Communities.rsvp_huddl/3, "rsvped")

  def call("join_huddl_waitlist", args, actor),
    do: mutate_huddl(args, actor, &Communities.join_waitlist_huddl/3, "waitlisted")

  def call("cancel_huddl_rsvp", args, actor),
    do: mutate_huddl(args, actor, &Communities.cancel_rsvp_huddl/3, "cancelled")

  def call("create_group", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, attrs} <-
           take_required(args, ["name", "description", "location", "is_public"], ["slug"]),
         {:ok, group} <-
           Communities.create_group_from_attrs(atomize_keys(attrs), actor: actor) do
      {:ok, %{group: serialize_group(group)}}
    else
      error -> normalize_error(error)
    end
  end

  def call("update_group", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, group} <- fetch_group(args["slug"], actor),
         {:ok, attrs} <-
           take_updates(args, ["name", "description", "location", "is_public", "new_slug"]),
         attrs <- rename_key(attrs, "new_slug", "slug"),
         {:ok, updated} <-
           Communities.update_group_from_attrs(group, atomize_keys(attrs), actor: actor) do
      {:ok, %{group: serialize_group(updated)}}
    else
      error -> normalize_error(error)
    end
  end

  def call("delete_group", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, group} <- fetch_group(args["slug"], actor),
         :ok <- Communities.destroy_group(group, actor: actor) do
      {:ok, %{deleted_group: group.slug}}
    else
      error -> normalize_error(error)
    end
  end

  def call("create_huddl", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, group} <- fetch_group(args["group_slug"], actor),
         {:ok, attrs} <- huddl_attrs(args, :create),
         attrs <- Map.put(attrs, :group_id, group.id),
         {:ok, huddl} <- Communities.create_huddl_from_attrs(attrs, actor: actor) do
      {:ok, %{huddl: serialize_huddl(huddl)}}
    else
      error -> normalize_error(error)
    end
  end

  def call("update_huddl", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, huddl} <- fetch_huddl(args["huddl_id"], actor),
         {:ok, attrs} <- huddl_attrs(args, :update),
         {:ok, updated} <-
           Communities.update_huddl_from_attrs(huddl, attrs, actor: actor) do
      {:ok, %{huddl: serialize_huddl(updated)}}
    else
      error -> normalize_error(error)
    end
  end

  def call("cancel_huddl", args, actor) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, huddl} <- fetch_huddl(args["huddl_id"], actor),
         :ok <- Communities.destroy_huddl(huddl, actor: actor) do
      {:ok, %{cancelled_huddl: huddl.id}}
    else
      error -> normalize_error(error)
    end
  end

  def call(name, _args, _actor),
    do: {:error, :tool_not_found, "Unknown tool: #{name}"}

  defp mutate_huddl(args, actor, operation, outcome) do
    with {:ok, actor} <- confirmed_actor(args, actor),
         {:ok, huddl} <- fetch_huddl(args["huddl_id"], actor),
         {:ok, updated} <- operation.(huddl, %{}, actor: actor) do
      {:ok, %{outcome: outcome, huddl: serialize_huddl(updated)}}
    else
      error -> normalize_error(error)
    end
  end

  defp fetch_group(slug, actor) when is_binary(slug) do
    case Communities.get_by_slug(slug, actor: actor, load: [:member_count]) do
      {:ok, %Group{} = group} -> {:ok, group}
      {:ok, nil} -> {:error, :not_found, "Group not found"}
      error -> error
    end
  end

  defp fetch_group(_slug, _actor), do: {:error, :invalid_params, "slug is required"}

  defp fetch_huddl(id, actor) when is_binary(id) do
    case Communities.get_huddl(id, actor: actor, load: huddl_loads(actor)) do
      {:ok, %Huddl{} = huddl} -> {:ok, huddl}
      {:ok, nil} -> {:error, :not_found, "Huddl not found"}
      error -> error
    end
  end

  defp fetch_huddl(_id, _actor), do: {:error, :invalid_params, "huddl_id is required"}

  defp confirmed_actor(%{"confirm" => true}, actor), do: require_actor(actor)

  defp confirmed_actor(_args, _actor),
    do: {:error, :invalid_params, "confirm must be true before this tool can make changes"}

  defp require_actor(%User{} = actor), do: {:ok, actor}

  defp require_actor(_actor),
    do: {:error, :authentication_required, "A valid bearer API credential is required"}

  defp page_options(args) do
    with {:ok, limit} <- limit(args),
         {:ok, offset} <- decode_cursor(Map.get(args, "cursor")) do
      {:ok, [limit: limit, offset: offset, count: true]}
    end
  end

  defp limit(%{"limit" => limit}) when is_integer(limit) and limit in 1..@max_limit,
    do: {:ok, limit}

  defp limit(%{"limit" => _}),
    do: {:error, :invalid_params, "limit must be between 1 and #{@max_limit}"}

  defp limit(_args), do: {:ok, @default_limit}

  defp decode_cursor(nil), do: {:ok, 0}

  defp decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         {offset, ""} when offset >= 0 <- Integer.parse(decoded) do
      {:ok, offset}
    else
      _ -> {:error, :invalid_params, "cursor is invalid or expired"}
    end
  end

  defp decode_cursor(_), do: {:error, :invalid_params, "cursor must be a string"}

  defp encode_cursor(offset), do: Base.url_encode64(Integer.to_string(offset), padding: false)

  defp page_result(%Offset{} = page, serializer) do
    next_cursor =
      if page.more? do
        encode_cursor(page.offset + page.limit)
      end

    %{
      items: Enum.map(page.results, serializer),
      next_cursor: next_cursor,
      total_count: page.count
    }
  end

  defp huddl_loads(%User{}), do: [:status, :visible_virtual_link, :rsvp_count, :waitlist_count]
  defp huddl_loads(_), do: [:status, :rsvp_count, :waitlist_count]

  defp serialize_group(group) do
    %{
      id: group.id,
      slug: group.slug,
      name: group.name,
      description: group.description,
      location: group.location,
      is_public: group.is_public,
      member_count: loaded_value(group, :member_count)
    }
  end

  defp serialize_huddl(huddl) do
    %{
      id: huddl.id,
      group_id: huddl.group_id,
      title: huddl.title,
      description: huddl.description,
      starts_at: huddl.starts_at,
      ends_at: huddl.ends_at,
      event_type: huddl.event_type,
      physical_location: huddl.physical_location,
      virtual_link: loaded_value(huddl, :visible_virtual_link),
      is_private: huddl.is_private,
      max_attendees: huddl.max_attendees,
      rsvp_count: loaded_value(huddl, :rsvp_count),
      waitlist_count: loaded_value(huddl, :waitlist_count),
      status: loaded_value(huddl, :status)
    }
  end

  defp serialize_membership(membership) do
    %{id: membership.id, group_id: membership.group_id, role: membership.role}
  end

  defp loaded_value(record, field) do
    case Map.get(record, field) do
      %Ash.NotLoaded{} -> nil
      %Ash.ForbiddenField{} -> nil
      value -> value
    end
  end

  defp enum_arg(args, key, allowed, opts \\ []) do
    case Map.fetch(args, key) do
      {:ok, value} when is_binary(value) ->
        case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
          nil -> {:error, :invalid_params, "#{key} must be one of #{enum_names(allowed)}"}
          atom -> {:ok, atom}
        end

      {:ok, _value} ->
        {:error, :invalid_params, "#{key} must be a string"}

      :error ->
        case Keyword.fetch(opts, :default) do
          {:ok, default} -> {:ok, default}
          :error -> {:error, :invalid_params, "#{key} is required"}
        end
    end
  end

  defp enum_names(values), do: Enum.map_join(values, ", ", &Atom.to_string/1)

  defp take_required(args, required, optional) do
    missing = Enum.reject(required, &Map.has_key?(args, &1))

    if missing == [] do
      {:ok, Map.take(args, required ++ optional)}
    else
      {:error, :invalid_params, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end

  defp take_updates(args, fields) do
    updates = Map.take(args, fields)

    if map_size(updates) == 0 do
      {:error, :invalid_params, "At least one update field is required"}
    else
      {:ok, updates}
    end
  end

  defp huddl_attrs(args, mode) do
    fields = [
      "title",
      "description",
      "date",
      "start_time",
      "duration_minutes",
      "event_type",
      "physical_location",
      "virtual_link",
      "is_private",
      "max_attendees",
      "edit_type"
    ]

    required =
      if mode == :create do
        ["title", "date", "start_time", "duration_minutes", "event_type", "is_private"]
      else
        []
      end

    with {:ok, attrs} <-
           if(mode == :create,
             do: take_required(args, required, fields -- required),
             else: take_updates(args, fields)
           ),
         {:ok, attrs} <- parse_date(attrs),
         {:ok, attrs} <- parse_time(attrs),
         {:ok, attrs} <- parse_enum(attrs, "event_type", [:in_person, :virtual, :hybrid]),
         {:ok, attrs} <- parse_enum(attrs, "edit_type", [:instance, :all]) do
      {:ok, atomize_keys(attrs)}
    end
  end

  defp parse_date(%{"date" => value} = attrs) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, Map.put(attrs, "date", date)}
      {:error, _} -> {:error, :invalid_params, "date must use YYYY-MM-DD"}
    end
  end

  defp parse_date(%{"date" => _attrs}),
    do: {:error, :invalid_params, "date must use YYYY-MM-DD"}

  defp parse_date(attrs), do: {:ok, attrs}

  defp parse_time(%{"start_time" => value} = attrs) when is_binary(value) do
    normalized =
      if Regex.match?(~r/^\d{2}:\d{2}$/, value) do
        value <> ":00"
      else
        value
      end

    case Time.from_iso8601(normalized) do
      {:ok, time} -> {:ok, Map.put(attrs, "start_time", time)}
      {:error, _} -> {:error, :invalid_params, "start_time must use HH:MM or HH:MM:SS"}
    end
  end

  defp parse_time(%{"start_time" => _attrs}),
    do: {:error, :invalid_params, "start_time must use HH:MM or HH:MM:SS"}

  defp parse_time(attrs), do: {:ok, attrs}

  defp parse_enum(attrs, key, allowed) do
    case Map.fetch(attrs, key) do
      {:ok, value} ->
        with {:ok, parsed} <- enum_arg(%{key => value}, key, allowed) do
          {:ok, Map.put(attrs, key, parsed)}
        end

      :error ->
        {:ok, attrs}
    end
  end

  @allowed_atom_keys %{
    "name" => :name,
    "description" => :description,
    "location" => :location,
    "is_public" => :is_public,
    "slug" => :slug,
    "title" => :title,
    "date" => :date,
    "start_time" => :start_time,
    "duration_minutes" => :duration_minutes,
    "event_type" => :event_type,
    "physical_location" => :physical_location,
    "virtual_link" => :virtual_link,
    "is_private" => :is_private,
    "max_attendees" => :max_attendees,
    "edit_type" => :edit_type
  }

  defp atomize_keys(map) do
    Map.new(map, fn {key, value} -> {Map.fetch!(@allowed_atom_keys, key), value} end)
  end

  defp rename_key(map, old, new) do
    case Map.pop(map, old) do
      {nil, map} -> map
      {value, map} -> Map.put(map, new, value)
    end
  end

  defp normalize_error({:error, kind, message})
       when kind in [
              :authentication_required,
              :forbidden,
              :not_found,
              :invalid_params,
              :tool_not_found,
              :internal
            ],
       do: {:error, kind, message}

  defp normalize_error({:error, %Ash.Error.Forbidden{}}),
    do: {:error, :forbidden, "The authenticated person is not allowed to do that"}

  defp normalize_error({:error, %Ash.Error.Invalid{} = error}) do
    if contains_not_found?(error) do
      {:error, :not_found, "The requested record was not found or is not visible"}
    else
      {:error, :invalid_params, invalid_message(error)}
    end
  end

  defp normalize_error({:error, _error}),
    do: {:error, :internal, "The request could not be completed"}

  defp normalize_error(other),
    do: {:error, :internal, "Unexpected result: #{inspect(other)}"}

  defp contains_not_found?(%Ash.Error.Query.NotFound{}), do: true

  defp contains_not_found?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &contains_not_found?/1)

  defp contains_not_found?(_error), do: false

  defp invalid_message(%{errors: errors}) when is_list(errors) do
    messages =
      errors
      |> Enum.flat_map(&leaf_messages/1)
      |> Enum.uniq()

    case messages do
      [] -> "The inputs are invalid"
      messages -> Enum.join(messages, "; ")
    end
  end

  defp invalid_message(_error), do: "The inputs are invalid"

  defp leaf_messages(%{errors: errors}) when is_list(errors),
    do: Enum.flat_map(errors, &leaf_messages/1)

  defp leaf_messages(error) do
    case Map.get(error, :message) do
      message when is_binary(message) ->
        case Map.get(error, :field) do
          field when is_atom(field) -> ["#{field} #{message}"]
          _ -> [message]
        end

      _ ->
        []
    end
  end

  defp tool(name, description, input_schema, annotations) do
    %{
      "name" => name,
      "description" => description,
      "inputSchema" => input_schema,
      "annotations" => annotations
    }
  end

  defp confirmed_tool(name, description, properties, required, annotations) do
    confirmation =
      boolean(
        "Must be true. Set this only after the person has reviewed and approved the change."
      )

    tool(
      name,
      description <> " This tool makes a change and requires explicit confirmation.",
      object_schema(Map.put(properties, "confirm", confirmation), required ++ ["confirm"]),
      annotations
    )
  end

  defp pagination_schema(properties) do
    object_schema(
      Map.merge(properties, %{
        "limit" => %{
          "type" => "integer",
          "minimum" => 1,
          "maximum" => @max_limit,
          "description" => "Page size; defaults to #{@default_limit}"
        },
        "cursor" => string("Opaque next_cursor from the previous response")
      })
    )
  end

  defp huddl_input_schema(extra) do
    Map.merge(extra, %{
      "title" => string("Huddl title"),
      "description" => string("Huddl description"),
      "date" => string("Local date in YYYY-MM-DD format"),
      "start_time" => string("Local time in HH:MM or HH:MM:SS format"),
      "duration_minutes" => %{"type" => "integer", "minimum" => 15, "maximum" => 1440},
      "event_type" => enum_string(["in_person", "virtual", "hybrid"], "Huddl format"),
      "physical_location" => string("Required for in-person and hybrid huddlz"),
      "virtual_link" => string("Required for virtual and hybrid huddlz"),
      "is_private" => boolean("Whether discovery is restricted to group members"),
      "max_attendees" => %{"type" => ["integer", "null"], "minimum" => 1}
    })
  end

  defp object_schema(properties, required \\ []) do
    %{
      "type" => "object",
      "properties" => properties,
      "required" => required,
      "additionalProperties" => false
    }
  end

  defp require_fields(schema, fields), do: Map.put(schema, "required", fields)

  defp string(description), do: %{"type" => "string", "description" => description}

  defp uuid(description),
    do: %{"type" => "string", "format" => "uuid", "description" => description}

  defp boolean(description), do: %{"type" => "boolean", "description" => description}

  defp enum_string(values, description),
    do: %{"type" => "string", "enum" => values, "description" => description}
end
