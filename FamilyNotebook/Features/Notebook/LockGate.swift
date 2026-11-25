import SwiftUI
import LocalAuthentication

/// A locked notebook shows its cover and title; Face ID (or your passcode) opens it.
struct LockGate<Content: View>: View {
    @ObservedObject var notebook: Notebook
    @ViewBuilder var content: () -> Content
    @State private var unlocked = false
    @State private var failed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !notebook.isLocked || unlocked {
                content()
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    NotebookCover(style: notebook.cover, photo: notebook.coverPhoto)
                        .frame(width: 170)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .padding(18)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    Text(notebook.displayTitle)
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.ink)
                    Button(failed ? "Try again" : "Unlock", action: unlock)
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 240)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .paperBackground()
                .onAppear(perform: unlock)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlocked = false }
        }
    }

    private func unlock() {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlocked = true
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Open “\(notebook.displayTitle)”") { ok, _ in
            DispatchQueue.main.async {
                withAnimation(.spring) {
                    unlocked = ok
                    failed = !ok
                }
            }
        }
    }
}
