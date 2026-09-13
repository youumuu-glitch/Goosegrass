import Foundation

enum AppointmentValidationError: Equatable, Sendable {
    case missingCustomer
    case invalidPartySize
}

enum AppointmentValidator {
    static func validate(
        customerID: UUID?,
        startAt: Date,
        partySize: Int
    ) -> [AppointmentValidationError] {
        var errors: [AppointmentValidationError] = []

        if customerID == nil {
            errors.append(.missingCustomer)
        }

        if partySize < 1 {
            errors.append(.invalidPartySize)
        }

        // Past dates are intentionally valid so users can enter historical appointments.
        _ = startAt
        return errors
    }
}
