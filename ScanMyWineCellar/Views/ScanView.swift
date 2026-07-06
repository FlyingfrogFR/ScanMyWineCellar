import SwiftUI
import PhotosUI

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    let cellar: Cellar

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var showCamera = false
    @State private var isScanning = false
    @State private var scanned: [ScannedWine]?
    @State private var errorMessage: String?

    private let maxPhotos = 12

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if images.isEmpty {
                    instructions
                } else {
                    photoGrid
                }
                Spacer(minLength: 0)
                bottomBar
            }
            .navigationTitle("Scan bottles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $scanned) { wines in
                ScanReviewView(wines: wines, cellar: cellar) {
                    dismiss()
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let image {
                        images.append(image)
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) {
                Task { await loadPickedPhotos() }
            }
            .alert(
                "Scan failed",
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
                if isScanning {
                    scanningOverlay
                }
            }
        }
        .interactiveDismissDisabled(isScanning)
    }

    private var instructions: some View {
        ContentUnavailableView {
            Label("Photograph your racks", systemImage: "camera.viewfinder")
        } description: {
            Text("Take a few photos covering your shelves — no need to shoot each bottle individually. Make sure labels are readable and avoid photographing the same shelf twice.")
        }
        .padding(.top, 40)
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                images.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .padding(4)
                        }
                }
            }
            .padding()
        }
    }

    private var bottomBar: some View {
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
                    .disabled(images.count >= maxPhotos)
                }
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: maxPhotos - images.count,
                    matching: .images
                ) {
                    Label("Photo library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(images.count >= maxPhotos)
            }
            Button {
                Task { await runScan() }
            } label: {
                Label(
                    images.isEmpty ? "Identify wines" : "Identify wines in \(images.count) photo(s)",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(images.isEmpty || isScanning)
        }
        .padding()
        .background(.bar)
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Reading your labels…")
                    .foregroundStyle(.white)
                Text("This can take a minute for many bottles.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func loadPickedPhotos() async {
        for item in pickerItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        pickerItems = []
    }

    private func runScan() async {
        isScanning = true
        defer { isScanning = false }
        do {
            let apiKey = APIKeyStore.load()
            let wines = try await WineScanService().scan(images: images, apiKey: apiKey)
            if wines.isEmpty {
                errorMessage = "No identifiable bottles were found in these photos. Try closer shots with readable labels."
            } else {
                scanned = wines
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
