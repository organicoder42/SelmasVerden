import SwiftUI

/// Forælderen kigger på det AI'en fandt: retter kategori og navn, fravælger stumper og deler hele figurer op.
struct ImportReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var pieces: [ImportedPiece]
    let sheet: CGImage?
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Er det rigtigt?").font(theme.font(26)).foregroundStyle(theme.ink)
                Text("\(pieces.filter(\.accepted).count) af \(pieces.count) kommer med")
                    .font(theme.font(15, weight: .regular)).foregroundStyle(theme.inkSoft)
                Spacer()
                Button("Smid væk", role: .destructive) { onCancel() }.font(theme.font(18))
                Button {
                    onSave()
                } label: {
                    Label("Læg ind i spillet", systemImage: "checkmark")
                        .font(theme.font(20))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(theme.selection, in: Capsule())
                        .foregroundStyle(theme.ink)
                }
                .buttonStyle(.plain)
                .disabled(!pieces.contains { $0.accepted && $0.category != .unknown })
            }
            .padding(.horizontal, 24).padding(.vertical, 10)

            if let note = pieces.first?.notes, note.contains("nøgle") || note.contains("Netværk") {
                Text(note).font(theme.font(14, weight: .regular)).foregroundStyle(theme.inkSoft).padding(.horizontal, 24)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach($pieces) { $piece in
                        PieceCard(piece: $piece) {
                            // Del en hel figur op i krop + tøj + ansigt
                            let parts = ImportPipeline.splitFullCharacter(piece)
                            if let i = pieces.firstIndex(where: { $0.id == piece.id }) {
                                pieces.replaceSubrange(i...i, with: parts)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
    }
}

struct PieceCard: View {
    @Environment(\.theme) private var theme
    @Binding var piece: ImportedPiece
    let onSplit: () -> Void
    @State private var editingBoxes = false
    @State private var splitRequested = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                CheckerBackground().clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6))
                Image(decorative: piece.image, scale: 1).resizable().scaledToFit().padding(10)
            }
            .frame(height: 180)
            .opacity(piece.accepted ? 1 : 0.35)

            TextField("Navn", text: $piece.name)
                .font(theme.font(17))
                .textFieldStyle(.roundedBorder)

            Picker("Kategori", selection: $piece.category) {
                ForEach(AssetGroup.allCases) { g in
                    Section(g.danishName) {
                        ForEach(g.categories) { c in
                            Text(c.danishName).tag(c)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .tint(theme.ink)

            HStack {
                ConfidenceDots(value: piece.confidence)
                Spacer()
                if piece.category == .fullCharacter {
                    Button { editingBoxes = true } label: { Label("Del op…", systemImage: "scissors") }.font(theme.font(14))
                }
                Toggle("Med", isOn: $piece.accepted).labelsHidden()
            }
            if let notes = piece.notes, piece.confidence < 0.5 {
                Text(notes).font(theme.font(12, weight: .regular)).foregroundStyle(theme.inkSoft).lineLimit(2)
            }
        }
        .padding(12)
        .background(theme.card, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.ink.opacity(0.35), lineWidth: 1.5))
        // Opdelingen udføres først når arket er lukket, så kortet ikke forsvinder under det åbne ark.
        .sheet(isPresented: $editingBoxes, onDismiss: {
            if splitRequested { splitRequested = false; onSplit() }
        }) {
            SubpartEditorSheet(piece: $piece) {
                splitRequested = true
                editingBoxes = false
            }
            .environment(\.theme, theme)
        }
    }
}

/// Viser hvor sikker sorteringen var: 1-5 prikker.
struct ConfidenceDots: View {
    @Environment(\.theme) private var theme
    let value: Double
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(Double(i) < value * 5 ? theme.ink : theme.ink.opacity(0.2)).frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel("Sikkerhed \(Int(value * 100)) procent")
    }
}

/// Skakternet baggrund så man kan se at papiret er væk.
struct CheckerBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 12
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let dark = (Int(x / s) + Int(y / s)) % 2 == 0
                    ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(dark ? Color.gray.opacity(0.18) : Color.gray.opacity(0.06)))
                    x += s
                }
                y += s
            }
        }
    }
}
