import AppKit

protocol DragDropViewDelegate: AnyObject {
    func dragDropView(_ view: DragDropView, didReceiveImage image: NSImage)
    func dragDropView(_ view: DragDropView, didRejectDropWithError error: String)
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

    private var dragHighlightView: NSView?

    private let supportedImageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic"]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let borderColor: NSColor
        let bgColor: NSColor
        let dashPhase: CGFloat

        if isDragging {
            borderColor = NSColor.controlAccentColor
            bgColor = NSColor.controlAccentColor.withAlphaComponent(0.1)
            dashPhase = 0
        } else {
            borderColor = NSColor.separatorColor
            bgColor = NSColor.clear
            dashPhase = 0
        }

        bgColor.setFill()
        NSBezierPath(rect: bounds).fill()

        NSColor.windowBackgroundColor.setFill()
        let innerRect = bounds.insetBy(dx: 4, dy: 4)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 6, yRadius: 6)
        innerPath.fill()

        borderColor.setStroke()
        let borderRect = bounds.insetBy(dx: 2, dy: 2)
        let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 8, yRadius: 8)
        borderPath.lineWidth = isDragging ? 3 : 2
        borderPath.setLineDash([8, 4], count: 2, phase: dashPhase)
        borderPath.stroke()

        drawPlaceholder()
    }

    private func drawPlaceholder() {
        let placeholderColor: NSColor = isDragging ? .controlAccentColor : .tertiaryLabelColor
        let text: String = isDragging ? "Release to recognize" : "Drop image here"

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: placeholderColor,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)

        let iconText = isDragging ? "✓" : "📷"
        let iconFont = NSFont.systemFont(ofSize: 32)
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: iconFont,
            .foregroundColor: placeholderColor
        ]
        let iconSize = iconText.size(withAttributes: iconAttributes)
        let iconRect = NSRect(
            x: (bounds.width - iconSize.width) / 2,
            y: textRect.maxY + 12,
            width: iconSize.width,
            height: iconSize.height
        )
        iconText.draw(in: iconRect, withAttributes: iconAttributes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard

        guard hasValidImageData(in: pasteboard) else {
            return []
        }

        if isDragging == false {
            isDragging = true
            animateHighlight(visible: true)
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        return hasValidImageData(in: pasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
        animateHighlight(visible: false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        return hasValidImageData(in: pasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        animateHighlight(visible: false)

        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let firstURL = urls.first {
            return handleFileURL(firstURL)
        }

        if let image = NSImage(pasteboard: pasteboard) {
            delegate?.dragDropView(self, didReceiveImage: image)
            return true
        }

        delegate?.dragDropView(self, didRejectDropWithError: "Unable to read image data from dropped item")
        return false
    }

    private func handleFileURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()

        guard supportedImageExtensions.contains(ext) else {
            delegate?.dragDropView(self, didRejectDropWithError: "Unsupported file format: .\(ext)")
            return false
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            delegate?.dragDropView(self, didRejectDropWithError: "Cannot read file: \(url.lastPathComponent)")
            return false
        }

        guard let image = NSImage(contentsOf: url) else {
            delegate?.dragDropView(self, didRejectDropWithError: "Failed to load image: \(url.lastPathComponent)")
            return false
        }

        guard image.isValid else {
            delegate?.dragDropView(self, didRejectDropWithError: "Invalid image data: \(url.lastPathComponent)")
            return false
        }

        delegate?.dragDropView(self, didReceiveImage: image)
        return true
    }

    private func hasValidImageData(in pasteboard: NSPasteboard) -> Bool {
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
               let url = urls.first {
                let ext = url.pathExtension.lowercased()
                return supportedImageExtensions.contains(ext)
            }
        }

        if pasteboard.types?.contains(.tiff) == true || pasteboard.types?.contains(.png) == true {
            return true
        }

        if let image = NSImage(pasteboard: pasteboard), image.isValid {
            return true
        }

        return false
    }

    private func animateHighlight(visible: Bool) {
        if dragHighlightView == nil {
            let highlight = NSView()
            highlight.wantsLayer = true
            highlight.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            highlight.layer?.cornerRadius = 8
            highlight.alphaValue = 0
            addSubview(highlight)
            dragHighlightView = highlight
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            dragHighlightView?.alphaValue = visible ? 1 : 0
        }
    }

    override func layout() {
        super.layout()
        dragHighlightView?.frame = bounds.insetBy(dx: 4, dy: 4)
    }
}

extension NSPasteboard.PasteboardType {
    static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
    static let jpg = NSPasteboard.PasteboardType("public.jpg")
}
