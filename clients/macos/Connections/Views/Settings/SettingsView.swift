import SwiftUI

struct SettingsView: View {
    @State private var serverURL: String = APIClient.shared.serverURL
    @State private var isChecking = false
    @State private var healthStatus: Bool?

    var body: some View {
        Form {
            Section("Server") {
                TextField("Server URL", text: $serverURL)
                    .onSubmit { save() }

                HStack {
                    Button("Save") { save() }
                    Button("Check Connection") { checkHealth() }
                        .disabled(isChecking)

                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else if let status = healthStatus {
                        Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(status ? .green : .red)
                        Text(status ? "Connected" : "Failed")
                            .foregroundStyle(status ? .green : .red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
        .padding()
    }

    private func save() {
        APIClient.shared.serverURL = serverURL
        healthStatus = nil
    }

    private func checkHealth() {
        isChecking = true
        healthStatus = nil
        Task {
            let result = await APIClient.shared.healthCheck()
            await MainActor.run {
                healthStatus = result
                isChecking = false
            }
        }
    }
}
