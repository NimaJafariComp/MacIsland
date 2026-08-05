//
//  BoringCalendar.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import AppKit
import Defaults
import SwiftUI

enum CalendarReminderPresentation {
    static func rowLabel(title: String) -> String {
        "Reminder: \(title)"
    }

    static func toggleLabel(title: String, completed: Bool) -> String {
        "Mark \(title) as \(completed ? "incomplete" : "complete")"
    }
}

enum HomeCalendarSummaryPresentation {
    static func countLabel(itemCount: Int, reminderCount: Int) -> String {
        let itemText = "\(itemCount) \(itemCount == 1 ? "item" : "items")"
        guard reminderCount > 0 else { return itemText }
        return "\(itemText) · \(reminderCount) \(reminderCount == 1 ? "reminder" : "reminders")"
    }
}

struct Config: Equatable {
    //    var count: Int = 10  // 3 days past + today + 7 days future
    var past: Int = 7
    var future: Int = 14
    var steps: Int = 1  // Each step is one day
    var spacing: CGFloat = 0
    var showsText: Bool = true
    var offset: Int = 2  // Number of dates to the left of the selected date
}

struct WheelPicker: View {
    @EnvironmentObject var vm: BoringViewModel
    @Binding var selectedDate: Date
    /// The rail contains the complete displayed month, so its first and last
    /// dates always match the month title rather than an arbitrary rolling
    /// window around today.
    let displayedMonth: Date
    @State private var scrollPosition: Int?
    @State private var haptics: Bool = false
    @State private var byClick: Bool = false
    let config: Config

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: config.spacing) {
                let spacerNum = config.offset
                let dateCount = totalDateItems()
                let totalItems = dateCount + 2 * spacerNum
                ForEach(0..<totalItems, id: \.self) { index in
                    if index < spacerNum || index >= spacerNum + dateCount {
                        // Leading/trailing spacers sized to match a date cell
                        Spacer()
                            .frame(width: 24, height: 24)
                            .id(index)
                    } else {
                        let date = dateForItemIndex(index: index, spacerNum: spacerNum)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        dateButton(date: date, isSelected: isSelected, id: index) {
                            selectedDate = date
                            byClick = true
                            withAnimation(IslandMotion.interaction) {
                                scrollPosition = index
                            }
                            if Defaults[.enableHaptics] {
                                haptics.toggle()
                            }
                        }
                    }
                }
            }
            .frame(height: 50)
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)  // Ensures scroll view snaps the centered view
        .safeAreaPadding(.horizontal)
        .sensoryFeedback(.alignment, trigger: haptics)
        .onChange(of: scrollPosition) { oldValue, newValue in
            if !byClick {
                handleScrollChange(newValue: newValue, config: config)
            } else {
                byClick = false
            }
        }
        .onAppear {
            scrollToSelection()
        }
        // When parent updates the bound selectedDate (e.g., view reopen), center the wheel on it
        .onChange(of: selectedDate) { _, newValue in
            let targetIndex = indexForDate(newValue)
            if scrollPosition != targetIndex {
                byClick = true
                withAnimation(IslandMotion.interaction) {
                    scrollPosition = targetIndex
                }
            }
        }
    }

    private func dateButton(
        date: Date, isSelected: Bool, id: Int, onClick: @escaping () -> Void
    ) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        return Button(action: onClick) {
            VStack(spacing: 8) {
                dayText(date: dateToString(for: date), isToday: isToday, isSelected: isSelected)
                dateCircle(date: date, isToday: isToday, isSelected: isSelected)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.effectiveAccentBackground : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .id(id)
    }

    private func dayText(date: String, isToday: Bool, isSelected: Bool) -> some View {
        Text(date)
            .font(.caption)
            .foregroundColor(isSelected ? Color.islandPrimaryText : Color.islandSecondaryText)
    }

    private func dateCircle(date: Date, isToday: Bool, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isToday ? Color.effectiveAccent : .clear)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.islandBorder, lineWidth: 0)
                )
            Text("\(date.date)")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isSelected || isToday ? Color.islandPrimaryText : Color.islandSecondaryText)
        }
    }

    func handleScrollChange(newValue: Int?, config: Config) {
        guard let newIndex = newValue else { return }
        let spacerNum = config.offset
        let dateCount = totalDateItems()
        guard (spacerNum..<(spacerNum + dateCount)).contains(newIndex) else { return }
        let date = dateForItemIndex(index: newIndex, spacerNum: spacerNum)
        if !Calendar.current.isDate(date, inSameDayAs: selectedDate) {
            selectedDate = date
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }

    private func scrollToSelection() {
        byClick = true
        scrollPosition = indexForDate(selectedDate)
    }

    // MARK: - Index/Date mapping with steps and spacers
    private func indexForDate(_ date: Date) -> Int {
        let spacerNum = config.offset
        let cal = Calendar.current
        let startDate = startOfDisplayedMonth(using: cal)
        let target = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startDate, to: target).day ?? 0
        let stepIndex = max(0, min(days, totalDateItems() - 1))
        return spacerNum + stepIndex
    }

    private func dateForItemIndex(index: Int, spacerNum: Int) -> Date {
        let cal = Calendar.current
        let startDate = startOfDisplayedMonth(using: cal)
        let stepIndex = index - spacerNum
        return cal.date(byAdding: .day, value: stepIndex, to: startDate) ?? startDate
    }

    private func totalDateItems() -> Int {
        let calendar = Calendar.current
        return calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 31
    }

    private func startOfDisplayedMonth(using calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: displayedMonth)?.start
            ?? calendar.startOfDay(for: displayedMonth)
    }

    private func dateToString(for date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }
}

