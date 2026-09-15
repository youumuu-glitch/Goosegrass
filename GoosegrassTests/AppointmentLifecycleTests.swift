import XCTest
@testable import Goosegrass

final class AppointmentLifecycleTests: XCTestCase {
    func testEveryStatusActionPairMatchesTheLifecycleTable() throws {
        let legal: [AppointmentStatus: [AppointmentAction: AppointmentStatus]] = [
            .draft: [
                .submit: .pendingConfirmation,
                .cancel: .cancelled,
            ],
            .pendingConfirmation: [
                .confirm: .confirmed,
                .reschedule: .rescheduled,
                .cancel: .cancelled,
            ],
            .confirmed: [
                .markUpcoming: .upcoming,
                .reschedule: .rescheduled,
                .cancel: .cancelled,
            ],
            .upcoming: [
                .arrive: .arrived,
                .reschedule: .rescheduled,
                .markNoShow: .noShow,
                .cancel: .cancelled,
            ],
            .arrived: [
                .complete: .completed,
            ],
            .rescheduled: [
                .confirm: .confirmed,
                .cancel: .cancelled,
            ],
        ]

        for status in AppointmentStatus.allCases {
            for action in AppointmentAction.allCases {
                if let expected = legal[status]?[action] {
                    XCTAssertEqual(
                        try AppointmentLifecycle.destination(from: status, action: action),
                        expected,
                        "Expected \(status.rawValue) + \(action.rawValue) to be legal"
                    )
                } else {
                    XCTAssertThrowsError(
                        try AppointmentLifecycle.destination(from: status, action: action),
                        "Expected \(status.rawValue) + \(action.rawValue) to be rejected"
                    ) { error in
                        XCTAssertEqual(
                            error as? AppointmentLifecycleError,
                            .invalidTransition(from: status, action: action)
                        )
                    }
                }
            }
        }
    }
}
