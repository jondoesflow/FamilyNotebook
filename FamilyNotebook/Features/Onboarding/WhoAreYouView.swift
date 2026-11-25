import SwiftUI

struct WhoAreYouView: View {
    @AppStorage("me") private var me: String = ""
    @AppStorage("personA") private var personA: String = People.defaultsA
    @AppStorage("personB") private var personB: String = People.defaultsB
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                NotebookCover(style: .blush).frame(width: 110).rotationEffect(.degrees(-14)).offset(x: -70, y: 10)
                NotebookCover(style: .lemons).frame(width: 110).rotationEffect(.degrees(12)).offset(x: 70, y: 10)
                NotebookCover(style: .midnight).frame(width: 124)
            }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 12)

            VStack(spacing: 10) {
                Text("Notebook")
                    .font(Theme.display(40))
                    .foregroundStyle(Theme.ink)
                Text("Beautiful notebooks for the two of you.")
                    .font(Theme.serif(.title3))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Text("Who's holding this phone?")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)

            HStack(spacing: 16) {
                ForEach([personA, personB], id: \.self) { name in
                    Button {
                        withAnimation(.spring) { me = name }
                    } label: {
                        VStack(spacing: 10) {
                            Avatar(name: name, size: 64)
                            Text(name).font(Theme.serif(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .card(radius: 24)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 24)

            Text("You can change names later in Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0.35)) { appeared = true } }
    }
}
