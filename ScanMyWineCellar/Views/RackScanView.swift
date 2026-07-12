import SwiftUI
import CoreData
import PhotosUI

/// Sets up racks from a photo of the cellar: the model counts shelves and
/// estimates bottles per shelf; the user confirms or adjusts before creating.
struct RackScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDRack.orderIndex, ascending: true)])
    private var allRacks: FetchedResults<CDRack>
    let cellar: CDCellar

    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var drafts: [RackDraft]?
    @State private var errorMessage: String?

    private var existingRacks: [CDRack] {
        allRacks.filter { $0.cellar?.objectID == cellar.objectID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let drafts {
                    confirmation(drafts)
                } else {
                    photoStage
                }
            }
            .background(Color.cellarBackground)
            .navigationTitle("Scan cellar setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { captured in
                    if let captured { image = ImageProcessing.downscaled(captured) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) {
                Task {
                    if let data = try? await pickerItem?.loadTransferable(type: Data.self),
                       let loaded = UIImage(data: data) {
                        image = ImageProcessing.downscaled(loaded)
                    }
                    pickerItem = nil
                }
            }
            .alert(
                "Analysis failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay {
                if isAnalyzing {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                            Text("Counting your shelves…")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isAnalyzing)
    }

    // MARK: - Stage 1: photo

    private var photoStage: some View {
        VStack(spacing: 0) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            } else {
                ContentUnavailableView {
                    Label("Photograph your cellar", systemImage: "camera.viewfinder")
                } description: {
                    Text("Take one photo showing the whole cabinet or rack, straight-on. The shelves and bottle positions will be counted for you — you only confirm the numbers.")
                }
                .padding(.top, 20)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Photo library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    Task { await analyze() }
                } label: {
                    Label("Count my shelves", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(image == nil || isAnalyzing)
            }
            .padding()
            .background(.bar)
        }
    }

    private func analyze() async {
        guard let image else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let estimates = try await WineScanService()
                .analyzeStructure(image: image, apiKey: APIKeyStore.load())
            if estimates.isEmpty {
                errorMessage = "No shelves could be identified in this photo. Try a straight-on shot showing the whole unit."
            } else {
                drafts = estimates.map { RackDraft(estimate: $0) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Stage 2: confirm

    private func confirmation(_ current: [RackDraft]) -> some View {
        Form {
            ForEach(current.indices, id: \.self) { i in
                let draft = binding(i)
                Section {
                    if current.count > 1 {
                        Toggle("Add this unit", isOn: draft.include)
                    }
                    TextField("Name", text: draft.name)
                        .font(.headline)
                    Stepper(value: draft.shelfCount, in: 1...30) {
                        HStack {
                            Text("Shelves")
                            Spacer()
                            Text("\(current[i].shelfCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: draft.bottlesPerShelf, in: 1...40) {
                        HStack {
                            Text("Bottles per shelf")
                            Spacer()
                            Text("\(current[i].bottlesPerShelf)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: draft.doubleDepth) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bottles stored two-deep")
                            Text("A hidden row sits behind the visible one — doubles the capacity.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(current.count > 1 ? "Detected unit \(i + 1)" : "Detected")
                } footer: {
                    if current[i].include {
                        let capacity = current[i].effectiveBottlesPerShelf * current[i].shelfCount
                        Text("Capacity: \(current[i].shelfCount) shelves × \(current[i].effectiveBottlesPerShelf) = \(capacity) bottles")
                    }
                }
                .listRowBackground(Color.cellarSurface)
            }
            Section {
                Button {
                    createRacks()
                } label: {
                    Label("Create", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!current.contains(where: \.include))
                Button("Retake photo", role: .cancel) {
                    drafts = nil
                    image = nil
                }
            }
            .listRowBackground(Color.cellarSurface)
        }
        .cellarChrome()
    }

    private func binding(_ index: Int) -> Binding<RackDraft> {
        Binding(
            get: { drafts![index] },
            set: { drafts![index] = $0 }
        )
    }

    private func createRacks() {
        guard let drafts else { return }
        var names = existingRacks.map(\.name)
        var nextIndex = (existingRacks.map(\.orderIndex).max() ?? -1) + 1
        for draft in drafts where draft.include {
            var name = draft.name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty { name = CDRack.nextDefaultName(existing: names) }
            while names.contains(name) { name += " 2" }
            names.append(name)
            let rack = CDRack(
                context: viewContext,
                name: name,
                orderIndex: nextIndex,
                floorCount: draft.shelfCount,
                bottlesPerFloor: draft.effectiveBottlesPerShelf
            )
            rack.cellar = cellar
            nextIndex += 1
        }
        dismiss()
    }
}

private struct RackDraft {
    var name: String
    var shelfCount: Int
    var bottlesPerShelf: Int
    var doubleDepth = false
    var include = true

    var effectiveBottlesPerShelf: Int {
        doubleDepth ? bottlesPerShelf * 2 : bottlesPerShelf
    }

    init(estimate: RackEstimate) {
        name = estimate.suggestedName
        shelfCount = max(1, min(30, estimate.shelfCount))
        bottlesPerShelf = max(1, min(40, estimate.bottlesPerShelf))
    }
}
