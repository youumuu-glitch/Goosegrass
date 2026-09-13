import Foundation
import XCTest
@testable import Goosegrass

final class DomainModelTests: XCTestCase {
    func testAppointmentStatusRawValuesRemainStable() {
        XCTAssertEqual(AppointmentStatus.pendingConfirmation.rawValue, "pendingConfirmation")
        XCTAssertEqual(AppointmentStatus.noShow.rawValue, "noShow")
        XCTAssertEqual(AppointmentStatus.allCases.count, 9)
    }

    func testCustomerKeepsOriginalAndNormalizedPhoneSeparately() {
        let customer = Customer(
            displayName: "王女士",
            phone: "138 0000-8888",
            normalizedPhone: "13800008888"
        )

        XCTAssertEqual(customer.phone, "138 0000-8888")
        XCTAssertEqual(customer.normalizedPhone, "13800008888")
        XCTAssertFalse(customer.isArchived)
    }

    func testAppointmentDefaultsToDraftAndKeepsNotesSeparate() {
        let appointment = Appointment(
            customerID: UUID(),
            startAt: Date(),
            partySize: 2,
            customerRequest: "安静座位",
            internalNote: "首次到店"
        )

        XCTAssertEqual(appointment.status, .draft)
        XCTAssertNotEqual(appointment.customerRequest, appointment.internalNote)
    }
}
