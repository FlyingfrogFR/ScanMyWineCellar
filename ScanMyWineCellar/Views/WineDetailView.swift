import SwiftUI
import CoreData

struct WineDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDCellar.dateCreated, ascending: true)])
    private var cellars: FetchedResults<CDCellar>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDRack.orderIndex, ascending: true)])
    private var allRacks: FetchedResults<CDRack>
    @ObservedObject var wine: CDWine

    @State private var confirmDelete = false

    private var cellarRacks: [CDRack] {
        allRacks.filter { $0.cellar?.objectID == wine.cellar?.objectID }
    }

    var body: some View {
        // The wine can be deleted (here or on the map) while this view is
        // still dismissing; touching its properties then would crash.
        if wine.isDeleted || wine.managedObjectContext == nil {
            Color.clear
        } else {
            form
        }
    }

    private var form: some View {
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
            .listRowBackground(Color.cellarSurface)
            Section("Origin") {
                TextField("Region", text: $wine.region)
                TextField("Country", text: $wine.country)
                TextField("Appellation", text: $wine.appellation)
                TextField("Grape varieties", text: $wine.grapeVarieties)
            }
            .listRowBackground(Color.cellarSurface)
            if cellars.count > 1 {
                Section("Cellar") {
                    Picker("Cellar", selection: Binding(
                        get: { wine.cellar?.objectID },
                        set: { id in
                            wine.cellar = cellars.first { $0.objectID == id }
                        }
                    )) {
                        ForEach(cellars) { cellar in
                            Text(cellar.name).tag(Optional(cellar.objectID))
                        }
                    }
                }
                .listRowBackground(Color.cellarSurface)
            }
            if !cellarRacks.isEmpty {
                Section("Location") {
                    Picker("Rack", selection: Binding(
                        get: { wine.rack?.objectID },
                        set: { id in
                            wine.rack = cellarRacks.first { $0.objectID == id }
                            let maxFloor = max(0, (wine.rack?.floorCount ?? 1) - 1)
                            wine.floorIndex = min(wine.floorIndex, maxFloor)
                        }
                    )) {
                        Text("Not placed").tag(nil as NSManagedObjectID?)
                        ForEach(cellarRacks) { rack in
                            Text(rack.name).tag(Optional(rack.objectID))
                        }
                    }
                    if let rack = wine.rack {
                        Picker("Shelf", selection: $wine.floorIndex) {
                            ForEach(0..<rack.floorCount, id: \.self) { floor in
                                Text(rack.floorName(floor)).tag(floor)
                            }
                        }
                    }
                }
                .listRowBackground(Color.cellarSurface)
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
            .listRowBackground(Color.cellarSurface)
            Section("Notes") {
                TextField("Tasting notes, storage location…", text: $wine.notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .listRowBackground(Color.cellarSurface)
            Section {
                LabeledContent("Added", value: wine.dateAdded.formatted(date: .abbreviated, time: .omitted))
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Remove from cellar", systemImage: "trash")
                }
            }
            .listRowBackground(Color.cellarSurface)
        }
        .cellarChrome()
        .navigationTitle(wine.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this wine and all its bottles?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                viewContext.delete(wine)
                dismiss()
            }
        }
    }
}
