if Code.ensure_loaded?(Mox) do
  Mox.defmock(Huddlz.MockGeocoding, for: Huddlz.Geocoding)
end
