import AppKit

class MainWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OCR App"
        window.minSize = NSSize(width: 600, height: 500)
        window.center()

        self.init(window: window)

        let mainViewController = MainViewController()
        window.contentViewController = mainViewController
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}
