import Contacts
import Foundation

enum ContactsWordError: Error, LocalizedError, Sendable {
    case accessDenied
    case notEnoughContacts

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Access to contacts was denied. Please allow access in Settings to use the Your Contacts theme."
        case .notEnoughContacts:
            "Not enough usable names were found in your contacts. At least 8 contacts with 4–9 letter names are needed."
        }
    }
}

struct ContactsWordService: Sendable {
    private static let minimumValidNames = 8
    private static let maximumWordsReturned = 10

    func fetchWords() async throws -> [String] {
        try await requestAccess()
        let names = try fetchContactGivenNames()
        let sanitised = sanitise(names)

        guard sanitised.count >= Self.minimumValidNames else {
            throw ContactsWordError.notEnoughContacts
        }

        return Array(sanitised.shuffled().prefix(Self.maximumWordsReturned))
    }

    // MARK: - Private helpers

    private func requestAccess() async throws {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            if !granted { throw ContactsWordError.accessDenied }
        case .denied, .restricted:
            throw ContactsWordError.accessDenied
        @unknown default:
            throw ContactsWordError.accessDenied
        }
    }

    private func fetchContactGivenNames() throws -> [String] {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .none

        var names: [String] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let given = contact.givenName.trimmingCharacters(in: .whitespaces)
            if !given.isEmpty {
                names.append(given)
            }
        }
        return names
    }

    private func sanitise(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.compactMap { raw -> String? in
            // Strip diacritics, uppercase
            let folded = raw
                .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
                .uppercased()

            // Letters only
            let lettersOnly = folded.unicodeScalars
                .filter { CharacterSet.uppercaseLetters.contains($0) }
                .map { Character($0) }
            let word = String(lettersOnly)

            // 4-9 letters
            guard (4...9).contains(word.count) else { return nil }

            // Deduplicate
            guard seen.insert(word).inserted else { return nil }

            return word
        }
    }
}
