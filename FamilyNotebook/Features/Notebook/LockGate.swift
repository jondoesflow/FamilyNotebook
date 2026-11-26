import SwiftUI
import CryptoKit
import LocalAuthentication
import Security

/// PINs are shared between the two of you (the salted hash syncs with the notebook or note),
/// so Katie can open a locked notebook with the same PIN. After you've typed the PIN once on a
/// phone, Face ID can open it there too.
enum PinLock {
    static func hash(_ pin: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + ":" + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Keychain (remembers which locks this device has opened, for Face ID)

    private static let service = "FamilyNotebook.pin"

    static func remember(_ lockID: String, hash: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: lockID]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(hash.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func remembered(_ lockID: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: lockID,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .touchID ? "Touch ID" : "Face ID"
    }
}

/// Shows its content only once the right PIN has been entered.
struct PinGate<Header: View, Content: View>: View {
    var lockID: String
    var pinHash: String?
    var title: String
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    @State private var unlockedHash: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if pinHash == nil || unlockedHash == pinHash {
                content()
            } else {
                PinPad(title: title, subtitle: "Enter the PIN to open", lockID: lockID, expectedHash: pinHash) {
                    withAnimation(.spring) { unlockedHash = pinHash }
                } header: { header() }
                .paperBackground()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlockedHash = nil }
        }
    }
}

extension PinGate where Header == EmptyView {
    init(lockID: String, pinHash: String?, title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(lockID: lockID, pinHash: pinHash, title: title, header: { EmptyView() }, content: content)
    }
}

/// Wraps a notebook: shows its cover behind the PIN pad.
struct LockGate<Content: View>: View {
    @ObservedObject var notebook: Notebook
    @ViewBuilder var content: () -> Content

    var body: some View {
        PinGate(lockID: notebook.uuid?.uuidString ?? "", pinHash: notebook.pinHash, title: notebook.displayTitle) {
            NotebookCover(cover: notebook.cover, photo: notebook.coverPhoto)
                .frame(width: 110)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.ultraThinMaterial, in: Circle())
                }
        } content: {
            content()
        }
    }
}

/// Number pad with dots. Used to unlock (expectedHash set) or to choose a new PIN (expectedHash nil).
struct PinPad<Header: View>: View {
    var title: String
    var subtitle: String
    var lockID: String
    var expectedHash: String?
    var onSuccess: () -> Void
    @ViewBuilder var header: () -> Header

    @State private var digits = ""
    @State private var shake = 0
    @State private var error = false

    private var canUseBiometrics: Bool {
        guard let expectedHash else { return false }
        return PinLock.remembered(lockID) == expectedHash
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)
            header()
            VStack(spacing: 6) {
                Text(title).font(Theme.display(26)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                Text(error ? "That's not it. Try again." : subtitle)
                    .font(.subheadline)
                    .foregroundStyle(error ? Theme.warning : Theme.inkSecondary)
            }
            HStack(spacing: 14) {
                ForEach(0..<max(4, digits.count), id: \.self) { i in
                    Circle()
                        .fill(i < digits.count ? Theme.ink : .clear)
                        .overlay(Circle().strokeBorder(Theme.inkSecondary, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                }
            }
            .modifier(Shake(animatableData: CGFloat(shake)))
            .frame(height: 20)

            keypad
            Spacer(minLength: 10)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.error, trigger: shake)
        .onAppear { if canUseBiometrics { biometric() } }
    }

    private var keypad: some View {
        let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["bio", "0", "del"]]
        return VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
            if expectedHash == nil {
                Button("Done") { submit() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 240)
                    .disabled(digits.count < 4)
                    .opacity(digits.count < 4 ? 0.5 : 1)
                    .padding(.top, 6)
            }
        }
    }

    @ViewBuilder private func keyButton(_ key: String) -> some View {
        switch key {
        case "bio":
            Button { biometric() } label: {
                Image(systemName: PinLock.biometryName == "Touch ID" ? "touchid" : "faceid")
                    .font(.title2)
                    .frame(width: 72, height: 72)
            }
            .foregroundStyle(Theme.ink)
            .opacity(canUseBiometrics ? 1 : 0)
            .disabled(!canUseBiometrics)
        case "del":
            Button { if !digits.isEmpty { digits.removeLast() } } label: {
                Image(systemName: "delete.left").font(.title3).frame(width: 72, height: 72)
            }
            .foregroundStyle(Theme.ink)
        default:
            Button {
                guard digits.count < 8 else { return }
                error = false
                digits.append(key)
                UISelectionFeedbackGenerator().selectionChanged()
                if expectedHash != nil, digits.count >= 4, PinLock.hash(digits, salt: lockID) == expectedHash { submit() }
            } label: {
                Text(key)
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 72, height: 72)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.hairline))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func submit() {
        if let expectedHash {
            if PinLock.hash(digits, salt: lockID) == expectedHash {
                PinLock.remember(lockID, hash: expectedHash)
                onSuccess()
            } else {
                fail()
            }
        } else if digits.count >= 4 {
            onSuccessWithPin(digits)
        }
    }

    /// For setup flows the parent reads the digits through this hook.
    var onPinChosen: ((String) -> Void)? = nil
    private func onSuccessWithPin(_ pin: String) {
        onPinChosen?(pin)
        digits = ""
    }

    private func fail() {
        error = true
        digits = ""
        withAnimation(.default) { shake += 1 }
    }

    private func biometric() {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Open “\(title)”") { ok, _ in
            if ok { DispatchQueue.main.async { onSuccess() } }
        }
    }
}

struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Choose a PIN twice. Calls back with the salted hash.
struct PinSetupSheet: View {
    var title: String
    var lockID: String
    var onSet: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var first: String?
    @State private var mismatch = false

    var body: some View {
        NavigationStack {
            Group {
                if first == nil {
                    pad(subtitle: mismatch ? "The PINs didn't match. Start again." : "Choose a PIN of 4 to 8 digits") { pin in
                        mismatch = false
                        withAnimation { first = pin }
                    }
                    .id("first")
                } else {
                    pad(subtitle: "Type it again to confirm") { pin in
                        if pin == first {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            let hash = PinLock.hash(pin, salt: lockID)
                            PinLock.remember(lockID, hash: hash)
                            onSet(hash)
                            dismiss()
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            withAnimation { first = nil; mismatch = true }
                        }
                    }
                    .id("second")
                }
            }
            .paperBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func pad(subtitle: String, chosen: @escaping (String) -> Void) -> some View {
        var p = PinPad(title: title, subtitle: subtitle, lockID: lockID, expectedHash: nil, onSuccess: {}) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(Theme.accent)
                .padding(18)
                .background(Theme.accentSoft, in: Circle())
        }
        p.onPinChosen = chosen
        return p
    }
}
