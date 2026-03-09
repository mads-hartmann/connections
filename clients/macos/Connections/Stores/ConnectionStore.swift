import Foundation
import SwiftData

enum ConnectionStore {

    static func create(
        in context: ModelContext,
        name: String,
        photo: String? = nil,
        note: String? = nil
    ) -> CDConnection {
        let connection = CDConnection(name: name, photo: photo, note: note)
        context.insert(connection)
        return connection
    }

    static func all(in context: ModelContext, query: String? = nil) -> [CDConnection] {
        var descriptor = FetchDescriptor<CDConnection>(
            sortBy: [SortDescriptor(\.name)]
        )
        if let query, !query.isEmpty {
            descriptor.predicate = #Predicate<CDConnection> { connection in
                connection.name.localizedStandardContains(query)
            }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func get(in context: ModelContext, uid: UUID) -> CDConnection? {
        let descriptor = FetchDescriptor<CDConnection>(
            predicate: #Predicate { $0.uid == uid }
        )
        return try? context.fetch(descriptor).first
    }

    static func findByHost(in context: ModelContext, host: String) -> [CDConnection] {
        // Find connections that have metadata or feeds matching the host
        let allConnections = all(in: context)
        return allConnections.filter { connection in
            let feedHosts = connection.feeds.compactMap { URL(string: $0.url)?.host }
            let metadataHosts = connection.metadata.compactMap { URL(string: $0.value)?.host }
            return feedHosts.contains(where: { $0.contains(host) })
                || metadataHosts.contains(where: { $0.contains(host) })
        }
    }

    static func update(
        _ connection: CDConnection,
        name: String,
        photo: String?
    ) {
        connection.name = name
        connection.photo = photo
    }

    static func updateNote(_ connection: CDConnection, note: String?) {
        connection.note = note
    }

    static func delete(in context: ModelContext, connection: CDConnection) {
        context.delete(connection)
    }
}
