import SwiftUI
import SwiftData

struct WineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var wine: Wine

    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section("Wine") {
                TextField("Name", text: $wine.name)
                TextField("Producer", text: $wine.producer)
                Picker("Color", selection: $wine.color) {
                    ForEach(WineColor.allCases) { color in
                        Text(color.label).tag(color)
                    }
                }
                Stepper(value: $wine.vintage, in: 0...2100) {
                    HStack {
                        Text("Vintage")
                        Spacer()
                        Text(wine.vintageLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Origin") {
                TextField("Region", text: $wine.region)
                TextField("Country", text: $wine.country)
                TextField("Appellation", text: $wine.appellation)
                TextField("Grape varieties", text: $wine.grapeVarieties)
            }
            Section("In cellar") {
                Stepper(value: $wine.quantity, in: 0...500) {
                    Text("\(wine.quantity) bottle(s)")
                }
                Button {
                    if wine.quantity > 0 { wine.quantity -= 1 }
                } label: {
                    Label("Drink one", systemImage: "wineglass")
                }
                .disabled(wine.quantity == 0)
            }
            Section("Notes") {
                TextField("Tasting notes, storage location…", text: $wine.notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            Section {
                LabeledContent("Added", value: wine.dateAdded.formatted(date: .abbreviated, time: .omitted))
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Remove from cellar", systemImage: "trash")
                }
            }
        }
        .navigationTitle(wine.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this wine and all its bottles?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                modelContext.delete(wine)
                dismiss()
            }
        }
    }
}
