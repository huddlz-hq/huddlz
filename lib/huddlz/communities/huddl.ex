defmodule Huddlz.Communities.Huddl do
  @moduledoc """
  A huddl is a gathering within the huddlz platform.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban, AshJsonApi.Resource, AshGraphql.Resource],
    primary_read_warning?: false

  graphql do
    type :huddl

    queries do
      get :get_huddl, :read
      list :search_huddlz, :search
      list :upcoming_huddlz, :upcoming
      list :past_huddlz, :past
      list :huddlz_in_group, :by_group
    end

    mutations do
      create :create_huddl, :create
      update :update_huddl, :update
      update :publish_huddl, :publish
      update :cancel_huddl, :cancel
      update :rsvp_to_huddl, :rsvp
      update :cancel_rsvp_to_huddl, :cancel_rsvp
      destroy :delete_huddl, :destroy
    end
  end

  json_api do
    type "huddl"

    routes do
      base "/huddlz"

      get :read
      index :search
      index :upcoming, route: "/upcoming"
      index :past, route: "/past"
      index :by_group, route: "/by_group"
      post :create
      patch :update
      patch :publish, route: "/:id/publish"
      patch :cancel, route: "/:id/cancel"
      patch :rsvp, route: "/:id/rsvp"
      patch :cancel_rsvp, route: "/:id/cancel_rsvp"
      delete :destroy
    end
  end

  oban do
    triggers do
      trigger :send_24h_reminder do
        action :send_24h_reminder
        read_action :due_for_24h_reminder
        scheduler_cron "*/2 * * * *"
        queue :notifications
        worker_module_name Huddlz.Notifications.Workers.HuddlReminder24h
        scheduler_module_name Huddlz.Notifications.Workers.HuddlReminder24hScheduler
      end

      trigger :send_1h_reminder do
        action :send_1h_reminder
        read_action :due_for_1h_reminder
        scheduler_cron "*/2 * * * *"
        queue :notifications
        worker_module_name Huddlz.Notifications.Workers.HuddlReminder1h
        scheduler_module_name Huddlz.Notifications.Workers.HuddlReminder1hScheduler
      end

      trigger :complete_huddl do
        action :complete
        read_action :due_for_completion
        scheduler_cron "*/2 * * * *"
        queue :default
        worker_module_name Huddlz.Communities.Workers.CompleteHuddl
        scheduler_module_name Huddlz.Communities.Workers.CompleteHuddlScheduler
      end
    end
  end

  postgres do
    table "huddlz"
    repo Huddlz.Repo

    references do
      reference :group, on_delete: :delete
      reference :group_location, on_delete: :nilify
      reference :published_by, on_delete: :nilify
      reference :cancelled_by, on_delete: :nilify
    end

    custom_indexes do
      index [:lifecycle_state, :ends_at],
        name: "huddlz_lifecycle_state_ends_at_index"

      index "ST_MakePoint(longitude, latitude)",
        name: "huddlz_location_gist_index",
        using: "GIST",
        where: "latitude IS NOT NULL AND longitude IS NOT NULL"
    end

    check_constraints do
      check_constraint :lifecycle_state,
                       "huddlz_valid_lifecycle_state",
                       check:
                         "lifecycle_state IN ('draft', 'published', 'cancelled', 'completed')",
                       message: "must be draft, published, cancelled, or completed"
    end
  end

  actions do
    destroy :destroy do
      primary? true
      require_atomic? false
    end

    read :read do
      primary? true
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
    end

    create :create do
      primary? true

      accept [
        :title,
        :description,
        :starts_at,
        :ends_at,
        :event_type,
        :virtual_link,
        :is_private,
        :thumbnail_url,
        :max_attendees,
        :group_id,
        :group_location_id,
        :huddl_template_id,
        :lifecycle_state
      ]

      # Virtual arguments for form inputs
      argument :date, :date, allow_nil?: true
      argument :start_time, :time, allow_nil?: true

      argument :duration_minutes, :integer do
        allow_nil? true
        constraints min: 15, max: 1440
      end

      argument :is_recurring, :boolean, default: false
      argument :repeat_until, :date, allow_nil?: true
      argument :frequency, :string, allow_nil?: true

      argument :pending_image_id, :uuid, allow_nil?: true, public?: false

      validate one_of(:lifecycle_state, [:draft, :published])
      validate Huddlz.Communities.Huddl.Validations.FutureDateValidation

      validate present(:frequency) do
        where argument_equals(:is_recurring, true)
        message "is required for recurring huddlz"
      end

      validate present(:repeat_until) do
        where argument_equals(:is_recurring, true)
        message "is required for recurring huddlz"
      end

      change Huddlz.Communities.Huddl.Changes.SetCreatorToActor
      change Huddlz.Communities.Huddl.Changes.AddCreatorAsAttendee
      change Huddlz.Communities.Huddl.Changes.DefaultTimeZoneFromGroup
      change Huddlz.Communities.Huddl.Changes.ApplySavedLocation
      change Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs
      change Huddlz.Communities.Huddl.Changes.ForcePrivateForPrivateGroups
      change Huddlz.Communities.Huddl.Changes.AssignPendingImage
      change Huddlz.Communities.Huddl.Changes.AddHuddlTemplate
      change Huddlz.Communities.Huddl.Changes.ClearUnusedLocationFields
      change Huddlz.Communities.Huddl.Changes.DefaultLocationFromGroup
      change Huddlz.Communities.Huddl.Changes.SetInitialLifecycleTimestamps
      change Huddlz.Communities.Huddl.Changes.NotifyNewInGroup
    end

    update :publish do
      description "Publish a draft huddl. Repeated publication is a no-op."
      require_atomic? false

      change {Huddlz.Communities.Huddl.Changes.TransitionLifecycle, to: :published}
      change Huddlz.Communities.Huddl.Changes.NotifyNewInGroup
    end

    update :cancel do
      description "Cancel a published huddl without deleting its details or RSVP history."
      require_atomic? false

      argument :cancellation_reason, :string do
        allow_nil? true
        constraints allow_empty?: true, max_length: 1000
      end

      change {Huddlz.Communities.Huddl.Changes.TransitionLifecycle, to: :cancelled}
      change Huddlz.Communities.Huddl.Changes.NotifyCancelled
    end

    update :complete do
      description "Persist completion after a published huddl ends."
      require_atomic? false

      change {Huddlz.Communities.Huddl.Changes.TransitionLifecycle, to: :completed}
    end

    update :update do
      primary? true

      accept [
        :title,
        :description,
        :starts_at,
        :ends_at,
        :event_type,
        :virtual_link,
        :is_private,
        :thumbnail_url,
        :max_attendees,
        :group_location_id,
        :huddl_template_id
      ]

      # Virtual arguments for form inputs
      argument :date, :date, allow_nil?: true
      argument :start_time, :time, allow_nil?: true

      argument :duration_minutes, :integer do
        allow_nil? true
        constraints min: 15, max: 1440
      end

      argument :repeat_until, :date
      argument :frequency, :string

      argument :edit_type, :string do
        constraints allow_empty?: true
        default "instance"
      end

      argument :suppress_update_notification, :boolean do
        allow_nil? false
        default false
        public? false
      end

      require_atomic? false

      validate present(:frequency) do
        where argument_equals(:edit_type, "all")
        message "is required when editing the whole series"
      end

      validate present(:repeat_until) do
        where argument_equals(:edit_type, "all")
        message "is required when editing the whole series"
      end

      change Huddlz.Communities.Huddl.Changes.DefaultTimeZoneFromGroup
      change Huddlz.Communities.Huddl.Changes.ApplySavedLocation
      change Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs
      change Huddlz.Communities.Huddl.Changes.ForcePrivateForPrivateGroups
      change Huddlz.Communities.Huddl.Changes.ClearUnusedLocationFields
      change Huddlz.Communities.Huddl.Changes.EditRecurringHuddlz
      change Huddlz.Communities.Huddl.Changes.DefaultLocationFromGroup
      change Huddlz.Communities.Huddl.Changes.EnforceCapacityFloor
      change Huddlz.Communities.Huddl.Changes.ResetReminderStamps
      change Huddlz.Communities.Huddl.Changes.NotifyMeaningfulUpdate
      change Huddlz.Communities.Huddl.Changes.PromoteOnCapacityIncrease
    end

    read :by_status do
      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:draft, :upcoming, :in_progress, :completed, :cancelled]
      end

      filter expr(status == ^arg(:status))
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
    end

    read :upcoming do
      filter expr(lifecycle_state == :published and ends_at > now())
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :asc])
    end

    read :past do
      filter expr(
               lifecycle_state == :completed or
                 (lifecycle_state == :published and ends_at < now())
             )

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :desc])
    end

    read :search do
      argument :query, :ci_string do
        allow_nil? true
      end

      argument :date_filter, :atom do
        allow_nil? false
        default :upcoming
        constraints one_of: [:upcoming, :this_week, :this_month, :past, :all]
      end

      argument :event_type, :atom do
        allow_nil? true
        constraints one_of: [:in_person, :virtual, :hybrid]
      end

      argument :search_latitude, :float, allow_nil?: true
      argument :search_longitude, :float, allow_nil?: true

      argument :distance_miles, :integer do
        allow_nil? true
        default 25
        constraints min: 5, max: 100
      end

      argument :relationship, :atom do
        description """
        Restrict results to huddlz the actor hosts (creator), is attending
        (confirmed RSVP), or is on the waitlist for. :attending excludes
        waitlisted rows; use :waitlisted to find those instead.
        """

        allow_nil? true
        constraints one_of: [:hosting, :attending, :waitlisted]
      end

      argument :sort, :atom do
        description "Result ordering. :soonest sorts upcoming huddlz first; :newest sorts by recently created."
        allow_nil? true
        default :soonest
        constraints one_of: [:soonest, :newest]
      end

      argument :search_time_zone, :string do
        description "IANA time zone used for relative calendar date filters"
        allow_nil? true
        constraints min_length: 1, max_length: 100
      end

      argument :now, :utc_datetime do
        allow_nil? true
        public? false
      end

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 20

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare Huddlz.Communities.Huddl.Preparations.ApplySearchFilters
    end

    read :by_group do
      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(
               lifecycle_state == :published and group_id == ^arg(:group_id) and
                 starts_at > now()
             )

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 10

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :asc])
    end

    read :past_by_group do
      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(
               group_id == ^arg(:group_id) and
                 (lifecycle_state == :completed or
                    (lifecycle_state == :published and ends_at < now()))
             )

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 10

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :desc])
    end

    read :siblings_in_series do
      description """
      Every later instance in the same recurring series, used internally when
      regenerating a series ("edit all"). Deliberately omits the
      FilterByVisibility preparation: series regeneration must find every
      instance regardless of the editor's visibility (e.g. a private series, or
      an admin who isn't a group member). Invoke only with `authorize?: false`.
      """

      argument :huddl_template_id, :uuid, allow_nil?: false
      argument :starting_after, :utc_datetime, allow_nil?: false

      filter expr(
               huddl_template_id == ^arg(:huddl_template_id) and
                 starts_at > ^arg(:starting_after)
             )
    end

    read :get_for_recurrence do
      description """
      Internal, visibility-free fetch of a single huddl by id for the
      recurring-series worker, which runs with no actor. Skips
      FilterByVisibility so a private series can still be regenerated. Invoke
      only with `authorize?: false`.
      """

      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    read :get_for_lifecycle_transition do
      description """
      Internal visibility-free fetch used while a lifecycle transition holds a
      row lock. Invoke only with `authorize?: false`.
      """

      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    read :huddlz_for_organizer do
      description """
      Huddlz across every group the actor owns or organizes.

      Note: this is intentionally broader than `Group.get_by_owner` (owner-only).
      The Workspace Groups + Members tabs still scope to owned groups; if those
      surfaces should ever match this action's reach, parallel them with a new
      `groups_for_organizer` action rather than widening `get_by_owner`.
      """

      argument :state, :atom do
        allow_nil? false
        default :published
        constraints one_of: [:live, :draft, :published, :cancelled, :past]
      end

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility

      filter expr(
               group.owner_id == ^actor(:id) or
                 exists(group.group_members, user_id == ^actor(:id) and role == :organizer)
             )

      filter expr(
               (^arg(:state) in [:live, :published] and lifecycle_state == :published and
                  ends_at > now()) or
                 (^arg(:state) == :draft and lifecycle_state == :draft) or
                 (^arg(:state) == :cancelled and lifecycle_state == :cancelled) or
                 (^arg(:state) == :past and
                    (lifecycle_state == :completed or
                       (lifecycle_state == :published and ends_at < now())))
             )
    end

    update :rsvp do
      description "RSVP to this huddl as the current actor"
      require_atomic? false

      change Huddlz.Communities.Huddl.Changes.Rsvp
      change Huddlz.Communities.Huddl.Changes.NotifyRsvpReceived
      change Huddlz.Communities.Huddl.Changes.NotifyRsvpConfirmation
    end

    update :cancel_rsvp do
      description "Cancel RSVP or leave waitlist for this huddl as the current actor"
      require_atomic? false

      change Huddlz.Communities.Huddl.Changes.CancelRsvp
      change Huddlz.Communities.Huddl.Changes.PromoteFromWaitlist
      change Huddlz.Communities.Huddl.Changes.NotifyRsvpCancelled
      change Huddlz.Communities.Huddl.Changes.NotifyWaitlistPromoted
    end

    update :join_waitlist do
      description "Join the waitlist for this huddl as the current actor when full"
      require_atomic? false

      change Huddlz.Communities.Huddl.Changes.JoinWaitlist
    end

    read :due_for_24h_reminder do
      description "Huddlz starting in the next 24 hours that have not yet had a 24h reminder sent."

      pagination keyset?: true, required?: false, default_limit: 100

      filter expr(
               lifecycle_state == :published and starts_at > now() and
                 starts_at < from_now(24, :hour) and
                 is_nil(reminder_24h_sent_at)
             )
    end

    read :due_for_1h_reminder do
      description "Huddlz starting in the next hour that have not yet had a 1h reminder sent."

      pagination keyset?: true, required?: false, default_limit: 100

      filter expr(
               lifecycle_state == :published and starts_at > now() and
                 starts_at < from_now(1, :hour) and
                 is_nil(reminder_1h_sent_at)
             )
    end

    read :due_for_completion do
      description "Published huddlz whose scheduled end time has passed."

      pagination keyset?: true, required?: false, default_limit: 100
      filter expr(lifecycle_state == :published and ends_at <= now())
    end

    update :send_24h_reminder do
      description "Mark and fan out the 24-hour reminder for this huddl. Invoked by the AshOban scheduler."
      require_atomic? false

      change {Huddlz.Communities.Huddl.Changes.SendReminder, kind: :h24}
    end

    update :send_1h_reminder do
      description "Mark and fan out the 1-hour reminder for this huddl. Invoked by the AshOban scheduler."
      require_atomic? false

      change {Huddlz.Communities.Huddl.Changes.SendReminder, kind: :h1}
    end
  end

  policies do
    # Admins can do anything
    bypass always() do
      description "Admins can do anything"
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Creation policies
    policy action(:create) do
      description "Only group owners and organizers can create huddls"
      authorize_if Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer
    end

    # Read policies - visibility filtering is handled by the FilterByVisibility preparation
    # on each read action, which adds database-level filters. We authorize all reads here
    # and rely on the preparation to restrict results.
    policy action_type(:read) do
      description "Users can read huddlz they have access to (filtered by preparation)"
      authorize_if always()
    end

    # Background lifecycle and reminder actions run through AshOban with no actor.
    policy action([:complete, :send_24h_reminder, :send_1h_reminder]) do
      description "Scheduled huddl maintenance runs from background workers"
      authorize_if always()
    end

    # RSVP, cancellation, and waitlist all share the same visibility rule
    policy action([:rsvp, :cancel_rsvp, :join_waitlist]) do
      description "Users can manage their attendance on huddlz they have access to"
      forbid_unless expr(lifecycle_state == :published)
      authorize_if expr(is_private == false and group.is_public == true)
      authorize_if expr(exists(group.members, id == ^actor(:id)))
    end

    policy action(:update) do
      description "Only group owners and organizers can update active huddlz"

      forbid_unless expr(
                      lifecycle_state == :draft or
                        (lifecycle_state == :published and ends_at > now())
                    )

      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(group.group_members, user_id == ^actor(:id) and role == :organizer)
                   )
    end

    policy action([:publish, :cancel]) do
      description "Only group owners and organizers can change a huddl lifecycle"
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(group.group_members, user_id == ^actor(:id) and role == :organizer)
                   )
    end

    policy action(:destroy) do
      description "Only group owners and organizers can delete an unpublished draft"
      forbid_unless expr(lifecycle_state == :draft)
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(group.group_members, user_id == ^actor(:id) and role == :organizer)
                   )
    end
  end

  # changes section removed - validation is handled by FutureDateValidation module

  validations do
    validate Huddlz.TimeZone.Validation do
      where action_is([:create, :update])
    end

    validate string_length(:title, min: 3, max: 200) do
      message "Must be between 3 and 200 characters"
    end

    validate compare(:max_attendees, greater_than_or_equal_to: 1) do
      message "Must be at least 1"
    end

    validate {Huddlz.Communities.Huddl.Validations.WebUrlValidation, attribute: :virtual_link}

    validate compare(:ends_at, greater_than: :starts_at) do
      message "must be after the start time"
    end

    # Scoped to the primary actions so RSVPs and lifecycle transitions on
    # legacy huddlz that predate the address book keep working.
    validate present(:group_location_id) do
      where [action_is([:create, :update]), one_of(:event_type, [:in_person, :hybrid])]
      message "is required for in-person and hybrid huddlz"
    end

    validate present([:virtual_link]) do
      where attribute_equals(:event_type, :virtual)
      message "is required for virtual huddlz"
    end

    validate present([:virtual_link]) do
      where attribute_equals(:event_type, :hybrid)
      message "is required for hybrid huddlz"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 5000
    end

    attribute :starts_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :ends_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :time_zone, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :event_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:in_person, :virtual, :hybrid]
      default :in_person
    end

    attribute :physical_location, :string do
      allow_nil? true
      public? true
      constraints max_length: 500
    end

    attribute :virtual_link, :string do
      allow_nil? true
      sensitive? true
      constraints max_length: 2048
    end

    attribute :is_private, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :thumbnail_url, :string do
      allow_nil? true
      public? true
    end

    attribute :max_attendees, :integer do
      allow_nil? true
      public? true
    end

    attribute :lifecycle_state, :atom do
      allow_nil? false
      public? true
      default :published
      constraints one_of: [:draft, :published, :cancelled, :completed]
      description "Explicit organizer-controlled lifecycle state."
    end

    attribute :published_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :cancelled_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :cancellation_reason, :string do
      allow_nil? true
      public? true
      constraints max_length: 1000
    end

    attribute :latitude, :float do
      allow_nil? true
      description "Geocoded latitude of physical_location or inherited from group"
      constraints min: -90, max: 90
    end

    attribute :longitude, :float do
      allow_nil? true
      description "Geocoded longitude of physical_location or inherited from group"
      constraints min: -180, max: 180
    end

    attribute :reminder_24h_sent_at, :utc_datetime_usec do
      allow_nil? true
      public? false

      description "Stamped when the 24-hour reminder has been sent for this huddl. Reset to nil when starts_at changes."
    end

    attribute :reminder_1h_sent_at, :utc_datetime_usec do
      allow_nil? true
      public? false

      description "Stamped when the 1-hour reminder has been sent for this huddl. Reset to nil when starts_at changes."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :creator, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    belongs_to :published_by, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? true
      primary_key? false
    end

    belongs_to :cancelled_by, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? true
      primary_key? false
    end

    belongs_to :group, Huddlz.Communities.Group do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    belongs_to :group_location, Huddlz.Communities.GroupLocation do
      attribute_type :uuid
      allow_nil? true
      primary_key? false
    end

    belongs_to :huddl_template, Huddlz.Communities.HuddlTemplate do
      attribute_type :uuid
      allow_nil? true
      primary_key? false
    end

    has_many :attendees, Huddlz.Communities.HuddlAttendee do
      destination_attribute :huddl_id
    end

    has_many :huddl_images, Huddlz.Communities.HuddlImage do
      destination_attribute :huddl_id
    end
  end

  calculations do
    calculate :status, :atom do
      calculation expr(
                    cond do
                      lifecycle_state == :draft -> :draft
                      lifecycle_state == :cancelled -> :cancelled
                      lifecycle_state == :completed -> :completed
                      starts_at > now() -> :upcoming
                      ends_at < now() -> :completed
                      true -> :in_progress
                    end
                  )
    end

    calculate :visible_virtual_link, :string do
      description "Returns the virtual link only if the actor has RSVPed to the huddl"

      calculation expr(
                    if lifecycle_state == :published and
                         exists(attendees, user_id == ^actor(:id)) do
                      virtual_link
                    else
                      nil
                    end
                  )
    end

    calculate :is_publicly_visible, :boolean do
      description "Whether the huddl is visible to everyone (public huddl in public group)"
      calculation expr(is_private == false and group.is_public == true)
    end

    calculate :at_capacity, :boolean do
      description "Whether the huddl has reached max_attendees (no open seats remain)"
      calculation expr(not is_nil(max_attendees) and rsvp_count >= max_attendees)
    end

    calculate :display_image_url, :string do
      description "Returns huddl's image, falling back to group image if none"
      calculation Huddlz.Communities.Huddl.Calculations.DisplayImageUrl
    end
  end

  aggregates do
    count :rsvp_count, :attendees do
      filter expr(is_nil(waitlisted_at))
    end

    count :waitlist_count, :attendees do
      filter expr(not is_nil(waitlisted_at))
    end

    first :current_image_url, :huddl_images, :thumbnail_path do
      description "Returns the thumbnail path of the huddl's current image"
      sort inserted_at: :desc
      filter expr(is_nil(deleted_at))
    end
  end
end
