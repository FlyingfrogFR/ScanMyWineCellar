import SwiftUI
import CoreData

/// Configure the cellar's racks: how many, their names, shelves, and
/// bottles per shelf.
struct RackEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDRack.orderIndex, ascending: true)])
    private var allRacks: FetchedResults<CDRack>
    let cellar: CDCellar

    @State private var showRackScan = false

    private var racks: [CDRack] {
        allRacks.filter { $0.cellar?.objectID == cellar.objectID }
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
                                // Keep placed wines on a valid shelf.
                                for wine in rack.winesArray where wine.floorIndex >= newValue {
                                    wine.floorIndex = newValue - 1
                                }
                            }
                        ), in: 1...30) {
                            HStack {
                                Text("Shelves")
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
                                Text("Bottles per shelf")
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
                    .listRowBackground(Color.cellarSurface)
                }
                Section {
                    Button {
                        addRack()
                    } label: {
                        Label("Add rack", systemImage: "plus")
                    }
                    Button {
                        showRackScan = true
                    } label: {
                        Label("Add from a photo", systemImage: "camera.viewfinder")
                    }
                } footer: {
                    Text("A rack is one storage unit: a wine cabinet like a EuroCave, a wine fridge, or a wall of racks in a cellar. Its shelves are counted from the bottom. Most people need just one rack — rename it after your cabinet. Deleting a rack doesn't delete its wines; they move back to “Not placed”.")
                }
                .listRowBackground(Color.cellarSurface)
            }
            .cellarChrome()
            .navigationTitle("Racks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showRackScan) {
                RackScanView(cellar: cellar)
            }
        }
    }

    private func addRack() {
        let rack = CDRack(
            context: viewContext,
            name: CDRack.nextDefaultName(existing: racks.map(\.name)),
            orderIndex: (racks.map(\.orderIndex).max() ?? -1) + 1
        )
        rack.cellar = cellar
    }

    private func deleteRack(_ rack: CDRack) {
        // Nullify happens via the relationship's delete rule; be explicit
        // so the map updates immediately.
        for wine in rack.winesArray {
            wine.rack = nil
            wine.floorIndex = 0
        }
        viewContext.delete(rack)
    }
}
