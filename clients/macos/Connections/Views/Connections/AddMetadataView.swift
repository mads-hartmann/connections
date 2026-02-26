import SwiftUI

struct AddMetadataView: View {
    let connectionId: Int
    let connectionName: String
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFieldType = MetadataFieldType.allTypes[5] // Website
    @State private var value = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Metadata to \(connectionName)")
                .font(.headline)

            Picker("Type", selection: $selectedFieldType) {
                ForEach(MetadataFieldType.allTypes) { fieldType in
                    Text(fieldType.name).tag(fieldType)
                }
            }

            TextField("Value", text: $value, prompt: Text("https://example.com"))
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(value.isEmpty || isSaving)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func save() {
        isSaving = true
        error = nil
        Task {
            do {
                _ = try await ConnectionService.createMetadata(
                    connectionId: connectionId,
                    fieldTypeId: selectedFieldType.id,
                    value: value.trimmingCharacters(in: .whitespaces)
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
