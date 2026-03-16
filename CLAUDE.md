# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Routinely is an iOS app for tracking daily routines across 8 time slots (3-hour intervals). Users schedule activities for specific weekdays and time slots, then mark them complete. Activities reset weekly based on calendar week boundaries.

## Build Commands

```bash
# Build for iOS Simulator (iPhone 17 Pro is primary test device)
xcodebuild -project Routinely.xcodeproj -scheme Routinely -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build widget extension
xcodebuild -project Routinely.xcodeproj -scheme RoutinelyWidgets -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Open in Xcode
open Routinely.xcodeproj
```

## Architecture

### Data Models (SwiftData)

Four core models in `Routinely/Models/`:

- **Activity** (`Activity.swift`): Name, icon (SF Symbol), color (hex), sort order. Relationships to time slots and completions.
- **ActivityTimeSlot** (`ActivityTimeSlot.swift`): Join model linking Activity to weekday (1-7) and TimeSlot.
- **Completion** (`Completion.swift`): Records when an activity was completed for a specific weekday/time slot.
- **UserPreferences** (`UserPreferences.swift`): First weekday, 24h clock preference, locale override.

**TimeSlot enum** (`TimeSlot.swift`): 8 cases (rawValue 0-7) for 3-hour intervals. Has `current` static property that calculates from current hour. Not a SwiftData model - stored as Int in database.

**Week numbering**: Uses `yearForWeekOfYear` and `weekOfYear` calendar components. Completions are scoped to current week; older completions naturally age out without cleanup.

### App Groups & Data Sharing

App Group identifier: `group.com.medlund.Routinely`

Both app and widget share SwiftData via App Group:
```swift
// In RoutinelyApp.swift
ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic,
    groupContainer: .identifier("group.com.medlund.Routinely")
)
```

Widget uses `.modelContainer(for:)` modifier with same model types.

### Project Structure

```
Routinely/
├── App/
│   ├── RoutinelyApp.swift          // ModelContainer setup with App Group
│   └── RoutinelyView.swift          // TabView (Current + Activities)
├── Models/
│   ├── Activity.swift               // Includes addSamples() for dev data
│   ├── ActivityTimeSlot.swift
│   ├── Completion.swift
│   ├── TimeSlot.swift               // Enum with display helpers
│   └── UserPreferences.swift
├── Features/
│   ├── Activities/
│   │   ├── ActivityListView.swift   // List with "Load Sample Activities" button
│   │   ├── ActivityRowView.swift
│   │   └── ActivityFormView.swift    // Uses SFSymbolPicker from SFSymbols package
│   ├── TimeSlots/
│   │   ├── TimeSlotView.swift       // Current time slot with timer-based updates
│   │   └── TimeSlotPickerView.swift
│   └── Completions/
│       └── CompletionButton.swift    // Toggles completion, updates badge
└── Services/
    ├── BadgeManager.swift            // App icon badge count
    └── NotificationScheduler.swift   // Silent notifications for badge updates

RoutinelyWidgets/                    // Separate target, shares App Group
├── CurrentTimeSlotWidget.swift      // Uses @Query + .modelContainer()
├── ActivityIntent.swift              // AppIntents (placeholder)
└── RoutinelyWidgetBundle.swift
```

### Key Implementation Patterns

**SwiftData Queries**: Cannot use TimeSlot in #Predicate (not supported). Always fetch all and filter in memory:
```swift
let allSlots = try? context.fetch(FetchDescriptor<ActivityTimeSlot>())
let slots = allSlots.filter { $0.weekday == currentWeekday && $0.timeSlot == currentTimeSlot }
```

**Widget Data Flow**: Widget uses `@Query` property wrapper + `.modelContainer()` modifier. Provider only creates timeline entries; view handles data fetching.

**Badge Updates**:
- `BadgeManager.updateBadge()` calculates incomplete activities for current time slot
- Called from `CompletionButton.toggleCompletion()` when completing current slot activities
- `TimeSlotView` schedules silent notifications at each time slot boundary (00:00, 03:00, 06:00, etc.) via `scheduleTimeSlotNotifications()`
- Scene phase change to `.background` triggers notification scheduling

**Time Slot Changes**: `TimeSlotView` has a 60-second timer that checks if `TimeSlot.current` changed and updates with animation.

### Dependencies

- **SFSymbols** (`https://github.com/simonbs/SFSymbols`): SF Symbol picker in ActivityFormView
  - Usage: `SFSymbolPicker("Icon", selection: $icon)`

### Sample Data

`Activity.addSamples(to:)` creates 7 activities with varied schedules. Called from "Load Sample Activities" button in ActivityListView when no activities exist.

### Widget Limitations

Widget timeline updates at time slot boundaries (every 3 hours). Widget cannot directly toggle completions - `widgetURL` opens the app with URL pattern `routinely://complete?activity=UUID&timeSlot=Int`.

### Testing Notes

- Primary test device: iPhone 17 Pro simulator
- If data store gets corrupted, app deletes and recreates container (DEBUG builds only)
- Sample data can be regenerated via button in Activities tab
