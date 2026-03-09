import Foundation
import SwiftData

enum TagStore {

    static func create(in context: ModelContext, name: String) -> CDTag {
        let tag = CDTag(name: name)
        context.insert(tag)
        return tag
    }

    static func getOrCreate(in context: ModelContext, name: String) -> CDTag {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<CDTag>(
            predicate: #Predicate<CDTag> { $0.name == trimmed }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        return create(in: context, name: trimmed)
    }

    static func all(in context: ModelContext, query: String? = nil) -> [CDTag] {
        var descriptor = FetchDescriptor<CDTag>(
            sortBy: [SortDescriptor(\.name)]
        )
        if let query, !query.isEmpty {
            descriptor.predicate = #Predicate<CDTag> { tag in
                tag.name.localizedStandardContains(query)
            }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func get(in context: ModelContext, uid: UUID) -> CDTag? {
        let descriptor = FetchDescriptor<CDTag>(
            predicate: #Predicate { $0.uid == uid }
        )
        return try? context.fetch(descriptor).first
    }

    static func update(_ tag: CDTag, name: String) {
        tag.name = name
    }

    static func delete(in context: ModelContext, tag: CDTag) {
        context.delete(tag)
    }

    // MARK: - Association helpers

    static func addToConnection(_ tag: CDTag, connection: CDConnection) {
        if !connection.tags.contains(where: { $0.uid == tag.uid }) {
            connection.tags.append(tag)
        }
    }

    static func removeFromConnection(_ tag: CDTag, connection: CDConnection) {
        connection.tags.removeAll { $0.uid == tag.uid }
    }

    static func addToFeed(_ tag: CDTag, feed: CDFeed) {
        if !feed.tags.contains(where: { $0.uid == tag.uid }) {
            feed.tags.append(tag)
        }
    }

    static func removeFromFeed(_ tag: CDTag, feed: CDFeed) {
        feed.tags.removeAll { $0.uid == tag.uid }
    }

    static func addToUri(_ tag: CDTag, uri: CDUri) {
        if !uri.tags.contains(where: { $0.uid == tag.uid }) {
            uri.tags.append(tag)
        }
    }

    static func removeFromUri(_ tag: CDTag, uri: CDUri) {
        uri.tags.removeAll { $0.uid == tag.uid }
    }
}
