import SwiftUI
import CoreData

/// Whole-cellar overview (design C): all racks side by side, bottle dots
/// colored by wine, floors pop out on tap, filter chips highlight matches
/// across the entire map.
struct CellarMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDRack.orderIndex, ascending: true)])
    private var allRacks: FetchedResults<CDRack>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDWine.name, ascending: true)])
    private var allWines: FetchedResults<CDWine>
    let cellar: CDCellar

    @State private var searchText = ""
    @State private var colorFilter: WineColor?
    @State private var selectedFloor: FloorRef?
    @State private var showRackEditor = false
    @State private var showRackScan = false

    private var racks: [CDRack] {
        allRacks.filter { $0.cellar?.objectID == cellar.objectID }
    }

    private var wines: [CDWine] {
        allWines.filter { $0.cellar?.objectID == cellar.objectID }
    }

    private var unplaced: [CDWine] { wines.filter { $0.rack == nil } }

    private var filterActive: Bool { colorFilter != nil || !searchText.isEmpty }

    var body: some View {
        Group {
            if racks.isEmpty {
                setupState
            } else {
                map
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRackEditor = true
                } label: {
                    Label("Racks", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(item: $selectedFloor) { ref in
            FloorDetailSheet(rack: ref.rack, floor: ref.floor, cellar: cellar)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRackEditor) {
            RackEditorView(cellar: cellar)
        }
        .sheet(isPresented: $showRackScan) {
            RackScanView(cellar: cellar)
        }
    }

    private var setupState: some View {
        ContentUnavailableView {
            Label("Describe your cellar", systemImage: "square.grid.3x2")
        } description: {
            Text("Add your storage — a wine cabinet like a EuroCave counts as one rack, and its shelves are the levels. Tell the app how many shelves it has and roughly how many bottles fit per shelf, and the map will show where every wine lives.")
        } actions: {
            Button {
                showRackScan = true
            } label: {
                Label("Photograph my cellar", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            Button {
                showRackEditor = true
            } label: {
                Label("Describe it manually", systemImage: "plus")
            }
        }
    }

    private var map: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                findBar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(racks) { rack in
                            rackColumn(rack)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                if !unplaced.isEmpty {
                    unplacedSection
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var findBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find a wine, region, vintage…", text: $searchText)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WineColor.allCases.filter { c in wines.contains { $0.color == c } }) { c in
                        let on = colorFilter == c
                        Button {
                            colorFilter = on ? nil : c
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(c.tint).frame(width: 10, height: 10)
                                Text(c.label).font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(on ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func matches(_ wine: CDWine) -> Bool {
        if let colorFilter, wine.color != colorFilter { return false }
        if !searchText.isEmpty {
            let haystack = "\(wine.name) \(wine.producer) \(wine.region) \(wine.country) \(wine.appellation) \(wine.grapeVarieties) \(wine.vintageLabel)"
            if !haystack.localizedCaseInsensitiveContains(searchText) { return false }
        }
        return true
    }

    private func winesOn(_ rack: CDRack, floor: Int) -> [CDWine] {
        wines.filter { $0.rack?.objectID == rack.objectID && $0.floorIndex == floor }
    }

    private func rackColumn(_ rack: CDRack) -> some View {
        VStack(spacing: 6) {
            Text(rack.name)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(Array((0..<rack.floorCount).reversed()), id: \.self) { floor in
                floorCell(rack: rack, floor: floor)
            }
        }
        .padding(10)
        .background(Color("CellarSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func floorCell(rack: CDRack, floor: Int) -> some View {
        let floorWines = winesOn(rack, floor: floor)
        let bottles: [(color: WineColor, hit: Bool)] = floorWines.flatMap { wine in
            Array(repeating: (wine.color, matches(wine)), count: wine.quantity)
        }
        let capacity = rack.bottlesPerFloor
        let overflow = max(0, bottles.count - capacity)

        return Button {
            selectedFloor = FloorRef(rack: rack, floor: floor)
        } label: {
            HStack(spacing: 4) {
                ForEach(Array(bottles.prefix(capacity).enumerated()), id: \.offset) { _, bottle in
                    Circle()
                        .fill(bottle.color.tint)
                        .frame(width: 13, height: 13)
                        .overlay {
                            if filterActive && bottle.hit {
                                Circle().stroke(Color.accentColor, lineWidth: 2.5)
                            }
                        }
                        .opacity(filterActive && !bottle.hit ? 0.18 : 1)
                }
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                ForEach(bottles.count..<max(bottles.count, capacity), id: \.self) { _ in
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3]))
                        .foregroundStyle(.tertiary)
                        .frame(width: 13, height: 13)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minWidth: CGFloat(capacity) * 17 + 16)
            .background(Color("CellarCell"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(rack.floorName(floor)), \(bottles.count) of \(capacity) bottles")
    }

    private var unplacedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not placed yet")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            ForEach(unplaced) { wine in
                HStack {
                    WineRow(wine: wine)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            Text("Open a shelf and use “Place bottles here”, or set the location from the wine's page.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
}

struct FloorRef: Identifiable {
    let rack: CDRack
    let floor: Int
    var id: String { "\(floor)|\(rack.objectID.uriRepresentation().absoluteString)" }
}

/// The pop-out: contents of one floor, rename with suggestions, and a
/// "place bottles here" list for unplaced wines.
struct FloorDetailSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDWine.name, ascending: true)])
    private var allWines: FetchedResults<CDWine>
    @ObservedObject var rack: CDRack
    let floor: Int
    let cellar: CDCellar

    private var floorWines: [CDWine] {
        allWines.filter { $0.rack?.objectID == rack.objectID && $0.floorIndex == floor }
    }

    private var unplaced: [CDWine] {
        allWines.filter { $0.cellar?.objectID == cellar.objectID && $0.rack == nil }
    }

    /// Wines in the same cellar sitting on a different shelf — movable here.
    private var elsewhere: [CDWine] {
        allWines.filter {
            $0.cellar?.objectID == cellar.objectID
                && $0.rack != nil
                && !($0.rack?.objectID == rack.objectID && $0.floorIndex == floor)
        }
    }

    private var bottleCount: Int { floorWines.reduce(0) { $0 + $1.quantity } }

    var body: some View {
        NavigationStack {
            List {
                nameSection
                Section {
                    if floorWines.isEmpty {
                        Text("Empty shelf")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(floorWines) { wine in
                        NavigationLink {
                            WineDetailView(wine: wine)
                        } label: {
                            WineRow(wine: wine)
                        }
                    }
                } header: {
                    Text("\(bottleCount) of \(rack.bottlesPerFloor) bottles")
                }
                .listRowBackground(Color.cellarSurface)
                if !unplaced.isEmpty {
                    Section("Place bottles here") {
                        ForEach(unplaced) { wine in
                            placementRow(wine)
                        }
                    }
                    .listRowBackground(Color.cellarSurface)
                }
                if !elsewhere.isEmpty {
                    Section("Move here from another shelf") {
                        ForEach(elsewhere) { wine in
                            placementRow(wine)
                        }
                    }
                    .listRowBackground(Color.cellarSurface)
                }
            }
            .cellarChrome()
            .navigationTitle("\(rack.name) · \(rack.floorName(floor))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Row for placing/moving a wine onto this shelf. Quantity 1 places
    /// directly; more bottles get a "how many?" menu that can split the
    /// entry across shelves.
    @ViewBuilder
    private func placementRow(_ wine: CDWine) -> some View {
        let label = HStack {
            WineRow(wine: wine)
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentColor)
        }
        if wine.quantity <= 1 {
            Button {
                place(wine, count: 1)
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            Menu {
                ForEach(placementCounts(for: wine.quantity), id: \.self) { n in
                    Button("Place \(n) bottle\(n > 1 ? "s" : "")") {
                        place(wine, count: n)
                    }
                }
                Button("Place all \(wine.quantity)") {
                    place(wine, count: wine.quantity)
                }
            } label: {
                label
            }
            .buttonStyle(.plain)
        }
    }

    private func placementCounts(for quantity: Int) -> [Int] {
        quantity <= 12
            ? Array(1..<quantity)
            : [1, 2, 3, 6, 12].filter { $0 < quantity }
    }

    /// Puts `count` bottles of `wine` on this shelf. A partial count splits
    /// the wine into a second entry; identical wines landing on the same
    /// shelf are merged back together.
    private func place(_ wine: CDWine, count: Int) {
        let n = min(count, wine.quantity)
        guard n > 0 else { return }
        if n == wine.quantity {
            if let twin = twin(of: wine) {
                twin.quantity += n
                viewContext.delete(wine)
            } else {
                wine.rack = rack
                wine.floorIndex = floor
            }
        } else {
            wine.quantity -= n
            if let twin = twin(of: wine) {
                twin.quantity += n
            } else {
                let moved = CDWine(
                    context: viewContext,
                    name: wine.name,
                    producer: wine.producer,
                    vintage: wine.vintage,
                    color: wine.color,
                    region: wine.region,
                    country: wine.country,
                    grapeVarieties: wine.grapeVarieties,
                    appellation: wine.appellation,
                    quantity: n,
                    notes: wine.notes,
                    dateAdded: wine.dateAdded
                )
                moved.cellar = wine.cellar
                moved.rack = rack
                moved.floorIndex = floor
            }
        }
    }

    /// An identical wine already sitting on this shelf, if any.
    private func twin(of wine: CDWine) -> CDWine? {
        allWines.first {
            $0.objectID != wine.objectID
                && $0.cellar?.objectID == wine.cellar?.objectID
                && $0.mergeKey == wine.mergeKey
                && $0.rack?.objectID == rack.objectID
                && $0.floorIndex == floor
        }
    }

    @ViewBuilder
    private var nameSection: some View {
        Section("Shelf name") {
            TextField(
                "Shelf \(floor + 1)",
                text: Binding(
                    get: { rack.customFloorName(floor) },
                    set: { rack.setFloorName($0, at: floor) }
                )
            )
            let suggestions = FloorNaming.suggestions(for: floorWines)
                .filter { $0 != rack.customFloorName(floor) }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                rack.setFloorName(suggestion, at: floor)
                            } label: {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
        .listRowBackground(Color.cellarSurface)
    }
}
