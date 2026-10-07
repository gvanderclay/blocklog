import SwiftUI

@main
struct BlocklogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Blocklog")
            .font(.largeTitle)
            .accessibilityIdentifier("placeholder")
    }
}
