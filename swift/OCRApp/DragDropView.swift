import AppKit

protocol DragDropViewDelegate: AnyObject {
    func dragDropView(_ view: DragDropView, didReceiveImage image: NSImage)
}

class DragDropView: NSView {

    weak var delegate: DragDropViewDelegate?
    weak var imageScrollView: NSScrollView?
    weak var textScrollView: NSScrollView?
    weak var segmentControl: NSSegmentedControl?

    private var isDragging = false {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let borderColor: NSColor
        let bgColor: NSColor

        if isDragging {
            borderColor = NSColor.selectedContentBackgroundColor
            bgColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.1)
        } else {
            borderColor = NSColor.separatorColor
            bgColor = NSColor.clear
        }

        bgColor.setFill()
        NSBezierPath(rect: bounds).fill()

        borderColor.setStroke()
        let borderRect = bounds.insetBy(dx: 2, dy: 2)
        let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 8, yRadius: 8)
        borderPath.lineWidth = 2
        borderPath.setLineDash([6, 3], count: 2, phase: 0)
        borderPath.stroke()

        if let image = NSImage(named: "DropImage") {
            let imageRect = NSRect(x: (bounds.width - 64) / 2, y: (bounds.height - 64) / 2, width: 64, height: 64)
            image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 0.5)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if canAcceptDrag(sender) {
            isDragging = true
            return .copy
        }
        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return canAcceptDrag(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return canAcceptDrag(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false

        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
            if let image = NSImage(contentsOf: url) {
                delegate?.dragDropView(self, didReceiveImage: image)
                return true
            }
        }

        if let image = NSImage(pasteboard: pasteboard) {
            delegate?.dragDropView(self, didReceiveImage: image)
            return true
        }

        return false
    }

    private func canAcceptDrag(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
                return url.isImageFile
            }
        }

        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }

        return false
    }
}

extension URL {
    var isImageFile: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp"]
        return imageExtensions.contains(pathExtension.lowercased())
    }
}
