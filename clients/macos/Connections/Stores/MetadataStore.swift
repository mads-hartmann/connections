import Foundation
import SwiftData

enum MetadataStore {

    static func create(
        in context: ModelContext,
        connection: CDConnection,
        fieldType: CDMetadataFieldType,
        value: String
    ) -> CDConnectionMetadata {
        let metadata = CDConnectionMetadata(
            fieldType: fieldType,
            value: value,
            connection: connection
        )
        context.insert(metadata)
        return metadata
    }

    /// Create metadata only if a matching (connection, fieldType, value) doesn't already exist.
    static func createIfNotExists(
        in context: ModelContext,
        connection: CDConnection,
        fieldType: CDMetadataFieldType,
        value: String
    ) -> CDConnectionMetadata? {
        let trimmedValue = value.trimmingCharacters(in: .whitespaces).lowercased()
        let exists = connection.metadata.contains { meta in
            meta.fieldType == fieldType
                && meta.value.trimmingCharacters(in: .whitespaces).lowercased() == trimmedValue
        }
        if exists { return nil }
        return create(in: context, connection: connection, fieldType: fieldType, value: value)
    }

    static func listByConnection(_ connection: CDConnection) -> [CDConnectionMetadata] {
        connection.metadata.sorted { $0.fieldType.name < $1.fieldType.name }
    }

    static func update(_ metadata: CDConnectionMetadata, value: String) {
        metadata.value = value
    }

    static func delete(in context: ModelContext, metadata: CDConnectionMetadata) {
        context.delete(metadata)
    }
}
