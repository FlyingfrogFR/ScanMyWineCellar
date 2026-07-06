import SwiftUI
import SwiftData

struct CellarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wine.name) private var wines: [Wine]

    @State private var searchText = ""
    @State private var colorFilter: WineColor?
    @State private var showScan = false
    @State private var showSettings = false
    @State private var showManualAdd = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    private var filteredWines: [Wine] {
        wines.filter { wine in
            if let colorFilter, wine.color != colorFilter { return false }
            if searchText.isEmpty { return true }
            let haystack = "\(wine.name) \(wine.producer) \(wine.region) \(wine.country) \(wine.appellation) \(wine.grapeVarieties) \(wine.vintageLabel)"
            return haystack.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalBottles: Int {
        wines.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        NavigationStack {
            Group {
                if wines.isEmpty {
                    emptyState
                } else {
                    wineList
                }
            }
            .navigationTitle("My Cellar")
            .searchable(text: $searchText, prompt: "Search wines, regions, grapes…")
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
                        .disabled(wines.isEmpty)
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
                ScanView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddView()
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
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your cellar is empty", systemImage: "wineglass")
        } description: {
            Text("Photograph your wine racks — several bottles at once — and they'll be identified and added automatically.")
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
                    Text("\(filteredWines.count) of \(wines.count) wines shown")
                }
            }
        }
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
                Text("\(wines.count)")
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
                ForEach(WineColor.allCases.filter { c in wines.contains { $0.color == c } }) { c in
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

    private func drinkOne(_ wine: Wine) {
        if wine.quantity > 1 {
            wine.quantity -= 1
        } else {
            modelContext.delete(wine)
        }
    }

    private func exportCSV() {
        do {
            exportURL = try CSVExporter.export(wines)
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
        return parts.joined(separator: " · ")
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    CellarView()
        .modelContainer(for: Wine.self, inMemory: true)
}
