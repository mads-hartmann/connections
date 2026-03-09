import SwiftUI

struct ConnectionEditView: View {
    let connection: CDConnection

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var photo: String

    init(connection: CDConnection) {
        self.connection = connection
        self._name = State(initialValue: connection.name)
        self._photo = State(initialValue: connection.photo ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Connection").font(.headline)

            TextField("Name", text: $name).textFieldStyle(.roundedBorder)

            TextField("Photo URL", text: $photo, prompt: Text("https://example.com/photo.jpg"))
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func save() {
        ConnectionStore.update(
            connection,
            name: name.trimmingCharacters(in: .whitespaces),
            photo: photo.isEmpty ? nil : photo
        )
        dismiss()
    }
}
