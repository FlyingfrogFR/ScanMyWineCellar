import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearance") private var appearance = "system"
    @State private var apiKey = APIKeyStore.load()
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.cellarSurface)
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("The key is stored only in this device's Keychain and is used to identify wines in your photos. Create one at console.anthropic.com under API Keys.")
                }
                .listRowBackground(Color.cellarSurface)
                Section {
                    LabeledContent("Model", value: WineScanService.model)
                } footer: {
                    Text("A typical scan of a few shelf photos costs a few cents.")
                }
                .listRowBackground(Color.cellarSurface)
            }
            .cellarChrome()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        APIKeyStore.save(apiKey)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
