import Foundation

enum DateFormatting {
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let displayWithTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return displayFormatter.string(from: date)
    }

    static func formatDateWithTime(_ date: Date?) -> String {
        guard let date else { return "" }
        return displayWithTimeFormatter.string(from: date)
    }
}
