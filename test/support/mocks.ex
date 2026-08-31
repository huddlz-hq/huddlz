if Code.ensure_loaded?(Mox) do
  Mox.defmock(Huddlz.MockGeocoding, for: Huddlz.Geocoding)
  Mox.defmock(Huddlz.MockPlaces, for: Huddlz.Places)
  Mox.defmock(Huddlz.MockCalendarClock, for: Huddlz.Calendar.Clock)
end
