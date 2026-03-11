# Routinely App Plan

A multi-platform SwiftUI app for tracking daily routines across iOS, iPadOS, macOS, and visionOS using SwiftData for persistence.

---

## Overview

Routinely helps users build habits by organizing activities into time slots throughout the day. Activities reset weekly, creating a recurring pattern that helps establish consistent routines.

---

## Architecture

### Data Models

```swift
// Activity.swift
@Model
class Activity {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var createdAt: Date
    var sortOrder: Int

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ActivityTimeSlot.activity)
    var timeSlots: [ActivityTimeSlot]?

    @Relationship(deleteRule: .cascade, inverse: \Completion.activity)
    var completions: [Completion]?

    init(name: String, icon: String) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.sortOrder = 0
    }

    /// Check if activity is completed for the given time slot
    /// - Parameters:
    ///   - timeSlot: The time slot to check
    ///   - date: The date within the target week (defaults to today)
    ///   - calendar: The calendar to use for week boundaries (respects user's firstWeekday preference)
    func isCompleted(for timeSlot: TimeSlot, on date: Date = Date(), using calendar: Calendar? = nil) -> Bool {
        guard let completions = completions else { return false }
        let cal = calendar ?? Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!

        return completions.contains { completion in
            completion.timeSlot == timeSlot &&
            completion.completedAt >= weekStart &&
            completion.completedAt < weekEnd
        }
    }
}

// ActivityTimeSlot.swift (Join model for many-to-many)
@Model
class ActivityTimeSlot {
    @Attribute(.unique) var id: UUID
    var timeSlot: TimeSlot

    @Relationship
    var activity: Activity?

    init(timeSlot: TimeSlot, activity: Activity) {
        self.id = UUID()
        self.timeSlot = timeSlot
        self.activity = activity
    }
}

// Completion.swift
@Model
class Completion {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var timeSlot: TimeSlot

    @Relationship
    var activity: Activity?

    init(timeSlot: TimeSlot, activity: Activity, completedAt: Date = Date()) {
        self.id = UUID()
        self.timeSlot = timeSlot
        self.activity = activity
        self.completedAt = completedAt
    }
}

// TimeSlot.swift
enum TimeSlot: Int, Codable, CaseIterable {
    case midnightTo3am = 0    // 00:00 - 03:00
    case earlyMorning = 1    // 03:00 - 06:00
    case morning = 2         // 06:00 - 09:00
    case lateMorning = 3     // 09:00 - 12:00
    case afternoon = 4       // 12:00 - 15:00
    case lateAfternoon = 5   // 15:00 - 18:00
    case evening = 6         // 18:00 - 21:00
    case night = 7           // 21:00 - 00:00

    var startHour: Int {
        return self.rawValue * 3
    }

    var endHour: Int {
        return ((self.rawValue + 1) * 3) % 24
    }

    // Localized display using DateIntervalFormatter (respects device locale)
    func displayName(using preferences: UserPreferences? = nil) -> String {
        let formatter = DateIntervalFormatter()
        formatter.timeStyle = .short

        // Use user preference if set, otherwise device locale
        if let localeId = preferences?.localeIdentifier {
            formatter.locale = Locale(identifier: localeId)
        }

        let start = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: Date())!
        let end = Calendar.current.date(bySettingHour: endHour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: start, to: end)
    }

    // Default color for each time slot (user-overridable in settings)
    var defaultColor: String {
        switch self {
        case .midnightTo3am: return "#1a1a2e"    // Deep night blue
        case .earlyMorning: return "#16213e"   // Dark blue
        case .morning: return "#f4d03f"        // Morning yellow
        case .lateMorning: return "#f39c12"    // Late morning orange
        case .afternoon: return "#e74c3c"      // Afternoon red
        case .lateAfternoon: return "#9b59b6"  // Late afternoon purple
        case .evening: return "#3498db"        // Evening blue
        case .night: return "#2c3e50"          // Night slate
        }
    }

    // Default icon/SF Symbol for each time slot (user-overridable in settings)
    var defaultIcon: String {
        switch self {
        case .midnightTo3am: return "moon.stars.fill"
        case .earlyMorning: return "moon.fill"
        case .morning: return "sunrise.fill"
        case .lateMorning: return "sun.max.fill"
        case .afternoon: return "sun.max.fill"
        case .lateAfternoon: return "sunset.fill"
        case .evening: return "moon.fill"
        case .night: return "moon.zzz.fill"
        }
    }

    static var current: TimeSlot {
        let hour = Calendar.current.component(.hour, from: Date())
        return TimeSlot(rawValue: hour / 3) ?? .night
    }
}

// UserPreferences.swift
@Model
class UserPreferences {
    @Attribute(.unique) var id: UUID

    // First day of week: 1 = Sunday, 2 = Monday, etc.
    // Defaults to device setting via Calendar.current.firstWeekday
    var firstWeekday: Int?

    // Time format preference: nil = follow device locale, true = 24h, false = 12h
    var use24HourClock: Bool?

    // Locale override: nil = follow device, otherwise use this locale identifier
    var localeIdentifier: String?

    // Time slot customization (user overrides for defaults)
    var timeSlotColors: [Int: String]?  // timeSlot.rawValue -> hex color
    var timeSlotIcons: [Int: String]?   // timeSlot.rawValue -> SF Symbol name

    init() {
        self.id = UUID()
    }

    /// Returns the user's preferred calendar, respecting firstWeekday setting
    var calendar: Calendar {
        var cal = Calendar.current
        if let firstWeekday = firstWeekday {
            cal.firstWeekday = firstWeekday
        }
        if let localeId = localeIdentifier {
            cal.locale = Locale(identifier: localeId)
        }
        return cal
    }

    /// Returns the appropriate time style based on user preference
    var timeStyle: DateFormatter.Style {
        // DateIntervalFormatter doesn't support explicit 12/24h toggle,
        // but we can influence it via locale. For strict control,
        // we'd need a custom formatter in the UI layer.
        return .short
    }
}
```

