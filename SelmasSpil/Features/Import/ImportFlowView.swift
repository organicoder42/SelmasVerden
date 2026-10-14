import SwiftUI
import PhotosUI

/// Forløbet "ny tegning": vælg foto eller tag et → behandling → godkend dele → gem.
struct ImportFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var path: [Route]

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var photo: CGImage?
    @State private var stage: ImportStage = .idle
    @State private var pieces: [ImportedPiece] = []
    @State private var running = false
    @State private var savedCount: Int?

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(title: "Nye tegninger", onBack: { _ = path.popLast() }) {
                    if !model.hasAPIAccess {
                        Button {
                            path.append(.settings)
                        } label: {
                            Label("Sorteringen er slået fra - sæt nøgle", systemImage: "exclamationmark.triangle")
                                .font(theme.font(14)).foregroundStyle(theme.ink)
                        }
                    }
                }
                content
            }
        }
        .gameScreen()
        .sheet(isPresented: $showCamera) {
            CameraPicker { img in
                showCamera = false
                if let img { start(with: img) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = ImageIO.loadOrientedCGImage(from: data, maxPixelSize: 3000) {
                    start(with: img)
                }
                photoItem = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let savedCount {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark.seal").font(.system(size: 72)).foregroundStyle(theme.ink)
                Text("\(savedCount) tegninger er lagt ind!").font(theme.font(30)).foregroundStyle(theme.ink)
                HStack(spacing: 20) {
                    Button("Tag flere") { reset() }.font(theme.font(22))
                    Button("Færdig") { _ = path.popLast() }.font(theme.font(22))
                }
                Spacer()
            }
        } else if running || (photo != nil && pieces.isEmpty) {
            VStack(spacing: 24) {
                Spacer()
                if let photo {
                    Image(decorative: photo, scale: 1).resizable().scaledToFit().frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                ProgressView().controlSize(.large)
                Text(stage.danishText).font(theme.font(22)).foregroundStyle(theme.ink)
                if case .failed = stage {
                    Button("Prøv igen") { reset() }.font(theme.font(20))
                }
                Spacer()
            }
        } else if !pieces.isEmpty {
            ImportReviewView(pieces: $pieces, sheet: photo) {
                do {
                    let saved = try model.commit(pieces: pieces)
                    savedCount = saved.count
                } catch {
                    stage = .failed(error.localizedDescription)
                }
            } onCancel: { reset() }
        } else {
            VStack(spacing: 28) {
                Spacer()
                Text("Tag et billede af en tegning").font(theme.font(32)).foregroundStyle(theme.ink)
                Text("Læg tegningen på et bord med godt lys. Flere tegninger på samme papir er fint - de bliver delt op.")
                    .font(theme.font(17, weight: .regular)).foregroundStyle(theme.inkSoft).multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                HStack(spacing: 24) {
                    if CameraPicker.isCameraAvailable {
                        BigButton(title: "Kamera", symbol: "camera") { showCamera = true }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 56)).foregroundStyle(theme.ink)
                            Text("Fra billeder").font(theme.font(26)).foregroundStyle(theme.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: 170)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.ink, lineWidth: theme.strokeWidth))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 640)
                Spacer()
            }
            .padding(40)
        }
    }

    private func start(with image: CGImage) {
        photo = image
        pieces = []
        running = true
        stage = .straightening
        savePhotoCopy(image)
        let pipeline = model.makePipeline()
        Task {
            let result = await pipeline.run(photo: image) { s in stage = s }
            running = false
            switch result {
            case .success(let p): pieces = p
            case .failure: break
            }
        }
    }

    /// Gem råfotoet, så tegningen kan køres igennem igen med bedre udskæring eller model senere.
    private func savePhotoCopy(_ image: CGImage) {
        guard let data = ImageIO.jpegData(ImageIO.downscaled(image, maxSide: 2500)) else { return }
        let name = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") + ".jpg"
        try? data.write(to: FileLocations.importedPhotos.appendingPathComponent(name))
    }

    private func reset() {
        photo = nil; pieces = []; stage = .idle; savedCount = nil; running = false
    }
}
