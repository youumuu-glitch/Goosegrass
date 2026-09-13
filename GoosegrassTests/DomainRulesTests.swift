import Foundation
import XCTest
@testable import Goosegrass

final class DomainRulesTests: XCTestCase {
    func testPhoneNormalizerRemovesBasicFormattingOnly() {
        XCTAssertEqual(
            PhoneNormalizer.normalize("+86 (138) 0000-8888"),
            "+8613800008888"
        )
    }

    func testPhoneNormalizerMatchesEquivalentFormatting() {
        XCTAssertTrue(
            PhoneNormalizer.possibleDuplicate("138 0000 8888", "138-0000-8888")
        )
    }

    func testPhoneNormalizerDoesNotAssumeCountryPrefixEquivalence() {
        XCTAssertFalse(
            PhoneNormalizer.possibleDuplicate("+86 13800008888", "13800008888")
        )
    }

    func testPhoneNormalizerDoesNotMatchEmptyValues() {
        XCTAssertFalse(PhoneNormalizer.possibleDuplicate("() -", ""))
    }

    func testAppointmentValidatorRejectsPartySizeBelowOne() {
        XCTAssertEqual(
            AppointmentValidator.validate(
                customerID: UUID(),
                startAt: Date(),
                partySize: 0
            ),
            [.invalidPartySize]
        )
    }

    func testAppointmentValidatorRequiresCustomer() {
        XCTAssertEqual(
            AppointmentValidator.validate(
                customerID: nil,
                startAt: Date(),
                partySize: 1
            ),
            [.missingCustomer]
        )
    }

    func testAppointmentValidatorAllowsPastAppointments() {
        XCTAssertTrue(
            AppointmentValidator.validate(
                customerID: UUID(),
                startAt: Date(timeIntervalSince1970: 0),
                partySize: 1
            ).isEmpty
        )
    }
}