struct CalendarView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @Default(.hideCompletedReminders) private var hideCompletedReminders

    private func events(on date: Date) -> [EventModel] {
        EventListView.filteredEvents(events: calendarManager.events).filter {
            Calendar.autoupdatingCurrent.isDate($0.start, inSameDayAs: date)
        }
    }

    private var selectedDayEvents: [EventModel] {
        events(on: selectedDate)
    }

    private func updatePanelHeight() {
        vm.requestOpenHeight(
            IslandExpandedPageSizing.calendarHeight(itemCount: selectedDayEvents.count),
            for: .calendar
        )
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { selectDate($0) }
        )
    }

    /// A selected day and its capped panel height are one presentation state.
    /// Sending the height only after a debounce makes populated days redraw
    /// before their enclosing Island has started to grow.
    private func selectDate(_ date: Date) {
        guard !Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: selectedDate) else { return }

        vm.requestOpenHeight(
            IslandExpandedPageSizing.calendarHeight(itemCount: events(on: date).count),
            for: .calendar
        )
        withAnimation(IslandMotion.islandOpenClose) {
            selectedDate = date
            if !Calendar.autoupdatingCurrent.isDate(
                date,
                equalTo: displayedMonth,
                toGranularity: .month
            ) {
                displayedMonth = date
            }
        }
        Task {
            await calendarManager.updateCalendarMonth(containing: date)
        }
    }

    var body: some View {
        let selectedEvents = selectedDayEvents
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 2) {
                    Button {
                        moveSelectedDate(byMonths: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Previous month")
                    .accessibilityLabel("Previous month")

                    VStack(alignment: .leading) {
                        Text(displayedMonth.formatted(.dateTime.month(.abbreviated)))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.islandPrimaryText)
                        Text(displayedMonth.formatted(.dateTime.year()))
                            .font(.title3)
                            .fontWeight(.light)
                            .foregroundColor(Color.islandSecondaryText)
                    }

                    Button {
                        moveSelectedDate(byMonths: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Next month")
                    .accessibilityLabel("Next month")
                }

                WheelPicker(
                    selectedDate: selectedDateBinding,
                    displayedMonth: displayedMonth,
                    config: Config()
                )
                    .overlay {
                        HStack(alignment: .top) {
                            LinearGradient(
                                colors: [Color.islandHardwareSurface, .clear], startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: 20)
                            Spacer()
                            LinearGradient(
                                colors: [.clear, Color.islandHardwareSurface], startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: 20)
                        }
                        .allowsHitTesting(false)
                    }

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
                } label: {
                    Label("Apple Calendar", systemImage: "calendar")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open Apple Calendar")
                .accessibilityLabel("Open Apple Calendar")

                Menu {
                    Toggle(
                        "Show completed reminders",
                        isOn: Binding(
                            get: { !hideCompletedReminders },
                            set: { hideCompletedReminders = !$0 }
                        )
                    )
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .help("Calendar display options")
                .accessibilityLabel("Calendar display options")
            }
            .padding(.bottom, 4)

            if selectedEvents.isEmpty {
                EmptyEventsView(selectedDate: selectedDate)
                Spacer(minLength: 0)
            } else {
                EventListView(events: selectedEvents)
            }
        }
        .listRowBackground(Color.clear)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: calendarManager.events) { _, _ in
            updatePanelHeight()
        }
        .onAppear {
            selectedDate = Date.now
            displayedMonth = selectedDate
            updatePanelHeight()
            Task {
                await calendarManager.updateCalendarMonth(containing: selectedDate)
            }
        }
    }

    private func moveSelectedDate(byMonths offset: Int) {
        let calendar = Calendar.autoupdatingCurrent
        guard let targetMonth = calendar.date(
            byAdding: .month,
            value: offset,
            to: displayedMonth
        ) else {
            return
        }

        let day = calendar.component(.day, from: selectedDate)
        let maximumDay = calendar.range(of: .day, in: .month, for: targetMonth)?.count ?? day
        var components = calendar.dateComponents([.year, .month], from: targetMonth)
        components.day = min(day, maximumDay)
        guard let newDate = calendar.date(from: components) else { return }

        selectDate(newDate)
    }
}

