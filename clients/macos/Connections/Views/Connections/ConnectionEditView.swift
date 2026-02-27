import SwiftUI

struct ConnectionEditView: View {
    let connection: Connection
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var photo: String
    @State private var isSaving = false
    @State private var error: String?

    init(connection: Connection, onSaved: @escaping () -> Void) {
        self.connection = connection
        self.onSaved = onSaved
        self._name = State(initialValue: connection.name)
        self._photo = State(initialValue: connection.photo ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Connection")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Photo URL", text: $photo, prompt: Text("https://example.com/photo.jpg"))
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isSaving)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func save() {
        isSaving = true
        Task {
            do {
                _ = try await ConnectionService.update(
                    id: connection.id,
                    name: name.trimmingCharacters(in: .whitespaces),
                    photo: photo.isEmpty ? nil : photo
                )
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
