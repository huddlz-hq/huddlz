# Define mocks for testing
# This file is only compiled in the test environment

if Code.ensure_loaded?(Mox) do
  Mox.defmock(Huddlz.Geocoding.Mock, for: Huddlz.Geocoding.Behaviour)
end
