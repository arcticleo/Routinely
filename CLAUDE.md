# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Routinely is a multi-platform SwiftUI app for tracking daily routines across iOS, iPadOS, macOS, and visionOS using SwiftData for persistence. Users organize activities into 8 time slots (3-hour intervals) throughout the day. Activities reset weekly to help establish consistent routines.

## Build Commands

Since this is an Xcode project, use `xcodebuild` from the repository root:

```bash
# Build for iOS Simulator
xcodebuild -project Routinely.xcodeproj -scheme Routinely -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for macOS
xcodebuild -project Routinely.xcodeproj -scheme Routinely -destination 'platform=macOS' build

# Run on iOS Simulator (requires device name)
open -a Simulator && xcodebuild -project Routinely.xcodeproj -scheme Routinely -destination 'platform=iOS Simulator,name=iPhone 16' test
```

For development, opening the project in Xcode is recommended:
```bash
open Routinely.xcodeproj
```

## Architecture

### Data Models (SwiftData)

The app uses four core SwiftData models defined in `PLAN.md`:

- **Activity**: Represents a routine activity with name, icon (SF Symbol), sort order. Has relationships to time slots and completions.
- **ActivityTimeSlot**: Join model for many-to-many relationship between Activity and TimeSlot
- **Completion**: Tracks when an activity was completed for a specific time slot
- **UserPreferences**: Stores user settings (first weekday, 24h time format, locale, time slot customization)

Time slots are defined as a `TimeSlot` enum with 8 cases (3-hour intervals from 00:00-24:00), not stored in the database.

### Project Structure

Intended organization (per `PLAN.md`):

```
Routinely/
├── App/
│   ├── RoutinelyApp.swift          // App entry with ModelContainer
│   └── RoutinelyView.swift          // Root view (NavigationSplitView/TabView)
├── Models/
│   ├── Activity.swift, ActivityTimeSlot.swift, Completion.swift, TimeSlot.swift, UserPreferences.swift
├── Features/
│   ├── Activities/ (ActivityListView, ActivityRowView, ActivityFormView)
│   ├── TimeSlots/ (TimeSlotView, TimeSlotActivitiesView, TimeSlotPickerView)
│   └── Completions/ (CompletionButton)
├── Widgets/                          // Home/Lock screen widgets (AppIntent-based)
├── Utilities/
└── Resources/
    └── Assets.xcassets
```

### Platform-Specific UI Patterns

- **iOS**: Uses `TabView` for navigation between Current and Activities tabs
- **iPadOS/macOS**: Uses `NavigationSplitView` with sidebar for time slots
- **visionOS**: Ornaments for time slot navigation, spatial hover effects

### Key Implementation Details

**Weekly Reset Logic**: Completions are scoped to the current week using `Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)`. No cleanup needed; older completions naturally age out.

**SwiftData Model Container**: The app sets up a shared `ModelContainer` in `RoutinelyApp.swift` with `cloudKitDatabase: .automatic` for optional iCloud sync.

**Time Slot Display**: Uses `DateIntervalFormatter` with `.short` time style for locale-aware formatting (respects 12/24h preferences automatically).

**Localization**: String Catalogs (`.xcstrings`) with dot-notation keys like `activity.add.title` and `timeslot.morning.label`.

## Testing

Tests should cover:
- Time slot calculations and week boundary conditions
- Completion query predicates with different calendar first-weekday settings
- Activity creation/editing flows

Run tests via Xcode or:
```bash
xcodebuild -project Routinely.xcodeproj -scheme Routinely test -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Current State

This is a fresh Xcode 16+ project (Swift 6.2, iOS 26+). The PLAN.md at repository root contains the detailed implementation spec. Current implementation consists only of boilerplate `RoutinelyApp.swift` and `ContentView.swift`.

The project uses modern Xcode features:
- `PBXFileSystemSynchronizedRootGroup` for automatic file tracking
- SwiftData for persistence
- String Catalogs for localization
- Multi-platform deployment (iOS, iPadOS, macOS, visionOS)
