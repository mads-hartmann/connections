import SwiftUI

struct ConnectionNoteView: View {
    let connectionId: Int
    let currentNote: String?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var isSaving = false

    init(connectionId: Int, currentNote: String?, onSaved: @escaping () -> Void) {
        self.connectionId = connectionId
        self.currentNote = currentNote
        self.onSaved = onSaved
        self._note = State(initialValue: currentNote ?? "")
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
                    .disabled(isSaving)
            }
        }
        .padding()
        .frame(width: 450, minHeight: 250)
    }

    private func save() {
        isSaving = true
        Task {
            _ = try? await ConnectionService.updateNote(id: connectionId, note: note.isEmpty ? nil : note)
            await MainActor.run {
                onSaved()
                dismiss()
            }
        }
    }
}
