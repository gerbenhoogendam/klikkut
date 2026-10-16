import SwiftUI
import AppKit
import ServiceManagement

@main
struct MuisklikkertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = ClickStore.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            Image(systemName: "cursorarrow.click.2")
            Text(store.today.total.formatted())
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Twee kopieën tegelijk zouden elkaars tellingen overschrijven; houd het bij één.
        let me = NSRunningApplication.current
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0 != me }) {
            NSApp.terminate(nil)
            return
        }
        MainActor.assumeIsolated { ClickStore.shared.start() }
        enableLaunchAtLoginOnFirstRun()
    }

    /// Zet "Start bij inloggen" één keer standaard aan; daarna beslist de schakelaar in het menu.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "didEnableLaunchAtLoginByDefault"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            NSLog("Muisklikkert: start bij inloggen aanzetten mislukt: \(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { ClickStore.shared.saveIfNeeded() }
    }
}
