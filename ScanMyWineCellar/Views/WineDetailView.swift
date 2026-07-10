import SwiftUI
import SwiftData

struct WineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Cellar.dateCreated) private var cellars: [Cellar]
    @Query(sort: \Rack.orderIndex) private var allRacks: [Rack]
    @Bindable var wine: Wine

    private var cellarRacks: [Rack] {
        allRacks.filter { $0.cellar?.persistentModelID == wine.cellar?.persistentModelID }
    }

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
                VintageField(vintage: $wine.vintage)
            }
            Section("Origin") {
                TextField("Region", text: $wine.region)
                TextField("Country", text: $wine.country)
                TextField("Appellation", text: $wine.appellation)
                TextField("Grape varieties", text: $wine.grapeVarieties)
            }
            if cellars.count > 1 {
                Section("Cellar") {
                    Picker("Cellar", selection: Binding(
                        get: { wine.cellar?.persistentModelID },
                        set: { id in
                            wine.cellar = cellars.first { $0.persistentModelID == id }
                        }
                    )) {
                        ForEach(cellars) { cellar in
                            Text(cellar.name).tag(Optional(cellar.persistentModelID))
                        }
                    }
                }
            }
            if !cellarRacks.isEmpty {
                Section("Location") {
                    Picker("Rack", selection: Binding(
                        get: { wine.rack?.persistentModelID },
                        set: { id in
                            wine.rack = cellarRacks.first { $0.persistentModelID == id }
                            let maxFloor = max(0, (wine.rack?.floorCount ?? 1) - 1)
                            wine.floorIndex = min(wine.floorIndex, maxFloor)
                        }
                    )) {
                        Text("Not placed").tag(nil as PersistentIdentifier?)
                        ForEach(cellarRacks) { rack in
                            Text(rack.name).tag(Optional(rack.persistentModelID))
                        }
                    }
                    if let rack = wine.rack {
                        Picker("Floor", selection: $wine.floorIndex) {
                            ForEach(0..<rack.floorCount, id: \.self) { floor in
                                Text(rack.floorName(floor)).tag(floor)
                            }
                        }
                    }
                }
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
