import SwiftUI

@main
struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var usageStore = UsageStore(provider: ClaudeUsageProvider())

    var body: some Scene {
        MenuBarExtra(usageStore.menuBarTitle) {
            MenuContentView(usageStore: usageStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}
