import SwiftUI

struct TagCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Tag").font(.headline)

            TextField("Tag name", text: $name).textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private func create() {
        _ = TagStore.create(in: modelContext, name: name.trimmingCharacters(in: .whitespaces))
        try? modelContext.save()
        dismiss()
    }
}

struct TagEditView: View {
    let tag: CDTag

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(tag: CDTag) {
        self.tag = tag
        self._name = State(initialValue: tag.name)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Tag").font(.headline)

            TextField("Tag name", text: $name).textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private func save() {
        TagStore.update(tag, name: name.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}
