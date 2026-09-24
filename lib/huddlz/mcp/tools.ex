defmodule Huddlz.Mcp.Tools do
  @moduledoc "Narrow MCP contracts; all business operations use existing authorized actions."
  use Ash.Resource, otp_app: :huddlz, domain: Huddlz.Mcp, authorizers: [Ash.Policy.Authorizer]

  actions do
    action :search_groups, :map do
      description "Discover visible groups by name, description, and distance from their home location. Uses your saved home unless coordinates or anywhere are supplied."

      constraints fields: [
                    items: [type: {:array, Huddlz.Mcp.GroupResult}, allow_nil?: false],
                    next_offset: [
                      type: :integer,
                      description: "Next page offset, or null when finished."
                    ]
                  ]

      argument :query, :string,
        constraints: [max_length: 300],
        description: "Words in the group's name or description."

      argument :latitude, :float,
        constraints: [min: -90, max: 90],
        description: "Search latitude; supply longitude too."

      argument :longitude, :float,
        constraints: [min: -180, max: 180],
        description: "Search longitude; supply latitude too."

      argument :distance_miles, :integer,
        allow_nil?: false,
        default: 25,
        constraints: [min: 5, max: 100],
        description: "Radius in miles."

      argument :anywhere, :boolean,
        allow_nil?: false,
        default: false,
        description: "Search without a distance restriction only when requested."

      argument :limit, :integer,
        allow_nil?: false,
        default: 20,
        constraints: [min: 1, max: 50],
        description: "Maximum results per page."

      argument :offset, :integer,
        allow_nil?: false,
        default: 0,
        constraints: [min: 0, max: 10_000],
        description: "Next offset from a preceding result."

      run Huddlz.Mcp.Groups
    end

    action :my_groups, :map do
      description "List groups you own or belong to, without a geographic restriction."

      constraints fields: [
                    items: [type: {:array, Huddlz.Mcp.GroupResult}, allow_nil?: false],
                    next_offset: [
                      type: :integer,
                      description: "Next page offset, or null when finished."
                    ]
                  ]

      argument :limit, :integer,
        allow_nil?: false,
        default: 20,
        constraints: [min: 1, max: 50],
        description: "Maximum results per page."

      argument :offset, :integer,
        allow_nil?: false,
        default: 0,
        constraints: [min: 0, max: 10_000],
        description: "Next offset from a preceding result."

      run Huddlz.Mcp.Groups
    end

    action :get_group, Huddlz.Mcp.GroupResult do
      description "Read details of a group visible to you. Does not expose membership rosters."

      argument :slug, :string,
        allow_nil?: false,
        constraints: [max_length: 200],
        description: "Group slug returned by discovery."

      run Huddlz.Mcp.Groups
    end

    action :join_group, :map do
      description "Join a public group as yourself. Requires explicit user intent; may notify organizers. Never join a group implicitly when RSVPing."

      constraints fields: [
                    group_id: [type: :uuid, description: "Group identifier."],
                    slug: [type: :string, description: "Group slug."],
                    membership: [
                      type: :string,
                      description: "Your resulting role: none, member, organizer, or owner."
                    ]
                  ]

      argument :slug, :string,
        allow_nil?: false,
        constraints: [max_length: 200],
        description: "The specific group the person chose."

      argument :confirmed, :boolean,
        allow_nil?: false,
        description: "True only after explicit user intent for this membership change."

      run Huddlz.Mcp.Groups
    end

    action :leave_group, :map do
      description "Leave a group as yourself after explicit user intent. You may lose access to private huddlz; owners must transfer ownership in the website first."

      constraints fields: [
                    group_id: [type: :uuid, description: "Group identifier."],
                    slug: [type: :string, description: "Group slug."],
                    membership: [
                      type: :string,
                      description: "Your resulting role: none, member, organizer, or owner."
                    ]
                  ]

      argument :slug, :string,
        allow_nil?: false,
        constraints: [max_length: 200],
        description: "The specific group the person chose."

      argument :confirmed, :boolean,
        allow_nil?: false,
        description: "True only after explicit user intent for this membership change."

      run Huddlz.Mcp.Groups
    end

    action :join_waitlist, Huddlz.Mcp.HuddlResult do
      description "Join your chosen huddl's waitlist when it is full. Requires explicit agreement to waitlist participation; never substitute this for a requested confirmed RSVP. A place may be assigned automatically later."

      argument :huddl_id, :uuid,
        allow_nil?: false,
        description: "The full huddl the person chose."

      argument :confirmed, :boolean,
        allow_nil?: false,
        description: "True only after the person explicitly agreed to join this waitlist."

      run Huddlz.Mcp.Attendance
    end

    action :cancel_rsvp, Huddlz.Mcp.HuddlResult do
      description "Cancel your RSVP or leave the waitlist for a specific huddl. Requires explicit user intent; may release a place to someone else and notify organizers."

      argument :huddl_id, :uuid,
        allow_nil?: false,
        description: "The huddl whose participation you want to cancel."

      argument :confirmed, :boolean,
        allow_nil?: false,
        description: "True only after the person explicitly requested cancellation."

      run Huddlz.Mcp.Attendance
    end

    action :get_huddl, Huddlz.Mcp.HuddlResult do
      description "Read a visible huddl's details, current capacity, and your attendance. Use the stable identifier from search results."

      argument :huddl_id, :uuid,
        allow_nil?: false,
        description: "huddl identifier returned by discovery."

      run Huddlz.Mcp.Attendance
    end

    action :rsvp_huddl, Huddlz.Mcp.HuddlResult do
      description "Reserve your place at a specific huddl. Requires explicit user intent, for example 'sign me up for that yoga huddl'. Clarify ambiguous choices first. May notify organizers. Does not join a group or waitlist."

      argument :huddl_id, :uuid,
        allow_nil?: false,
        description: "The specific huddl the person chose."

      argument :confirmed, :boolean,
        allow_nil?: false,
        description: "True only after the person explicitly requested this RSVP."

      run Huddlz.Mcp.Attendance
    end

    action :search_huddlz, :map do
      description "Find upcoming huddlz near your saved home or supplied coordinates. For tonight, use get_search_context and pass an explicit local-evening UTC window. Results exclude inaccessible huddlz."

      constraints fields: [
                    items: [type: {:array, Huddlz.Mcp.HuddlResult}, allow_nil?: false],
                    next_offset: [
                      type: :integer,
                      description: "Pass as offset for the next page; null means finished."
                    ]
                  ]

      argument :query, :string,
        description: "Words in the title or description.",
        constraints: [max_length: 300]

      argument :starts_at_or_after, :utc_datetime,
        description: "Inclusive start instant, ISO 8601 with UTC offset."

      argument :starts_before, :utc_datetime,
        description: "Exclusive start instant, ISO 8601 with UTC offset."

      argument :latitude, :float,
        constraints: [min: -90, max: 90],
        description: "Search latitude; supply longitude too. Defaults to saved home."

      argument :longitude, :float,
        constraints: [min: -180, max: 180],
        description: "Search longitude; supply latitude too."

      argument :distance_miles, :integer,
        allow_nil?: false,
        default: 25,
        constraints: [min: 5, max: 100],
        description: "Radius in miles."

      argument :anywhere, :boolean,
        allow_nil?: false,
        default: false,
        description: "Explicitly search without a distance restriction."

      argument :relationship, :atom,
        constraints: [one_of: [:attending, :waitlisted, :member, :hosting]],
        description: "Optional relationship to you. attending excludes waitlisted."

      argument :limit, :integer,
        allow_nil?: false,
        default: 20,
        constraints: [min: 1, max: 50],
        description: "Maximum results per page."

      argument :offset, :integer,
        allow_nil?: false,
        default: 0,
        constraints: [min: 0, max: 10_000],
        description: "Pagination offset from a preceding result."

      run Huddlz.Mcp.SearchHuddlz
    end

    action :get_search_context, :map do
      description "Read your saved home search location and the current UTC time. For 'near me', use home unless the person supplied another location. If home is null, ask where to search."

      constraints fields: [
                    home_location: [
                      type: :map,
                      description: "Saved place, or null when unset.",
                      constraints: [
                        fields: [
                          label: [type: :string],
                          latitude: [type: :float],
                          longitude: [type: :float],
                          time_zone: [
                            type: :string,
                            description: "IANA time zone for local date boundaries."
                          ]
                        ]
                      ]
                    ],
                    distance_miles: [type: :integer, description: "Default radius in miles."],
                    now: [
                      type: :utc_datetime,
                      description:
                        "Current UTC time; resolve tonight in the search location's zone."
                    ]
                  ]

      run Huddlz.Mcp.SearchContext
    end
  end

  policies do
    policy always() do
      authorize_if actor_present()
    end
  end
end
