import SwiftUI
import SwiftData

struct ManualAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var producer = ""
    @State private var vintage = 0
    @State private var color: WineColor = .red
    @State private var region = ""
    @State private var country = ""
    @State private var appellation = ""
    @State private var grapeVarieties = ""
    @State private var quantity = 1
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Wine") {
                    TextField("Name", text: $name)
                    TextField("Producer", text: $producer)
                    Picker("Color", selection: $color) {
                        ForEach(WineColor.allCases) { color in
                            Text(color.label).tag(color)
                        }
                    }
                    Stepper(value: $vintage, in: 0...2100) {
                        HStack {
                            Text("Vintage")
                            Spacer()
                            Text(vintage > 0 ? String(vintage) : "NV")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Origin") {
                    TextField("Region", text: $region)
                    TextField("Country", text: $country)
                    TextField("Appellation", text: $appellation)
                    TextField("Grape varieties", text: $grapeVarieties)
                }
                Section("Quantity") {
                    Stepper(value: $quantity, in: 1...500) {
                        Text("\(quantity) bottle(s)")
                    }
                }
                Section("Notes") {
                    TextField("Tasting notes, storage location…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Add wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let wine = Wine(
                            name: name,
                            producer: producer,
                            vintage: vintage,
                            color: color,
                            region: region,
                            country: country,
                            grapeVarieties: grapeVarieties,
                            appellation: appellation,
                            quantity: quantity,
                            notes: notes
                        )
                        modelContext.insert(wine)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
