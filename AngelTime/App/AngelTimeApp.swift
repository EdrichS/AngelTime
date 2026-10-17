import AppKit

@main
@MainActor
enum AngelTimeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // NSApplication holds its delegate weakly, so keep it alive for the life of the run loop.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
