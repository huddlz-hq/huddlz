# Changelog

All notable changes to the Huddlz project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New date/time/duration picker components for huddl creation
  - Separate date picker with future date validation
  - Time picker with 15-minute increment suggestions and manual entry support
  - Duration selector with preset options (30m, 1h, 1.5h, 2h, 2.5h, 3h, 4h, 6h)
  - Real-time end time calculation and display
  - Support for events crossing day boundaries

### Changed
- Replaced single datetime-local inputs with three separate inputs for better UX
- Huddl resource now uses virtual arguments (date, start_time, duration_minutes) that calculate starts_at and ends_at
- LiveView form now shows calculated end time dynamically
- Improved user experience for scheduling events with standard time blocks

### Technical Details
- Added `date_picker/1`, `time_picker/1`, and `duration_picker/1` components to CoreComponents
- Created `CalculateDateTimeFromInputs` change module for Ash resource
- Updated HuddlLive.New to handle new form inputs and real-time calculations
- Maintained backward compatibility with existing API endpoints
- No database migration required (using existing starts_at and ends_at fields)

## [0.1.0] - Previous Release
- Initial release with basic huddl creation and management features