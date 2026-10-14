import SwiftUI

/// En lille regneopgave, så børn ikke selv ender i import og indstillinger.
struct ParentGateView: View {
    @Environment(\.theme) private var theme
    @Binding var path: [Route]
    @State private var a = Int.random(in: 3...9)
    @State private var b = Int.random(in: 2...9)
    @State private var answer = ""
    @State private var wrong = false

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 24) {
                TopBar(title: "Til de voksne", onBack: { _ = path.popLast() }) { EmptyView() }
                Spacer()
                Text("Hvad er \(a) gange \(b)?").font(theme.font(30)).foregroundStyle(theme.ink)
                TextField("Svar", text: $answer)
                    .font(theme.font(28))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit(check)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
                Button("Videre") { check() }.font(theme.font(22))
                if wrong { Text("Prøv igen").foregroundStyle(.red).font(theme.font(16)) }
                Spacer()
            }
        }
        .gameScreen()
    }

    private func check() {
        if Int(answer) == a * b {
            path.removeLast()
            path.append(.importDrawing)
        } else {
            wrong = true
            answer = ""
            a = Int.random(in: 3...9); b = Int.random(in: 2...9)
        }
    }
}
