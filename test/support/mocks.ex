if Code.ensure_loaded?(Mox) do
  Mox.defmock(Huddlz.MockStorage, for: Huddlz.Storage)
  Mox.defmock(Huddlz.MockGeocoding, for: Huddlz.Geocoding)
  Mox.defmock(Huddlz.MockPlaces, for: Huddlz.Places)
end
