import SwiftUI

struct AddMetadataView: View {
    let connection: CDConnection

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedFieldType: CDMetadataFieldType = .website
    @State private var value = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Metadata to \(connection.name)").font(.headline)

            Picker("Type", selection: $selectedFieldType) {
                ForEach(CDMetadataFieldType.allCases) { fieldType in
                    Text(fieldType.name).tag(fieldType)
                }
            }

            TextField("Value", text: $value, prompt: Text("https://example.com"))
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(value.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func save() {
        _ = MetadataStore.create(
            in: modelContext,
            connection: connection,
            fieldType: selectedFieldType,
            value: value.trimmingCharacters(in: .whitespaces)
        )
        dismiss()
    }
}
