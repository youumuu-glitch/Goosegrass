import Foundation
import XCTest
@testable import Goosegrass

final class ReminderCalculatorTests: XCTestCase {
    func testDefaultPresetsProduceOrderedFutureSchedules() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let start = try date("2026-09-17T12:00:00Z")
        let now = try date("2026-09-15T10:00:00Z")

        let schedules = ReminderCalculator.schedules(
            for: start,
            preferences: ReminderPreferences(),
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(schedules, [
            ReminderSchedule(type: .oneDayBefore, fireAt: try date("2026-09-16T12:00:00Z")),
            ReminderSchedule(type: .twoHoursBefore, fireAt: try date("2026-09-17T10:00:00Z")),
            ReminderSchedule(type: .thirtyMinutesBefore, fireAt: try date("2026-09-17T11:30:00Z")),
        ])
    }

    func testDisabledPresetsAndPastFireDatesAreOmitted() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let start = try date("2026-09-15T12:00:00Z")

        XCTAssertEqual(ReminderCalculator.schedules(
            for: start,
            preferences: ReminderPreferences(
                oneDayBeforeEnabled: false,
                twoHoursBeforeEnabled: true,
                thirtyMinutesBeforeEnabled: false,
                soundEnabled: false
            ),
            calendar: calendar,
            now: try date("2026-09-15T09:00:00Z")
        ), [ReminderSchedule(type: .twoHoursBefore, fireAt: try date("2026-09-15T10:00:00Z"))])

        XCTAssertTrue(ReminderCalculator.schedules(
            for: try date("2026-09-15T10:20:00Z"),
            preferences: ReminderPreferences(),
            calendar: calendar,
            now: try date("2026-09-15T10:00:00Z")
        ).isEmpty)
    }

    func testOneDayPresetPreservesLocalWallClockAcrossSpringForward() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let appointment = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 3,
            day: 9,
            hour: 1,
            minute: 30
        )))
        let now = try XCTUnwrap(calendar.date(byAdding: .day, value: -3, to: appointment))
        let schedule = try XCTUnwrap(ReminderCalculator.schedules(
            for: appointment,
            preferences: ReminderPreferences(
                oneDayBeforeEnabled: true,
                twoHoursBeforeEnabled: false,
                thirtyMinutesBeforeEnabled: false
            ),
            calendar: calendar,
            now: now
        ).first)

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: schedule.fireAt)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.hour, 1)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(appointment.timeIntervalSince(schedule.fireAt), 23 * 3_600)
    }

    func testSystemNotificationIdentifierIsStableAndNamespaced() throws {
        let id = try XCTUnwrap(UUID(uuidString: "91919191-9191-9191-9191-919191919191"))
        XCTAssertEqual(
            ReminderNotificationIdentity.identifier(for: id),
            "com.gravityedge.goosegrass.reminder.91919191-9191-9191-9191-919191919191"
        )
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}
