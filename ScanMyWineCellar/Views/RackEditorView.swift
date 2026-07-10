import SwiftUI
import SwiftData

/// Configure the cellar's racks: how many, their names, floors, and
/// bottles per floor.
struct RackEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Rack.orderIndex) private var allRacks: [Rack]
    let cellar: Cellar

    private var racks: [Rack] {
        allRacks.filter { $0.cellar?.persistentModelID == cellar.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(racks) { rack in
                    Section {
                        TextField("Rack name", text: Binding(
                            get: { rack.name },
                            set: { rack.name = $0 }
                        ))
                        .font(.headline)
                        Stepper(value: Binding(
                            get: { rack.floorCount },
                            set: { newValue in
                                rack.floorCount = newValue
                                // Keep placed wines on a valid floor.
                                for wine in rack.wines ?? [] where wine.floorIndex >= newValue {
                                    wine.floorIndex = newValue - 1
                                }
                            }
                        ), in: 1...30) {
                            HStack {
                                Text("Floors")
                                Spacer()
                                Text("\(rack.floorCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Stepper(value: Binding(
                            get: { rack.bottlesPerFloor },
                            set: { rack.bottlesPerFloor = $0 }
                        ), in: 1...40) {
                            HStack {
                                Text("Bottles per floor")
                                Spacer()
                                Text("\(rack.bottlesPerFloor)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button(role: .destructive) {
                            deleteRack(rack)
                        } label: {
                            Label("Delete rack", systemImage: "trash")
                        }
                    }
                }
                Section {
                    Button {
                        addRack()
                    } label: {
                        Label("Add rack", systemImage: "plus")
                    }
                } footer: {
                    Text("Deleting a rack doesn't delete its wines — they move back to “Not placed”. Floors are counted from the bottom.")
                }
            }
            .navigationTitle("Racks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addRack() {
        let rack = Rack(
            name: Rack.nextDefaultName(existing: racks.map(\.name)),
            orderIndex: (racks.map(\.orderIndex).max() ?? -1) + 1
        )
        rack.cellar = cellar
        modelContext.insert(rack)
    }

    private func deleteRack(_ rack: Rack) {
        // Nullify happens via the relationship's delete rule; be explicit
        // so the map updates immediately.
        for wine in rack.wines ?? [] {
            wine.rack = nil
            wine.floorIndex = 0
        }
        modelContext.delete(rack)
    }
}
