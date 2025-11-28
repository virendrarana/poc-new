import Foundation

struct KycLogEntry {
    let type: String
    let step: String?
    let message: String
    let meta: String?
    let timestamp: Date
}

final class KycLogStore {

    static let shared = KycLogStore()
    private init() {}

    private var items: [KycLogEntry] = []

    var events: [KycLogEntry] {
        return items
    }

    func add(_ entry: KycLogEntry) {
        // newest first – like Android
        items.insert(entry, at: 0)
    }

    func clear() {
        items.removeAll()
    }
}
