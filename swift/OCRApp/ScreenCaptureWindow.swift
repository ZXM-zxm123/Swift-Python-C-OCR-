import AppKit
import Carbon.HIToolbox

class ScreenCaptureWindow: NSWindow {

    var onCapture: ((NSImage?) -> Void)?

    private var selectionView: SelectionOverlayView!
    private var startPoint: NSPoint = .zero
    private var endPoint: NSPoint = .zero
    private var isSelecting = false

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        super.init(contentRect: screenFrame, styleMask: .borderless, backing: .buffered, defer: false)

        level = .screenSaver
        isOpaque = false
        backgroundColor = NSColor.clear
        ignoresMouseEvents = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        selectionView = SelectionOverlayView(frame: contentRect)
        contentView = selectionView

        let trackingArea = NSTrackingArea(
            rect: contentRect,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(trackingArea)
    }

    func beginCapture() {
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        endPoint = startPoint
        isSelecting = true
        selectionView.startPoint = startPoint
        selectionView.endPoint = endPoint
        selectionView.isSelecting = true
        selectionView.needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        endPoint = event.locationInWindow
        selectionView.endPoint = endPoint
        selectionView.needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isSelecting = false
        selectionView.isSelecting = false

        NSCursor.arrow.set()

        let rect = normalizedRect(from: startPoint, to: endPoint)
        if rect.width > 10 && rect.height > 10 {
            captureRect(rect)
        } else {
            close()
            onCapture?(nil)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            close()
            onCapture?(nil)
        }
    }

    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func captureRect(_ rect: NSRect) {
        let screenRect = convertToScreen(rect)
        let cgRect = CGRect(
            x: screenRect.origin.x,
            y: NSScreen.main!.frame.height - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )

        guard let cgImage = CGWindowListCreateImage(cgRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else {
            close()
            onCapture?(nil)
            return
        }

        let image = NSImage(cgImage: cgImage, size: rect.size)
        close()
        onCapture?(image)
    }
}

class SelectionOverlayView: NSView {

    var startPoint: NSPoint = .zero
    var endPoint: NSPoint = .zero
    var isSelecting = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        let selectionRect = normalizedRect()
        NSColor.clear.setFill()
        selectionRect.fill(using: .clear)

        NSColor.white.setStroke()
        let borderPath = NSBezierPath(rect: selectionRect)
        borderPath.lineWidth = 2
        borderPath.stroke()

        let dashPattern: [CGFloat] = [6, 4]
        borderPath.setLineDash(dashPattern, count: 2, phase: 0)
        borderPath.stroke()

        let sizeString = "\(Int(selectionRect.width)) x \(Int(selectionRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let attributedString = NSAttributedString(string: " \(sizeString) ", attributes: attributes)
        let stringSize = attributedString.size()

        var labelOrigin = NSPoint(x: selectionRect.maxX - stringSize.width - 5, y: selectionRect.minY - stringSize.height - 5)
        if labelOrigin.y < 5 {
            labelOrigin.y = selectionRect.maxY + 5
        }
        if labelOrigin.x < 5 {
            labelOrigin.x = selectionRect.minX + 5
        }

        let labelRect = NSRect(origin: labelOrigin, size: stringSize)
        attributedString.draw(in: labelRect)

        if isSelecting {
            let instructionText = "Drag to select area | Press ESC to cancel"
            let instructionAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let instructionString = NSAttributedString(string: instructionText, attributes: instructionAttributes)
            let instructionSize = instructionString.size()
            let instructionOrigin = NSPoint(
                x: (bounds.width - instructionSize.width) / 2,
                y: bounds.height - instructionSize.height - 20
            )
            instructionString.draw(at: instructionOrigin)
        }
    }

    private func normalizedRect() -> NSRect {
        let x = min(startPoint.x, endPoint.x)
        let y = min(startPoint.y, endPoint.y)
        let width = abs(endPoint.x - startPoint.x)
        let height = abs(endPoint.y - startPoint.y)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

extension NSEvent {
    var locationInWindow: NSPoint {
        return self.locationInWindow
    }
}
