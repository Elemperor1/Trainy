import Foundation

enum ProviderTextUtilities {
    static func stableID(from value: String) -> String {
        let characters = value.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        return String(characters).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func lastIdentifierComponent(_ value: String) -> String {
        value.split { $0 == "." || $0 == ":" }.last.map(String.init) ?? value
    }

    static func spacedCamelCase(_ value: String) -> String {
        var result = ""
        var previousWasLowercase = false

        for character in value {
            if character.isUppercase && previousWasLowercase {
                result.append(" ")
            }
            result.append(character)
            previousWasLowercase = character.isLowercase || character.isNumber
        }

        return result
    }

    static func normalizedStationKey(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func searchTokens(from value: String) -> [String] {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let normalized = String(folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        })
        let stopWords: Set<String> = ["to", "from", "for", "via"]
        return normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    static func collapsedSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}

extension Array where Element == TrainStatusTone {
    var maxBySeverity: TrainStatusTone? {
        if contains(.late) {
            return .late
        }
        if contains(.watch) {
            return .watch
        }
        return first
    }
}
