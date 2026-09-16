import XCTest
@testable import Goosegrass

final class FollowUpScheduleTests: XCTestCase {
    func testTomorrowAtElevenUsesTheNextLocalCalendarDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 16,
            hour: 23,
            minute: 45
        )))

        let result = try FollowUpSchedule.tomorrowAtEleven(from: now, calendar: calendar)

        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result),
            DateComponents(year: 2026, month: 9, day: 17, hour: 11, minute: 0)
        )
    }

    func testTomorrowAtElevenRetainsWallClockTimeAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let beforeSpringForward = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 7,
            hour: 16
        )))

        let result = try FollowUpSchedule.tomorrowAtEleven(from: beforeSpringForward, calendar: calendar)

        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result),
            DateComponents(year: 2026, month: 3, day: 8, hour: 11, minute: 0)
        )
        XCTAssertEqual(result.timeIntervalSince(beforeSpringForward), 18 * 60 * 60)
    }

    func testPendingAndSnoozedFollowUpsSupportActiveLifecycleActions() throws {
        XCTAssertEqual(try FollowUpLifecycle.destination(from: .pending, action: .complete), .completed)
        XCTAssertEqual(try FollowUpLifecycle.destination(from: .pending, action: .snooze), .snoozed)
        XCTAssertEqual(try FollowUpLifecycle.destination(from: .pending, action: .cancel), .cancelled)
        XCTAssertEqual(try FollowUpLifecycle.destination(from: .snoozed, action: .complete), .completed)
        XCTAssertEqual(try FollowUpLifecycle.destination(from: .snoozed, action: .snooze), .snoozed)
        XCTAssertEqual(try FollowUpLifecycle.destination(from: .snoozed, action: .cancel), .cancelled)
    }

    func testTerminalFollowUpsRejectFurtherTransitions() {
        for status in [FollowUpStatus.completed, .cancelled] {
            XCTAssertThrowsError(try FollowUpLifecycle.destination(from: status, action: .complete)) { error in
                XCTAssertEqual(
                    error as? FollowUpValidationError,
                    .invalidTransition(from: status, action: .complete)
                )
            }
        }
    }

    func testReasonIsTrimmedAndMustNotBeEmpty() throws {
        XCTAssertEqual(try FollowUpLifecycle.validatedReason("  Confirm new date  "), "Confirm new date")
        XCTAssertThrowsError(try FollowUpLifecycle.validatedReason(" \n ")) { error in
            XCTAssertEqual(error as? FollowUpValidationError, .emptyReason)
        }
    }

    func testDueDateMustBeStrictlyLaterThanOperationTime() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNoThrow(try FollowUpLifecycle.validateDueAt(now.addingTimeInterval(1), after: now))
        XCTAssertThrowsError(try FollowUpLifecycle.validateDueAt(now, after: now)) { error in
            XCTAssertEqual(error as? FollowUpValidationError, .dueDateMustBeFuture)
        }
        XCTAssertThrowsError(try FollowUpLifecycle.validateDueAt(now.addingTimeInterval(-1), after: now)) { error in
            XCTAssertEqual(error as? FollowUpValidationError, .dueDateMustBeFuture)
        }
    }
}
