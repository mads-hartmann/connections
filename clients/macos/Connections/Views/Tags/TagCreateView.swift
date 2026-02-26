import SwiftUI

struct TagCreateView: View {
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Tag")
                .font(.headline)

            TextField("Tag name", text: $name)
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isCreating)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private func create() {
        isCreating = true
        error = nil
        Task {
            do {
                _ = try await TagService.create(name: name.trimmingCharacters(in: .whitespaces))
                await MainActor.run {
                    onCreated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

struct TagEditView: View {
    let tag: Tag
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var error: String?

    init(tag: Tag, onSaved: @escaping () -> Void) {
        self.tag = tag
        self.onSaved = onSaved
        self._name = State(initialValue: tag.name)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Tag")
                .font(.headline)

            TextField("Tag name", text: $name)
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
        .frame(width: 350)
    }

    private func save() {
        isSaving = true
        Task {
            do {
                _ = try await TagService.update(id: tag.id, name: name.trimmingCharacters(in: .whitespaces))
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
