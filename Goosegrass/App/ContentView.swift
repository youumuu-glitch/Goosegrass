import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 36))
                .accessibilityHidden(true)

            Text("Goosegrass")
                .font(.title)

            Text("Repository and architecture foundation")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 360)
    }
}

#Preview {
    ContentView()
}
