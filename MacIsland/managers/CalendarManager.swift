//
//  CalendarManager.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import EventKit
import SwiftUI

enum CalendarAccessPolicy {
    static func hasReadAccess(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    static func shouldClearEvents(
        calendarStatus: EKAuthorizationStatus,
        reminderStatus: EKAuthorizationStatus
    ) -> Bool {
        !hasReadAccess(calendarStatus) && !hasReadAccess(reminderStatus)
    }

    static func homeStatusMessage(for status: EKAuthorizationStatus) -> String? {
        guard !hasReadAccess(status) else { return nil }
        if status == .notDetermined {
            return "Allow Calendar Access in Settings"
        }
        if status == .denied || status == .restricted {
            return "Calendar access denied in System Settings"
        }
        return "Calendar access required"
    }
}

// MARK: - CalendarManager

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published var currentWeekStartDate: Date
    @Published var events: [EventModel] = []
    @Published var allCalendars: [CalendarModel] = []
    @Published var eventCalendars: [CalendarModel] = []
    @Published var reminderLists: [CalendarModel] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    private var selectedCalendars: [CalendarModel] = []
    /// Non-persistent fixtures used exclusively by UI audit mode.
    private var auditEvents: [EventModel]?
    private let calendarService = CalendarService()

    private var eventStoreChangedObserver: NSObjectProtocol?
    private var dayBoundaryTask: Task<Void, Never>?

    private init() {
        self.currentWeekStartDate = CalendarManager.startOfDay(Date())
        setupEventStoreChangedObserver()
        scheduleDayBoundaryRefresh()
        Task {
            refreshAuthorizationStatuses()
            await reloadCalendarAndReminderLists()
            await updateEvents()
        }
    }

    func shutdown() {
        if let observer = eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(observer)
            eventStoreChangedObserver = nil
        }
        dayBoundaryTask?.cancel()
        dayBoundaryTask = nil
    }

    private func setupEventStoreChangedObserver() {
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshAfterStoreChange()
            }
        }
    }

    /// Reads the current state without prompting. Views use this when they appear so
    /// permission requests always remain a deliberate user action.
    func refreshAuthorizationStatuses() {
        if auditEvents != nil {
            calendarAuthorizationStatus = .fullAccess
            reminderAuthorizationStatus = .fullAccess
            return
        }
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    private func refreshAfterStoreChange() async {
        refreshAuthorizationStatuses()
        currentWeekStartDate = Self.startOfDay(.now)
        await reloadCalendarAndReminderLists()
        await updateEvents()
    }

    private func scheduleDayBoundaryRefresh() {
        dayBoundaryTask?.cancel()
        let calendar = Calendar.autoupdatingCurrent
        let nextDay = calendar.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0, second: 1),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(86_400)

        dayBoundaryTask = Task { [weak self] in
            let delay = max(0, nextDay.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            await self.refreshAfterStoreChange()
            self.scheduleDayBoundaryRefresh()
        }
    }

    @MainActor
    func reloadCalendarAndReminderLists() async {
        let all = await calendarService.calendars()
        self.eventCalendars = all.filter { !$0.isReminder }
        self.reminderLists = all.filter { $0.isReminder }
        self.allCalendars = all // for legacy compatibility, can be removed if not needed
        updateSelectedCalendars()
    }

    func requestCalendarAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarAuthorizationStatus = status

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .event) else {
                refreshAuthorizationStatuses()
                return
            }
            refreshAuthorizationStatuses()
            if granted {
                await reloadCalendarAndReminderLists()
                await updateEvents()
            }
        case .fullAccess, .authorized:
            await reloadCalendarAndReminderLists()
            await updateEvents()
        case .restricted, .denied, .writeOnly:
            events = []
        @unknown default: break
        }
    }

    func requestReminderAccess() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        reminderAuthorizationStatus = status

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .reminder) else {
                refreshAuthorizationStatuses()
                return
            }
            refreshAuthorizationStatuses()
            if granted {
                await reloadCalendarAndReminderLists()
                await updateEvents()
            }
        case .fullAccess, .authorized:
            await reloadCalendarAndReminderLists()
            await updateEvents()
        case .restricted, .denied, .writeOnly:
            break
        @unknown default: break
        }
    }

    // Kept for callers from older builds; this now only refreshes state and data.
    func checkCalendarAuthorization() async {
        refreshAuthorizationStatuses()
        guard hasReadAccess(calendarAuthorizationStatus) else { return }
        await reloadCalendarAndReminderLists()
        await updateEvents()
    }

    func checkReminderAuthorization() async {
        refreshAuthorizationStatuses()
        guard hasReadAccess(reminderAuthorizationStatus) else { return }
        await reloadCalendarAndReminderLists()
        await updateEvents()
    }

    private func hasReadAccess(_ status: EKAuthorizationStatus) -> Bool {
        CalendarAccessPolicy.hasReadAccess(status)
    }

    func updateSelectedCalendars() {
        // Populate selectedCalendarIDs based on Defaults calendar selection state
        switch Defaults[.calendarSelectionState] {
        case .all:
            selectedCalendarIDs = Set(allCalendars.map { $0.id })
        case .selected(let identifiers):
            selectedCalendarIDs = identifiers
        }

        // Update the local calendar objects that correspond to the selected ids
        selectedCalendars = allCalendars.filter { selectedCalendarIDs.contains($0.id) }
    }

    func getCalendarSelected(_ calendar: CalendarModel) -> Bool {
        return selectedCalendarIDs.contains(calendar.id)
    }

    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {
        var selectionState = Defaults[.calendarSelectionState]

        switch selectionState {
        case .all:
            if !isSelected {
                let identifiers = Set(allCalendars.map { $0.id }).subtracting([calendar.id])
                selectionState = .selected(identifiers)
            }

        case .selected(var identifiers):
            if isSelected {
                identifiers.insert(calendar.id)
            } else {
                identifiers.remove(calendar.id)
            }

            selectionState =
                identifiers.isEmpty
                ? .all : identifiers.count == allCalendars.count ? .all : .selected(identifiers)  // if empty, select all
        }

        Defaults[.calendarSelectionState] = selectionState
        updateSelectedCalendars()
        await updateEvents()
    }

    static func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }

    func updateCurrentDate(_ date: Date) async {
        currentWeekStartDate = Calendar.current.startOfDay(for: date)
        await updateEvents()
    }

    func useAuditEvents(_ events: [EventModel]) {
        auditEvents = events.sorted { $0.start < $1.start }
        self.events = auditEvents ?? []
        calendarAuthorizationStatus = .fullAccess
        reminderAuthorizationStatus = .fullAccess
    }

    private func updateEvents() async {
        if let auditEvents {
            events = auditEvents
            return
        }
        refreshAuthorizationStatuses()
        guard !CalendarAccessPolicy.shouldClearEvents(
            calendarStatus: calendarAuthorizationStatus,
            reminderStatus: reminderAuthorizationStatus
        ) else {
            events = []
            return
        }
        let calendarIDs = selectedCalendars.map { $0.id }
        let eventsResult = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: calendarIDs
        )
        self.events = eventsResult
    }
    
    func setReminderCompleted(reminderID: String, completed: Bool) async {
        await calendarService.setReminderCompleted(reminderID: reminderID, completed: completed)
        // Refresh events after updating
        events = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: selectedCalendars.map { $0.id })
    }
}
