import SwiftUI
import CoreGraphics

/// Fælles byggesten. Alt udseende kommer fra Theme, så det kan skiftes ud med Selmas streg senere.

struct BigButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let title: String
    var symbol: String
    /// Eksplicit håndtegnet ikon. Udelades det, slås der op på knappens titel blandt Selmas "Knap / ikon"-tegninger.
    var iconAsset: CGImage? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if let icon = iconAsset ?? model.library.uiIconImage(named: title) {
                    Image(decorative: icon, scale: 1)
                        .resizable().scaledToFit().frame(height: 72)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(theme.ink)
                }
                Text(title)
                    .font(theme.font(26))
                    .foregroundStyle(theme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 170)
            .background(theme.card, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.ink, lineWidth: theme.strokeWidth))
        }
        .buttonStyle(.plain)
    }
}

struct RoundIconButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let symbol: String
    var label: String? = nil
    var size: CGFloat = 56
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    // Findes der et håndtegnet ikon med samme navn som knappen, bruges det i stedet for systemsymbolet.
                    if let label, let icon = model.library.uiIconImage(named: label) {
                        Image(decorative: icon, scale: 1)
                            .resizable().scaledToFit()
                            .padding(size * 0.18)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: size * 0.42, weight: .semibold))
                    }
                }
                    .frame(width: size, height: size)
                    .background(active ? theme.selection : theme.card, in: Circle())
                    .overlay(Circle().stroke(theme.ink, lineWidth: theme.strokeWidth * 0.7))
                    .foregroundStyle(theme.ink)
                if let label {
                    Text(label).font(theme.font(12, weight: .medium)).foregroundStyle(theme.ink)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? symbol)
    }
}

/// Lille billede af en tegning, med dens maling.
struct AssetThumbnail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let assetID: UUID
    var paint: PaintState = .none
    var selected: Bool = false
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6)
                .fill(theme.card)
            if let img = model.renderer.image(for: assetID, paint: paint) {
                Image(decorative: img, scale: 1)
                    .resizable().scaledToFit()
                    .padding(size * 0.08)
            } else {
                Image(systemName: "questionmark").foregroundStyle(theme.inkSoft)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6)
                .stroke(selected ? theme.selection : theme.ink.opacity(0.35), lineWidth: selected ? theme.strokeWidth * 1.3 : 1.5)
        )
    }
}

/// Tom tilstand: "Der er ikke tegnet noget endnu".
struct EmptyHint: View {
    @Environment(\.theme) private var theme
    let title: String
    let text: String
    var symbol: String = "pencil.and.scribble"

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 54)).foregroundStyle(theme.inkSoft)
            Text(title).font(theme.font(24)).foregroundStyle(theme.ink)
            Text(text).font(theme.font(16, weight: .regular)).foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: 480)
    }
}

/// Tilbage-knap øverst til venstre, stor nok til børnefingre.
struct TopBar<Trailing: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    var onBack: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            RoundIconButton(symbol: "chevron.left", size: 52) {
                if let onBack { onBack() } else { dismiss() }
            }
            Text(title).font(theme.font(28)).foregroundStyle(theme.ink)
            Spacer()
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

extension View {
    /// Skjuler systemets navigationsbjælke - vi har vores egen store TopBar.
    func gameScreen() -> some View {
        #if os(iOS)
        return self
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        #else
        return self
        #endif
    }
}