/// Home uses a summary, not the full scheduler. This keeps the island useful
/// at a glance and reserves the detailed, scrollable schedule for CalendarView.
struct HomeCalendarCard: View {
    /// Home owns one shared row height. Supplying it here prevents the
    /// Calendar surface from drawing beyond its fixed HStack slot.
    let moduleHeight: CGFloat?
    @ObservedObject private var calendarManager = CalendarManager.shared
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @EnvironmentObject private var vm: BoringViewModel

    private var todayItems: [EventModel] {
        EventListView.filteredEvents(events: calendarManager.events).filter {
            Calendar.autoupdatingCurrent.isDate($0.start, inSameDayAs: .now)
        }
    }

    private var primaryItem: EventModel? {
        let timedItems = todayItems.filter { !$0.isAllDay }
        return timedItems.first { $0.start <= .now && $0.end > .now }
            ?? timedItems.first { $0.start > .now }
            ?? todayItems.first
    }

    private var reminderCount: Int {
        todayItems.filter(\.type.isReminder).count
    }

    private var hasScheduleAccess: Bool {
        CalendarAccessPolicy.hasReadAccess(calendarManager.calendarAuthorizationStatus)
            || CalendarAccessPolicy.hasReadAccess(calendarManager.reminderAuthorizationStatus)
    }

    private var statusMessage: String? {
        hasScheduleAccess
            ? nil
            : CalendarAccessPolicy.homeStatusMessage(for: calendarManager.calendarAuthorizationStatus)
    }

