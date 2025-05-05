defmodule Huddlz.Soirees do
  use Ash.Domain,
    otp_app: :huddlz

  resources do
    resource Huddlz.Soirees.Soiree do
      define :get_upcoming, action: :upcoming
      define :search, action: :search, args: [:query]
      define :get_by_status, action: :by_status, args: [:status]
    end
  end
end