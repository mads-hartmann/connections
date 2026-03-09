import SwiftUI

struct UriNoteView: View {
    let uri: CDUri

    @Environment(\.dismiss) private var dismiss
    @State private var note: String

    init(uri: CDUri) {
        self.uri = uri
        self._note = State(initialValue: uri.note ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Note")
                .font(.headline)

            TextEditor(text: $note)
                .font(.body)
                .frame(minHeight: 150)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 250)
    }

    private func save() {
        UriStore.updateNote(uri, note: note.isEmpty ? nil : note)
        dismiss()
    }
}