    private var weekday: String {
        Date.now.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    var body: some View {
        Group {
            if hasScheduleAccess {
                Button {
                    vm.requestOpenHeight(
                        IslandExpandedPageSizing.calendarHeight(itemCount: todayItems.count),
                        for: .calendar
                    )
                    vm.selectOpenPage(.calendar)
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .help("View schedule in MacIsland")
                .accessibilityLabel(
                    primaryItem == nil
                        ? "View schedule in MacIsland"
                        : "View today's \(HomeCalendarSummaryPresentation.countLabel(itemCount: todayItems.count, reminderCount: reminderCount)) in MacIsland, starting with \(primaryItem!.title)"
                )
            } else {
                content
            }
        }
        // The Home row is height-bounded by `HomeLayoutBudget`. Keep the
        // summary's minimum height inside that shared module height so its
        // surface aligns with the media card instead of growing upward.
        .padding(.horizontal, IslandStyle.modulePadding)
        .padding(.vertical, 6)
        .frame(
            maxWidth: .infinity,
            minHeight: moduleHeight,
            maxHeight: moduleHeight,
            alignment: .topLeading
        )
        .background(Color.islandModuleSurface, in: RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous)
                .stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: IslandStyle.moduleCornerRadius,
                style: .continuous
            )
        )
        .onAppear {
            Task { await calendarManager.updateCurrentDate(.now) }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(weekday)
                    .font(IslandTypography.metadata.weight(.semibold))
                        .foregroundStyle(Color.islandSecondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Date.now.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(IslandTypography.metadata.weight(.semibold))
                            .foregroundStyle(Color.islandSecondaryText)
                        Text(Date.now.formatted(.dateTime.day()))
                            .font(.system(size: 23, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.islandPrimaryText)
                    }
                }
                Spacer(minLength: 4)
                HStack(spacing: 5) {
                    HomeCalendarCountBadge(
                        count: todayItems.count,
                        symbol: "calendar"
                    )
                    if reminderCount > 0 {
                        HomeCalendarCountBadge(
                            count: reminderCount,
                            symbol: "checklist"
                        )
                    }
                }
            }

            Divider().overlay(Color.islandBorder)

            if let statusMessage {
                Label(statusMessage, systemImage: "calendar.badge.exclamationmark")
                    .font(IslandTypography.metadata)
                    .foregroundStyle(Color.islandSecondaryText)
                    .lineLimit(2)
            } else if let primaryItem {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryItem.title)
                        .font(IslandTypography.body.weight(.semibold))
                        .foregroundStyle(Color.islandPrimaryText)
                        .lineLimit(1)
                    if !primaryItem.isAllDay {
                        Text(primaryItem.start.formatted(date: .omitted, time: .shortened))
                            .font(IslandTypography.metadata)
                            .foregroundStyle(Color.islandSecondaryText)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing else today")
                        .font(IslandTypography.body.weight(.semibold))
                    Text("Enjoy clear time.")
                        .font(IslandTypography.metadata)
                        .foregroundStyle(Color.islandSecondaryText)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct HomeCalendarCountBadge: View {
    let count: Int
    let symbol: String

    var body: some View {
        Label("\(count)", systemImage: symbol)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.effectiveAccent)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 5)
            .frame(height: 20)
            .background(Color.islandElevatedSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth)
            }
            .accessibilityLabel(symbol == "calendar" ? "\(count) scheduled items" : "\(count) reminders")
    }
}

struct EmptyEventsView: View {
    let selectedDate: Date
    
    var body: some View {
        VStack {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title)
                .foregroundColor(Color.islandSecondaryText)
            Text(Calendar.current.isDateInToday(selectedDate) ? "No events today" : "No events")
                .font(.subheadline)
                .foregroundColor(Color.islandPrimaryText)
            Text("Enjoy your free time!")
                .font(.caption)
                .foregroundColor(Color.islandSecondaryText)
        }
    }
}