---

## App Structure

### Project Organization

```
Routinely/
├── App/
│   ├── RoutinelyApp.swift          // App entry point with ModelContainer
│   └── RoutinelyView.swift          // Root view with NavigationSplitView
├── Models/
│   ├── Activity.swift
│   ├── ActivityTimeSlot.swift
│   ├── Completion.swift
│   ├── TimeSlot.swift
│   └── UserPreferences.swift
├── Features/
│   ├── Activities/
│   │   ├── ActivityListView.swift
│   │   ├── ActivityRowView.swift
│   │   └── ActivityFormView.swift   // Add/Edit activity
│   ├── TimeSlots/
│   │   ├── TimeSlotView.swift       // Current time slot view
│   │   ├── TimeSlotActivitiesView.swift
│   │   └── TimeSlotPickerView.swift // Visual time slot selector
│   └── Completions/
│       └── CompletionButton.swift   // Toggle completion state
├── Widgets/
│   ├── RoutinelyWidgetBundle.swift
│   ├── CurrentTimeSlotWidget.swift  // Main widget
│   ├── ActivityIntent.swift         // AppIntent for completion
│   └── Provider.swift               // TimelineProvider
├── Utilities/
│   ├── TimeSlotCalculator.swift
│   └── ViewExtensions.swift
└── Resources/
    └── Assets.xcassets
```

---

## UI Design

### Main Views

#### 1. RoutinelyView (Root)

Uses `NavigationSplitView` for macOS/iPadOS, `TabView` for iOS:

```swift
struct RoutinelyView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            TimeSlotDetailView()
        }
    }
}
```

#### 2. TimeSlotView

Shows activities for the currently selected time slot with visual completion tracking:

```swift
struct TimeSlotView: View {
    let timeSlot: TimeSlot
    @Query(filter: #Predicate<ActivityTimeSlot> { $0.timeSlot == timeSlot })
    private var activityTimeSlots: [ActivityTimeSlot]

    var body: some View {
        VStack(spacing: 0) {
            TimeSlotHeader(timeSlot: timeSlot)

            List(activityTimeSlots.compactMap(\.activity)) { activity in
                ActivityCompletionRow(activity: activity, timeSlot: timeSlot)
            }
        }
    }
}
```

#### 3. ActivityFormView

Form for creating/editing activities with multi-select time slot picker:

```swift
struct ActivityFormView: View {
    @Bindable var activity: Activity
    @State private var selectedTimeSlots: Set<TimeSlot> = []

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $activity.name)
                IconPicker(selection: $activity.icon)
            }

            Section("Schedule") {
                TimeSlotGridPicker(selection: $selectedTimeSlots)
            }
        }
    }
}
```

---

## Widget Implementation

### Timeline Provider

```swift
struct Provider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 3, to: currentDate)!

        // Update every 3 hours when time slots change
        let entries: [RoutinelyEntry] = [RoutinelyEntry(date: currentDate)]
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RoutinelyEntry: TimelineEntry {
    let date: Date
}
```

### App Intent for Completion

```swift
struct CompleteActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Activity"

    @Parameter(title: "Activity")
    var activity: ActivityEntity

    func perform() async throws -> some IntentResult {
        // Complete the activity using model context
        await completeActivity(activity.id)
        return .result()
    }
}

struct ActivityEntity: AppEntity {
    let id: UUID
    let name: String

    static var defaultQuery = ActivityQuery()
}
```

---

## Platform Considerations

### iOS
- Tab-based navigation with Current/Activities tabs
- Widgets on Home Screen and Lock Screen
- Haptic feedback on completion
- Pull to refresh for current time slot

### iPadOS
- NavigationSplitView with sidebar
- Drag and drop to reorder activities
- Keyboard shortcuts (Space to complete, Cmd+N for new activity)
- Multiple window support (UISceneSession)

### macOS
- Menu bar extra for quick access
- Native toolbar with search
- Right-click context menus
- SwiftUI Table for activity management

### visionOS
- Ornaments for time slot navigation
- Spatial hover effects
- Dimmable background when focusing
- Hand gesture support (pinch to complete)

---

## SwiftData Schema Design

### Model Container Configuration

```swift
@main
struct RoutinelyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Activity.self,
            ActivityTimeSlot.self,
            Completion.self,
            UserPreferences.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic // Optional iCloud sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RoutinelyView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### Migration Strategy

- Use lightweight migrations for simple property changes
- Version schema for breaking changes
- Consider CloudKit sync limitations

---

## Key Implementation Details

### Weekly Reset Logic

Completions are scoped to the current week. No cleanup needed; older completions naturally age out:

```swift
extension Activity {
    func isCompleted(for timeSlot: TimeSlot, using calendar: Calendar = Calendar.current) -> Bool {
        guard let completions = completions else { return false }

        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.yearForWeekOfYear, from: Date())

        return completions.contains { completion in
            let completionWeek = calendar.component(.weekOfYear, from: completion.completedAt)
            let completionYear = calendar.component(.yearForWeekOfYear, from: completion.completedAt)
            return completion.timeSlot == timeSlot &&
                   completionWeek == weekOfYear &&
                   completionYear == year
        }
    }
}
```

### Completion Toggle

```swift
struct CompletionButton: View {
    let activity: Activity
    let timeSlot: TimeSlot
    @Environment(\.modelContext) private var modelContext

    var isCompleted: Bool {
        activity.isCompleted(for: timeSlot)
    }

    var body: some View {
        Button {
            toggleCompletion()
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .symbolRenderingMode(.palette)
                .foregroundStyle(isCompleted ? .white : .secondary, timeSlot.swiftUIColor)
                .font(.title2)
        }
        .buttonStyle(.borderless)
        .contentTransition(.symbolEffect(.replace))
    }

    private func toggleCompletion() {
        if isCompleted {
            // Remove completion for this week
            if let completion = activity.completions?.first(where: {
                $0.timeSlot == timeSlot && Calendar.current.isDate($0.completedAt, equalTo: Date(), toGranularity: .weekOfYear)
            }) {
                modelContext.delete(completion)
            }
        } else {
            // Add completion
            let completion = Completion(timeSlot: timeSlot, activity: activity)
            modelContext.insert(completion)
        }
        try? modelContext.save()
    }
}
```

---

## Localization & Internationalization

### String Catalogs

Use Xcode String Catalogs (`.xcstrings`) for all user-facing strings. Keys use dot-notation for organization:

```
// Localizable.xcstrings
{
  "activity.add.title" = "Add Activity";
  "activity.edit.title" = "Edit Activity";
  "activity.name.placeholder" = "Activity Name";
  "timeslot.morning.title" = "Morning";
  "settings.firstWeekday.title" = "First Day of Week";
  "settings.timeFormat.title" = "Time Format";
  "settings.timeFormat.automatic" = "Automatic";
  "settings.timeFormat.12hour" = "12-Hour";
  "settings.timeFormat.24hour" = "24-Hour";
}
```

### SwiftUI Usage

```swift
// Use localized keys, not hardcoded strings
Text("activity.add.title")

