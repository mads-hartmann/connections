import SwiftUI

struct ConnectionNoteView: View {
    let connection: CDConnection

    @Environment(\.dismiss) private var dismiss
    @State private var note: String

    init(connection: CDConnection) {
        self.connection = connection
        self._note = State(initialValue: connection.note ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Note").font(.headline)

            TextEditor(text: $note)
                .font(.body)
                .frame(minHeight: 150)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 250)
    }

    private func save() {
        ConnectionStore.updateNote(connection, note: note.isEmpty ? nil : note)
        dismiss()
    }
}
