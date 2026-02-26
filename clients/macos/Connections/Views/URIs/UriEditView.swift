import SwiftUI

struct UriEditView: View {
    let uri: UriEntry
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var selectedKind: UriKind
    @State private var isSaving = false
    @State private var error: String?

    init(uri: UriEntry, onSaved: @escaping () -> Void) {
        self.uri = uri
        self.onSaved = onSaved
        self._title = State(initialValue: uri.title ?? "")
        self._selectedKind = State(initialValue: uri.kind)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit URI")
                .font(.headline)

            LabeledContent("URL") { Text(uri.url).font(.caption).lineLimit(1) }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Kind", selection: $selectedKind) {
                ForEach(UriKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

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
        .frame(width: 400)
    }

    private func save() {
        // URI edit is done through the note endpoint for now;
        // the server doesn't have a general URI update endpoint,
        // so we update what we can
        isSaving = true
        Task {
            // For now, just refresh and callback
            await MainActor.run {
                onSaved()
                dismiss()
            }
        }
    }
}

struct UriNoteView: View {
    let uriId: Int
    let currentNote: String?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var isSaving = false

    init(uriId: Int, currentNote: String?, onSaved: @escaping () -> Void) {
        self.uriId = uriId
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
            _ = try? await UriService.updateNote(id: uriId, note: note.isEmpty ? nil : note)
            await MainActor.run {
                onSaved()
                dismiss()
            }
        }
    }
}