// For dynamic values, use String(format:)
Text(String(format: String(localized: "completions.count"), completionCount))
```

### Locale-Aware Formatting

```swift
// Time display using DateIntervalFormatter (respects device locale)
var localizedDisplayName: String {
    let formatter = DateIntervalFormatter()
    formatter.timeStyle = .short  // Adapts to 12/24h automatically
    let start = dateForHour(startHour)
    let end = dateForHour(endHour)
    return formatter.string(from: start, to: end)
}

// For explicit user override, create formatter with specific locale
func formattedTime(for preferences: UserPreferences?) -> String {
    let formatter = DateIntervalFormatter()
    formatter.timeStyle = .short
    if let localeId = preferences?.localeIdentifier {
        formatter.locale = Locale(identifier: localeId)
    }
    // ...
}
```

### First Day of Week Support

```swift
// Calendar extension for user preferences
extension Calendar {
    static func forUser(_ preferences: UserPreferences?) -> Calendar {
        var calendar = Calendar.current
        if let firstWeekday = preferences?.firstWeekday {
            calendar.firstWeekday = firstWeekday
        }
        if let localeId = preferences?.localeIdentifier {
            calendar.locale = Locale(identifier: localeId)
        }
        return calendar
    }
}
```

### Localization Testing Checklist

- [ ] Test with 24-hour locale (e.g., Germany, Japan)
- [ ] Test with Sunday-start calendar (US)
- [ ] Test with Monday-start calendar (Europe)
- [ ] Test RTL languages (Arabic, Hebrew) if supported
- [ ] Verify date intervals format correctly in all target locales

---

## Testing Strategy

### Unit Tests
- TimeSlot calculations and edge cases
- Weekly boundary conditions
- Completion query predicates

### UI Tests
- Activity creation flow
- Time slot switching
- Completion toggling

### Widget Tests
- Timeline provider refresh
- Intent handling

---

## Localization

### String Catalogs

Use Xcode String Catalogs (`.xcstrings`) for all user-facing text. No hardcoded strings in the UI:

```swift
// Localizable.xcstrings
{
  "activity.add.title": {
    "localizations": {
      "en": { "stringUnit": { "value": "Add Activity" } },
      "de": { "stringUnit": { "value": "Aktivität hinzufügen" } },
      "fr": { "stringUnit": { "value": "Ajouter une activité" } }
    }
  },
  "timeslot.morning.label": {
    "localizations": {
      "en": { "stringUnit": { "value": "Morning" } },
      "de": { "stringUnit": { "value": "Morgen" } },
      "fr": { "stringUnit": { "value": "Matin" } }
    }
  }
}
```

```swift
// Usage in SwiftUI
Text("activity.add.title")
Button("timeslot.complete.button") { }
```

### Locale-Aware Formatting

All time displays use `DateIntervalFormatter` or `DateFormatter` with the user's locale:

```swift
var timeFormatter: DateIntervalFormatter {
    let formatter = DateIntervalFormatter()
    formatter.timeStyle = .short
    // Automatically respects 12/24h based on device locale
    return formatter
}
```

### Calendar Considerations

- **First weekday**: Sunday (US) vs Monday (Europe) — configurable in `UserPreferences`
- **Week numbering**: ISO 8601 (Europe) vs US standard
- **Time zone**: Store all dates in UTC, display in device local time

### Supported Languages (Phase 1)

- English (en)
- German (de)
- French (fr)
- Spanish (es)
- Japanese (ja)

---

## Future Enhancements

1. **Statistics**: Streak tracking, completion rate per time slot
2. **Notifications**: Reminders at time slot start
3. **Siri Shortcuts**: "Start my morning routine"
4. **Focus Modes**: Integration with iOS Focus for automatic time slot switching
5. **Shared Routines**: iCloud sharing between family members
6. **Complications**: watchOS app for quick completion
