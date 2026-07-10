import SwiftUI
import SwiftData

struct CellarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wine.name) private var wines: [Wine]
    @Query(sort: \Cellar.dateCreated) private var cellars: [Cellar]

    @State private var selectedCellar: Cellar?
    @State private var searchText = ""
    @State private var colorFilter: WineColor?
    @State private var showScan = false
    @State private var showSettings = false
    @State private var showManualAdd = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showRenameCellar = false
    @State private var renameText = ""
    @State private var confirmDeleteCellar = false
    @AppStorage("cellarViewMode") private var viewMode = "list"

    /// Wines belonging to the currently selected cellar.
    private var cellarWines: [Wine] {
        wines.filter { $0.cellar?.persistentModelID == selectedCellar?.persistentModelID }
    }

    private var filteredWines: [Wine] {
        cellarWines.filter { wine in
            if let colorFilter, wine.color != colorFilter { return false }
            if searchText.isEmpty { return true }
            let haystack = "\(wine.name) \(wine.producer) \(wine.region) \(wine.country) \(wine.appellation) \(wine.grapeVarieties) \(wine.vintageLabel)"
            return haystack.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalBottles: Int {
        cellarWines.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $viewMode) {
                    Text("List").tag("list")
                    Text("Map").tag("map")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                Group {
                    if viewMode == "map", let selectedCellar {
                        CellarMapView(cellar: selectedCellar)
                    } else if cellarWines.isEmpty {
                        emptyState
                    } else {
                        wineList
                    }
                }
            }
            .navigationTitle(selectedCellar?.name ?? "My Cellar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarTitleMenu {
                cellarMenu
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showManualAdd = true
                        } label: {
                            Label("Add manually", systemImage: "plus")
                        }
                        Button {
                            exportCSV()
                        } label: {
                            Label("Export as spreadsheet (CSV)", systemImage: "square.and.arrow.up")
                        }
                        .disabled(cellarWines.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    Button {
                        showScan = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showScan) {
                if let selectedCellar {
                    ScanView(cellar: selectedCellar)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showManualAdd) {
                if let selectedCellar {
                    ManualAddView(cellar: selectedCellar)
                }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(items: [url])
            }
            .alert(
                "Export failed",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .alert("Rename cellar", isPresented: $showRenameCellar) {
                TextField("Name", text: $renameText)
                Button("Rename") {
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { selectedCellar?.name = name }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete \"\(selectedCellar?.name ?? "")\"? All \(totalBottles) bottle(s) in it will be deleted too.",
                isPresented: $confirmDeleteCellar,
                titleVisibility: .visible
            ) {
                Button("Delete cellar", role: .destructive) {
                    deleteSelectedCellar()
                }
            }
            .task {
                bootstrap()
            }
        }
    }

    @ViewBuilder
    private var cellarMenu: some View {
        ForEach(cellars) { cellar in
            Button {
                selectedCellar = cellar
            } label: {
                if cellar.persistentModelID == selectedCellar?.persistentModelID {
                    Label(cellar.name, systemImage: "checkmark")
                } else {
                    Text(cellar.name)
                }
            }
        }
        Divider()
        Button {
            addCellar()
        } label: {
            Label("New cellar", systemImage: "plus")
        }
        Button {
            renameText = selectedCellar?.name ?? ""
            showRenameCellar = true
        } label: {
            Label("Rename cellar", systemImage: "pencil")
        }
        if cellars.count > 1 {
            Button(role: .destructive) {
                confirmDeleteCellar = true
            } label: {
                Label("Delete cellar", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("This cellar is empty", systemImage: "wineglass")
        } description: {
            Text("Photograph your bottles a shelf at a time — pull them out and lay them on a table if they're stored neck-out — and they'll be identified and added to \(selectedCellar?.name ?? "your cellar"). Tap the title above to switch or create cellars.")
        } actions: {
            Button {
                showScan = true
            } label: {
                Label("Scan bottles", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var wineList: some View {
        List {
            Section {
                summaryHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
            Section {
                colorFilterChips
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(filteredWines) { wine in
                    NavigationLink(value: wine.persistentModelID) {
                        WineRow(wine: wine)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            drinkOne(wine)
                        } label: {
                            Label("Drink one", systemImage: "wineglass")
                        }
                        .tint(.purple)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(wine)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                if !searchText.isEmpty || colorFilter != nil {
                    Text("\(filteredWines.count) of \(cellarWines.count) wines shown")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search wines, regions, grapes…")
        .navigationDestination(for: PersistentIdentifier.self) { id in
            if let wine = wines.first(where: { $0.persistentModelID == id }) {
                WineDetailView(wine: wine)
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("\(totalBottles)")
                    .font(.title.bold())
                Text("bottles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                Text("\(cellarWines.count)")
                    .font(.title.bold())
                Text("wines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var colorFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", color: nil)
                ForEach(WineColor.allCases.filter { c in cellarWines.contains { $0.color == c } }) { c in
                    filterChip(label: c.label, color: c)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func filterChip(label: String, color: WineColor?) -> some View {
        let isSelected = colorFilter == color
        return Button {
            colorFilter = color
        } label: {
            HStack(spacing: 6) {
                if let color {
                    Circle().fill(color.tint).frame(width: 10, height: 10)
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cellar management

    private func bootstrap() {
        if cellars.isEmpty {
            let cellar = Cellar(name: "My Cellar")
            modelContext.insert(cellar)
            selectedCellar = cellar
        } else if selectedCellar == nil {
            selectedCellar = cellars.first
        }
        // Adopt wines created before multi-cellar support.
        if let home = selectedCellar {
            for wine in wines where wine.cellar == nil {
                wine.cellar = home
            }
        }
    }

    private func addCellar() {
        let cellar = Cellar(name: Cellar.nextDefaultName(existing: cellars.map(\.name)))
        modelContext.insert(cellar)
        selectedCellar = cellar
    }

    private func deleteSelectedCellar() {
        guard let cellar = selectedCellar, cellars.count > 1 else { return }
        let deletedID = cellar.persistentModelID
        modelContext.delete(cellar)
        selectedCellar = cellars.first { $0.persistentModelID != deletedID }
    }

    private func drinkOne(_ wine: Wine) {
        if wine.quantity > 1 {
            wine.quantity -= 1
        } else {
            modelContext.delete(wine)
        }
    }

    private func exportCSV() {
        do {
            exportURL = try CSVExporter.export(
                cellarWines,
                cellarName: selectedCellar?.name ?? "MyWineCellar"
            )
        } catch {
            exportError = error.localizedDescription
        }
    }
}

struct WineRow: View {
    let wine: Wine

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(wine.color.tint)
                .frame(width: 8, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(wine.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("×\(wine.quantity)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if !wine.producer.isEmpty { parts.append(wine.producer) }
        parts.append(wine.vintageLabel)
        if !wine.region.isEmpty { parts.append(wine.region) }
        if !wine.locationLabel.isEmpty { parts.append(wine.locationLabel) }
        return parts.joined(separator: " · ")
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    CellarView()
        .modelContainer(for: [Wine.self, Cellar.self, Rack.self], inMemory: true)
}