struct EventListView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var calendarManager = CalendarManager.shared
    let events: [EventModel]
    @Default(.autoScrollToNextEvent) private var autoScrollToNextEvent
    @Default(.showFullEventTitles) private var showFullEventTitles


    static func filteredEvents(events: [EventModel]) -> [EventModel] {
        events.filter { event in
            if event.type.isReminder {
                if case .reminder(let completed) = event.type {
                    return !completed || !Defaults[.hideCompletedReminders]
                }
            }
            // Filter out all-day events if setting is enabled
            if event.isAllDay && Defaults[.hideAllDayEvents] {
                return false
            }
            return true
        }
    }

    private func scrollToRelevantEvent(proxy: ScrollViewProxy) {
        // This list represents one selected day. Start at its first item so
        // all-day content is never skipped when a day change reuses a prior
        // scroll position.
        guard let target = events.first else { return }

        Task { @MainActor in
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(target.id, anchor: .top)
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(events) { event in
                        Group {
                            if event.type.isReminder {
                                eventRow(event)
                            } else {
                                Button(action: {
                                    if let url = event.calendarAppURL() {
                                        openURL(url)
                                    }
                                }) {
                                    eventRow(event)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .id(event.id)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)

                        Divider().overlay(Color.islandBorder)
                    }
                }
            }
            .scrollIndicators(.automatic)
            .onAppear {
                scrollToRelevantEvent(proxy: proxy)
            }
            .onChange(of: events) { _, _ in
                scrollToRelevantEvent(proxy: proxy)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func eventRow(_ event: EventModel) -> some View {
        if event.type.isReminder {
            let isCompleted: Bool
            if case .reminder(let completed) = event.type {
                isCompleted = completed
            } else {
                isCompleted = false
            }
            return AnyView(
                HStack(spacing: 8) {
                    ReminderToggle(
                        isOn: Binding(
                            get: { isCompleted },
                            set: { newValue in
                                Task {
                                    await calendarManager.setReminderCompleted(
                                        reminderID: event.id, completed: newValue
                                    )
                                }
                            }
                        ),
                        color: Color(event.calendar.color),
                        title: event.title
                    )
                    .opacity(1.0)  // Ensure the toggle is always fully opaque
                    HStack {
                        Text(event.title)
                            .font(.callout)
                            .foregroundColor(Color.islandPrimaryText)
                            .lineLimit(showFullEventTitles ? nil : 1)
                            .accessibilityLabel(CalendarReminderPresentation.rowLabel(title: event.title))
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            if event.isAllDay {
                                Text("All-day")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.islandPrimaryText)
                                    .lineLimit(1)
                            } else {
                                Text(event.start, style: .time)
                                    .foregroundColor(Color.islandPrimaryText)
                                    .font(.caption)
                            }
                        }
                    }
                    .opacity(
                        isCompleted
                            ? 0.4
                            : event.start < Date.now && Calendar.current.isDateInToday(event.start)
                                ? 0.6 : 1.0
                    )
                }
                .padding(.vertical, 4)
            )
        } else {
            return AnyView(
                HStack(alignment: .top, spacing: 4) {
                    Rectangle()
                        .fill(Color(event.calendar.color))
                        .frame(width: 3)
                        .cornerRadius(1.5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(Color.islandPrimaryText)
                            .lineLimit(showFullEventTitles ? nil : 2)

                        if let location = event.location, !location.isEmpty {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(Color.islandSecondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if event.isAllDay {
                            Text("All-day")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color.islandPrimaryText)
                                .lineLimit(1)
                        } else {
                            Text(event.start, style: .time)
                                .foregroundColor(Color.islandPrimaryText)
                            Text(event.end, style: .time)
                                .foregroundColor(Color.islandSecondaryText)
                        }
                    }
                    .font(.caption)
                    .frame(minWidth: 44, alignment: .trailing)
                }
                .opacity(
                    event.eventStatus == .ended && Calendar.current.isDateInToday(event.start)
                        ? 0.6 : 1.0)
            )
        }
    }
}

struct ReminderToggle: View {
    @Binding var isOn: Bool
    var color: Color
    var title: String

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 14, height: 14)
                // Inner fill
                if isOn {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Circle()
                    .fill(Color.islandHitTarget)
                    .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(0)
        .accessibilityLabel(CalendarReminderPresentation.toggleLabel(title: title, completed: isOn))
    }
}

#Preview {
    CalendarView()
        .frame(width: 215, height: 130)
        .background(Color.islandHardwareSurface)
        .environmentObject(BoringViewModel())
}
