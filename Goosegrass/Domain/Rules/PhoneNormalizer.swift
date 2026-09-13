import Foundation

enum PhoneNormalizer {
    private static let basicFormattingCharacters: Set<Character> = [" ", "-", "(", ")"]

    static func normalize(_ phone: String) -> String {
        phone.filter { !basicFormattingCharacters.contains($0) }
    }

    static func possibleDuplicate(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLeft = normalize(lhs)
        return !normalizedLeft.isEmpty && normalizedLeft == normalize(rhs)
    }
}
