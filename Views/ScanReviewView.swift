import SwiftUI
import SwiftData

/// Shows what the scan found and lets the user fix mistakes before the wines
/// are added to the cellar.
struct ScanReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var existingWines: [Wine]

    @State var wines: [ScannedWine]
    let onDone: () -> Void

    @State private var editingIndex: Int?

    init(wines: [ScannedWine], onDone: @escaping () -> Void) {
        self._wines = State(initialValue: wines)
        self.onDone = onDone
    }

    private var includedCount: Int {
        wines.filter(\.include).reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        List {
            Section {
                ForEach($wines) { $wine in
                    ScannedWineRow(wine: $wine) {
                        editingIndex = wines.firstIndex(where: { $0.id == wine.id })
                    }
                }
            } header: {
                Text("\(wines.count) wines found")
            } footer: {
                Text("Tap a row to correct details or bottle counts. Uncheck anything that was misread.")
            }
        }
        .navigationTitle("Review scan")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                addToCellar()
            } label: {
                Label("Add \(includedCount) bottle(s) to cellar", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(includedCount == 0)
            .padding()
            .background(.bar)
        }
        .sheet(item: Binding(
            get: { editingIndex.map { EditingIndex(value: $0) } },
            set: { editingIndex = $0?.value }
        )) { index in
            ScannedWineEditView(wine: $wines[index.value])
        }
    }

    private func addToCellar() {
        for scanned in wines where scanned.include {
            let wine = scanned.toWine()
            if let existing = existingWines.first(where: { $0.mergeKey == wine.mergeKey }) {
                existing.quantity += wine.quantity
            } else {
                modelContext.insert(wine)
            }
        }
        onDone()
    }
}

private struct EditingIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

private struct ScannedWineRow: View {
    @Binding var wine: ScannedWine
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                wine.include.toggle()
            } label: {
                Image(systemName: wine.include ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(wine.include ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

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
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer()

            Text("×\(wine.quantity)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .opacity(wine.include ? 1 : 0.4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !wine.producer.isEmpty { parts.append(wine.producer) }
        parts.append(wine.vintage > 0 ? String(wine.vintage) : "NV")
        if !wine.region.isEmpty { parts.append(wine.region) }
        return parts.joined(separator: " · ")
    }
}

private struct ScannedWineEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var wine: ScannedWine

    var body: some View {
        NavigationStack {
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
                            Text(wine.vintage > 0 ? String(wine.vintage) : "NV")
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
                Section("Quantity") {
                    Stepper(value: $wine.quantity, in: 1...200) {
                        Text("\(wine.quantity) bottle(s)")
                    }
                }
            }
            .navigationTitle("Edit wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
