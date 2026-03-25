import EventKit
import Foundation

public struct UpcomingEvent {
    public let id: String
    public let title: String
    public let startDate: Date
    public let calendarName: String
    public let secondsUntilStart: TimeInterval

    public var formattedTimeUntil: String {
        let seconds = Int(secondsUntilStart)
        if seconds < 0 {
            let ago = abs(seconds)
            if ago < 60 { return "\(ago)s ago" }
            return "\(ago / 60)m ago"
        }
        if seconds < 60 { return "in \(seconds)s" }
        if seconds < 3600 { return "in \(seconds / 60)m" }
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        if mins == 0 { return "in \(hours)h" }
        return "in \(hours)h \(mins)m"
    }

    public var countdownString: String {
        let seconds = Int(max(secondsUntilStart, 0))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

public class CalendarService {
    private let store = EKEventStore()

    public init() {}

    public func requestAccess() -> Bool {
        var granted = false
        var done = false
        store.requestFullAccessToEvents { result, error in
            granted = result
            if let error = error {
                log("Error requesting calendar access: \(error.localizedDescription)")
            }
            done = true
        }
        while !done {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        return granted
    }

    public func checkAccess() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }

    public func findUpcomingEvents(config: Config) -> [UpcomingEvent] {
        let now = Date()
        let leadTime = TimeInterval(config.leadTimeSeconds)
        let gracePeriod = TimeInterval(config.gracePeriodSeconds)

        let startDate = now.addingTimeInterval(-gracePeriod)
        let endDate = now.addingTimeInterval(leadTime)

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: filteredCalendars(config: config))
        let events = store.events(matching: predicate)

        return events.compactMap { event -> UpcomingEvent? in
            if config.skipAllDay && event.isAllDay { return nil }
            if config.skipDeclined {
                if let attendees = event.attendees {
                    let selfAttendee = attendees.first { $0.isCurrentUser }
                    if selfAttendee?.participantStatus == .declined { return nil }
                }
            }
            if event.status == .canceled { return nil }

            return UpcomingEvent(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                calendarName: event.calendar.title,
                secondsUntilStart: event.startDate.timeIntervalSince(now)
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    public func findNextEvent(config: Config) -> UpcomingEvent? {
        let now = Date()
        let endDate = now.addingTimeInterval(24 * 3600)

        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: filteredCalendars(config: config))
        let events = store.events(matching: predicate)

        return events.compactMap { event -> UpcomingEvent? in
            if config.skipAllDay && event.isAllDay { return nil }
            if event.status == .canceled { return nil }
            if config.skipDeclined {
                if let attendees = event.attendees {
                    let selfAttendee = attendees.first { $0.isCurrentUser }
                    if selfAttendee?.participantStatus == .declined { return nil }
                }
            }
            return UpcomingEvent(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                calendarName: event.calendar.title,
                secondsUntilStart: event.startDate.timeIntervalSince(now)
            )
        }
        .sorted { $0.startDate < $1.startDate }
        .first
    }

    private func filteredCalendars(config: Config) -> [EKCalendar]? {
        guard !config.calendars.isEmpty else { return nil }
        let allCalendars = store.calendars(for: .event)
        let filtered = allCalendars.filter { config.calendars.contains($0.title) }
        return filtered.isEmpty ? nil : filtered
    }
}
